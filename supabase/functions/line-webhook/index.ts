// Aiko × LINE — Supabase Edge Function
//
// Bridges the LINE Messaging API to Aiko's existing `aiko-chat` function so a
// LINE user can chat with Aiko using their own RLS-scoped financial data.
//
// Two entry points on one function:
//   GET  →  serves the LIFF login page. The user signs in with their normal
//           Aiko email/password (Supabase Auth) *inside LINE*; the page writes a
//           `line_links` row (LINE id → user id + refresh token) under their JWT.
//   POST →  the LINE webhook. Verifies LINE's signature, looks up the linked
//           user, refreshes a short-lived access token for them, calls the
//           existing `aiko-chat` function with that token (so the model only
//           ever sees data RLS allows), collects the streamed reply, and sends
//           it back through the LINE reply API.
//
// Security: the provider/AI key never lives here (it stays in aiko-chat). The
// service-role key is used *only* server-side to read/rotate the LINE link
// (an inbound LINE event carries no Supabase JWT). Per-user data access still
// flows through that user's JWT into aiko-chat, so Postgres RLS scopes it.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.0";
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const LINE_CHANNEL_SECRET = Deno.env.get("LINE_CHANNEL_SECRET") ?? "";
const LINE_CHANNEL_ACCESS_TOKEN = Deno.env.get("LINE_CHANNEL_ACCESS_TOKEN") ?? "";
const LINE_LIFF_ID = Deno.env.get("LINE_LIFF_ID") ?? "";

const LIFF_URL = LINE_LIFF_ID ? `https://liff.line.me/${LINE_LIFF_ID}` : "";
const LINE_REPLY_ENDPOINT = "https://api.line.me/v2/bot/message/reply";
const AIKO_CHAT_URL = `${SUPABASE_URL}/functions/v1/aiko-chat`;
const MAX_LINE_TEXT = 4800; // LINE caps a text message at 5000 chars.

const encoder = new TextEncoder();

// ---- LINE signature verification (HMAC-SHA256 of the raw body) ----

async function verifyLineSignature(rawBody: string, signature: string | null): Promise<boolean> {
  if (!signature || !LINE_CHANNEL_SECRET) return false;
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(LINE_CHANNEL_SECRET),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const mac = await crypto.subtle.sign("HMAC", key, encoder.encode(rawBody));
  const expected = btoa(String.fromCharCode(...new Uint8Array(mac)));
  // Constant-time-ish compare.
  if (expected.length !== signature.length) return false;
  let diff = 0;
  for (let i = 0; i < expected.length; i++) {
    diff |= expected.charCodeAt(i) ^ signature.charCodeAt(i);
  }
  return diff === 0;
}

// ---- LINE reply ----

async function replyToLine(replyToken: string, text: string): Promise<void> {
  await fetch(LINE_REPLY_ENDPOINT, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${LINE_CHANNEL_ACCESS_TOKEN}`,
    },
    body: JSON.stringify({
      replyToken,
      messages: [{ type: "text", text: text.slice(0, MAX_LINE_TEXT) }],
    }),
  }).catch(() => {/* best-effort: LINE reply tokens are short-lived */});
}

// ---- Aiko: refresh the linked user's token, then call aiko-chat ----

interface LinkRow {
  user_id: string;
  refresh_token: string | null;
}

// Exchanges the stored refresh token for a fresh access token and rotates the
// stored refresh token. Returns null if the link can't be refreshed (the user
// must re-link). Uses an anon client purely for the token exchange.
async function freshAccessToken(
  admin: ReturnType<typeof createClient>,
  lineUserId: string,
  link: LinkRow,
): Promise<string | null> {
  if (!link.refresh_token) return null;
  const anon = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data, error } = await anon.auth.refreshSession({
    refresh_token: link.refresh_token,
  });
  if (error || !data.session) return null;

  // Rotate the stored refresh token so the next message uses the latest one.
  await admin
    .from("line_links")
    .update({ refresh_token: data.session.refresh_token, updated_at: new Date().toISOString() })
    .eq("line_user_id", lineUserId);

  return data.session.access_token;
}

// Calls the existing aiko-chat SSE function as the linked user and assembles the
// streamed deltas into a single reply string.
async function askAiko(accessToken: string, text: string): Promise<string> {
  const resp = await fetch(AIKO_CHAT_URL, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Accept: "text/event-stream",
      Authorization: `Bearer ${accessToken}`,
    },
    body: JSON.stringify({ messages: [{ role: "user", content: text }] }),
  });

  if (!resp.ok || !resp.body) {
    return "Aiko is having trouble right now. Please try again in a moment.";
  }

  const reader = resp.body.getReader();
  const decoder = new TextDecoder();
  let buffer = "";
  let answer = "";
  while (true) {
    const { value, done } = await reader.read();
    if (done) break;
    buffer += decoder.decode(value, { stream: true });
    const lines = buffer.split("\n");
    buffer = lines.pop() ?? "";
    for (const line of lines) {
      const trimmed = line.trim();
      if (!trimmed.startsWith("data:")) continue;
      const payload = trimmed.slice(5).trim();
      if (!payload || payload === "[DONE]") continue;
      try {
        const json = JSON.parse(payload);
        if (typeof json.delta === "string") answer += json.delta;
        if (json.done === true) return answer.trim() || "…";
        if (typeof json.error === "string" && !answer) return "Aiko hit an error. Please try again.";
      } catch {
        // ignore non-JSON keepalive lines
      }
    }
  }
  return answer.trim() || "…";
}

// ---- Webhook event handling ----

async function handleTextMessage(
  admin: ReturnType<typeof createClient>,
  lineUserId: string,
  replyToken: string,
  text: string,
): Promise<void> {
  const { data: link } = await admin
    .from("line_links")
    .select("user_id, refresh_token")
    .eq("line_user_id", lineUserId)
    .maybeSingle();

  if (!link) {
    await replyToLine(
      replyToken,
      `Hi! I'm Aiko 💙 To answer questions about your money, please log in to your Aiko account first:\n${LIFF_URL}`,
    );
    return;
  }

  const token = await freshAccessToken(admin, lineUserId, link as LinkRow);
  if (!token) {
    await replyToLine(
      replyToken,
      `Your Aiko sign-in expired. Please log in again to reconnect:\n${LIFF_URL}`,
    );
    return;
  }

  const answer = await askAiko(token, text);
  await replyToLine(replyToken, answer);
}

async function handleWebhook(rawBody: string): Promise<void> {
  let body: { events?: unknown };
  try {
    body = JSON.parse(rawBody);
  } catch {
    return;
  }
  const events = Array.isArray(body.events) ? body.events : [];
  if (events.length === 0) return;

  const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  for (const event of events as Array<Record<string, any>>) {
    const lineUserId = event?.source?.userId;
    const replyToken = event?.replyToken;
    if (!lineUserId || !replyToken) continue;

    if (event.type === "follow") {
      await replyToLine(
        replyToken,
        `Welcome! I'm Aiko 💙 Log in to your Aiko account and I'll help with your spending, budgets, and goals:\n${LIFF_URL}`,
      );
      continue;
    }
    if (event.type === "message" && event.message?.type === "text") {
      await handleTextMessage(admin, lineUserId, replyToken, String(event.message.text ?? ""));
    }
  }
}

// ---- LIFF login page (served on GET) ----

function loginPage(): string {
  // The page runs inside LINE (LIFF). After a normal Supabase email/password
  // sign-in it writes the line_links row under the user's own JWT, so RLS
  // applies. The anon key is public by design.
  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>Connect Aiko</title>
<style>
  :root { font-family: -apple-system, system-ui, sans-serif; }
  body { margin: 0; background: #EFF6FF; color: #0F172A; }
  .card { max-width: 380px; margin: 0 auto; padding: 24px; }
  h1 { font-size: 20px; }
  p { color: #293348; font-size: 14px; }
  input { width: 100%; box-sizing: border-box; padding: 12px; margin: 6px 0;
    border: 1px solid #BAC3D6; border-radius: 8px; font-size: 15px; }
  button { width: 100%; padding: 14px; margin-top: 12px; border: 0;
    border-radius: 8px; background: #3B82F6; color: #fff; font-size: 15px;
    font-weight: 700; }
  button:disabled { opacity: .5; }
  .status { margin-top: 12px; font-size: 14px; min-height: 20px; }
  .ok { color: #16A34A; } .err { color: #DC2626; }
</style>
</head>
<body>
  <div class="card">
    <h1>Connect Aiko to LINE</h1>
    <p>Sign in with the same email and password you use in the Aiko app. This links your LINE chat to your account so Aiko can answer about your money.</p>
    <input id="email" type="email" placeholder="Email" autocomplete="username" />
    <input id="password" type="password" placeholder="Password" autocomplete="current-password" />
    <button id="submit">Log in &amp; connect</button>
    <div id="status" class="status"></div>
  </div>
  <script src="https://static.line-scdn.net/liff/edge/2/sdk.js"></script>
  <script src="https://esm.sh/@supabase/supabase-js@2.45.0"></script>
  <script type="module">
    import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.0";
    const supabase = createClient("${SUPABASE_URL}", "${SUPABASE_ANON_KEY}");
    const statusEl = document.getElementById("status");
    let lineUserId = null, displayName = null;

    async function boot() {
      try {
        await liff.init({ liffId: "${LINE_LIFF_ID}" });
        if (!liff.isLoggedIn()) { liff.login(); return; }
        const profile = await liff.getProfile();
        lineUserId = profile.userId;
        displayName = profile.displayName;
      } catch (e) {
        statusEl.textContent = "Open this page from inside LINE to connect.";
        statusEl.className = "status err";
      }
    }
    boot();

    document.getElementById("submit").addEventListener("click", async () => {
      const btn = document.getElementById("submit");
      const email = document.getElementById("email").value.trim();
      const password = document.getElementById("password").value;
      if (!lineUserId) { statusEl.textContent = "LINE profile not ready yet."; statusEl.className = "status err"; return; }
      btn.disabled = true; statusEl.textContent = "Signing in…"; statusEl.className = "status";
      const { data, error } = await supabase.auth.signInWithPassword({ email, password });
      if (error || !data.session) {
        statusEl.textContent = "Sign-in failed. Check your email and password."; statusEl.className = "status err";
        btn.disabled = false; return;
      }
      const { error: upsertErr } = await supabase.from("line_links").upsert({
        line_user_id: lineUserId,
        user_id: data.session.user.id,
        refresh_token: data.session.refresh_token,
        display_name: displayName,
        updated_at: new Date().toISOString(),
      }, { onConflict: "line_user_id" });
      if (upsertErr) {
        statusEl.textContent = "Could not save the link. Please try again."; statusEl.className = "status err";
        btn.disabled = false; return;
      }
      statusEl.textContent = "Connected! You can return to LINE and chat with Aiko."; statusEl.className = "status ok";
      setTimeout(() => { if (window.liff && liff.isInClient()) liff.closeWindow(); }, 1500);
    });
  </script>
</body>
</html>`;
}

// ---- Entry point ----

serve(async (req) => {
  if (req.method === "GET") {
    return new Response(loginPage(), {
      headers: { "Content-Type": "text/html; charset=utf-8", "Cache-Control": "no-store" },
    });
  }

  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  if (!SUPABASE_URL || !SERVICE_ROLE_KEY || !LINE_CHANNEL_SECRET || !LINE_CHANNEL_ACCESS_TOKEN) {
    // Misconfigured — acknowledge so LINE doesn't retry endlessly, but do nothing.
    return new Response("ok", { status: 200 });
  }

  const rawBody = await req.text();
  const signature = req.headers.get("x-line-signature");
  if (!(await verifyLineSignature(rawBody, signature))) {
    return new Response("Bad signature", { status: 401 });
  }

  // Acknowledge LINE immediately; process events without blocking the 200.
  // (Edge runtime keeps the task alive via waitUntil-style background work.)
  await handleWebhook(rawBody);
  return new Response("ok", { status: 200 });
});
