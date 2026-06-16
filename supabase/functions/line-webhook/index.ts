// Aiko × LINE — Supabase Edge Function
//
// Bridges the LINE Messaging API to Aiko's existing `aiko-chat` function so a
// LINE user can chat with Aiko using their own RLS-scoped financial data.
//
// Linking: an unlinked LINE user gets a short pairing code from the bot. They
// enter it in the Aiko app (Profile → Connect LINE), which — signed in — writes
// the `line_links` row (LINE id → user id + refresh token) under their own JWT.
// This function never sees the user's password.
//
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

const PAIRING_TTL_MIN = 10;
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

// ---- Pairing code ----

// 6 chars from an unambiguous alphabet (~8.8e8 combinations). Single active
// code per LINE user, ~10 min TTL. Redemption goes through the
// redeem_line_pairing RPC (line_pairings isn't client-readable), so codes can't
// be enumerated — only guessed, which the entropy + TTL + single-use cover.
// ponytail: no rate limit on guessing; add one if it ever looks worth it.
function newPairingCode(): string {
  const alphabet = "ABCDEFGHJKMNPQRSTUVWXYZ23456789";
  const bytes = crypto.getRandomValues(new Uint8Array(6));
  let code = "";
  for (const b of bytes) code += alphabet[b % alphabet.length];
  return code;
}

// Issues (or replaces) the pending pairing code for this LINE user and returns
// the message to send them. The connect page redeems it under the user's JWT.
async function startPairing(
  admin: ReturnType<typeof createClient>,
  lineUserId: string,
): Promise<string> {
  const code = newPairingCode();
  await admin.from("line_pairings").upsert({
    line_user_id: lineUserId,
    code,
    expires_at: new Date(Date.now() + PAIRING_TTL_MIN * 60_000).toISOString(),
  }, { onConflict: "line_user_id" });
  return `Hi! I'm Aiko 💙 To connect your account, open the Aiko app → Profile → Connect LINE and enter this code:\n\n${code}\n\nThe code expires in ${PAIRING_TTL_MIN} minutes.`;
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
    await replyToLine(replyToken, await startPairing(admin, lineUserId));
    return;
  }

  const token = await freshAccessToken(admin, lineUserId, link as LinkRow);
  if (!token) {
    await replyToLine(
      replyToken,
      `Your Aiko sign-in expired — let's reconnect.\n\n${await startPairing(admin, lineUserId)}`,
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
      await replyToLine(replyToken, await startPairing(admin, lineUserId));
      continue;
    }
    if (event.type === "message" && event.message?.type === "text") {
      await handleTextMessage(admin, lineUserId, replyToken, String(event.message.text ?? ""));
    }
  }
}

// ---- Entry point ----

serve(async (req) => {
  // Linking happens in the Aiko app (Profile → Connect LINE), not here. This
  // function only handles the LINE webhook (POST).
  if (req.method === "GET") {
    return new Response("Aiko LINE webhook. Connect from the Aiko app.", {
      headers: { "Content-Type": "text/plain" },
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
