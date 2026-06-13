// Aiko Chat — Supabase Edge Function
// Streams OpenAI Chat Completions responses as Server-Sent Events to the
// Aiko mobile assistant. Validates the caller's Supabase JWT, enforces the
// user's AI consent preference, applies a per-user rate limit, and emits
// `data: {"delta":"..."}\n\n` chunks (and a final `{"done":true}`).

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.0";
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

const SYSTEM_PROMPT = [
  "You are Aiko, a friendly, warm, and supportive personal finance companion in the Aiko app.",
  "You are not a certified financial advisor — every response that gives numbers, recommendations, or projections MUST end with this exact line on its own:",
  '"Aiko provides estimates, not certified financial advice."',
  "Never shame or judge the user. If you don't have enough data, say so plainly and suggest the screen in Aiko that would help (Accounts, Budgets, Goals, Transactions).",
  "Prefer short, skimmable answers. Use the user's reported base currency. Round to two decimals. Avoid jargon.",
  "Do not promise features that don't exist in Aiko. Do not request sensitive data (SSN, full card numbers, passwords).",
  "If the user asks something unrelated to personal finance, gently steer back: 'I'm best with money questions — want to ask me about your spending, budgets, or goals?'",
].join(" ");

const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY") ?? "";
const OPENAI_MODEL = Deno.env.get("OPENAI_MODEL") ?? "gpt-4o-mini";
const RATE_LIMIT_PER_MIN = Number(Deno.env.get("AIKO_RATE_PER_MIN") ?? "20");

const rateBuckets = new Map<string, { tokens: number; updatedAt: number }>();

function takeToken(userId: string): boolean {
  const now = Date.now();
  const bucket = rateBuckets.get(userId) ?? { tokens: RATE_LIMIT_PER_MIN, updatedAt: now };
  const elapsed = (now - bucket.updatedAt) / 60_000;
  const refilled = Math.min(RATE_LIMIT_PER_MIN, bucket.tokens + elapsed * RATE_LIMIT_PER_MIN);
  if (refilled < 1) {
    rateBuckets.set(userId, { tokens: refilled, updatedAt: now });
    return false;
  }
  rateBuckets.set(userId, { tokens: refilled - 1, updatedAt: now });
  return true;
}

function sseEvent(payload: Record<string, unknown>): Uint8Array {
  return new TextEncoder().encode(`data: ${JSON.stringify(payload)}\n\n`);
}

function jsonResponse(status: number, body: Record<string, unknown>): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json",
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Headers": "authorization, content-type",
    },
  });
}

interface IncomingMessage {
  role: "user" | "assistant" | "system";
  content: string;
}

interface RequestBody {
  messages: IncomingMessage[];
  systemContext?: { baseCurrency?: string; locale?: string };
}

function isRequestBody(value: unknown): value is RequestBody {
  if (!value || typeof value !== "object") return false;
  const v = value as Record<string, unknown>;
  if (!Array.isArray(v.messages)) return false;
  return v.messages.every((m) =>
    m && typeof m === "object" &&
    typeof (m as Record<string, unknown>).role === "string" &&
    typeof (m as Record<string, unknown>).content === "string"
  );
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST, OPTIONS",
        "Access-Control-Allow-Headers": "authorization, content-type",
      },
    });
  }

  if (req.method !== "POST") {
    return jsonResponse(405, { error: "Method not allowed", code: "METHOD_NOT_ALLOWED" });
  }

  const authHeader = req.headers.get("authorization") ?? "";
  const jwt = authHeader.startsWith("Bearer ") ? authHeader.slice(7) : null;
  if (!jwt) {
    return jsonResponse(401, { error: "Missing bearer token", code: "NO_TOKEN" });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const supabaseAnon = Deno.env.get("SUPABASE_ANON_KEY");
  if (!supabaseUrl || !supabaseAnon) {
    return jsonResponse(500, { error: "Server is not configured", code: "MISCONFIGURED" });
  }

  const supabase = createClient(supabaseUrl, supabaseAnon, {
    auth: { persistSession: false },
    global: { headers: { Authorization: `Bearer ${jwt}` } },
  });

  const { data: userData, error: userErr } = await supabase.auth.getUser(jwt);
  if (userErr || !userData?.user) {
    return jsonResponse(401, { error: "Invalid token", code: "BAD_TOKEN" });
  }
  const userId = userData.user.id;

  if (!takeToken(userId)) {
    return jsonResponse(429, { error: "Too many requests. Try again in a moment.", code: "RATE_LIMITED" });
  }

  const { data: profile, error: profileErr } = await supabase
    .from("profiles")
    .select("ai_consent_enabled")
    .eq("user_id", userId)
    .maybeSingle();

  if (profileErr) {
    return jsonResponse(500, { error: "Could not load profile", code: "PROFILE_LOAD_FAILED" });
  }
  if (!profile?.ai_consent_enabled) {
    return jsonResponse(403, { error: "AI features are off in Settings.", code: "AI_CONSENT_OFF" });
  }

  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return jsonResponse(400, { error: "Invalid JSON", code: "BAD_JSON" });
  }
  if (!isRequestBody(body)) {
    return jsonResponse(400, { error: "messages array is required", code: "BAD_REQUEST" });
  }

  if (!OPENAI_API_KEY) {
    return jsonResponse(500, { error: "Server is missing OPENAI_API_KEY", code: "MISSING_PROVIDER_KEY" });
  }

  const baseCurrency = body.systemContext?.baseCurrency ?? "USD";
  const systemWithContext = `${SYSTEM_PROMPT}\n\nUser's base currency: ${baseCurrency}. Always render currency with that code.`;

  const openaiMessages = [
    { role: "system" as const, content: systemWithContext },
    ...body.messages.slice(-20).map((m) => ({ role: m.role, content: m.content })),
  ];

  let upstream: Response;
  try {
    upstream = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${OPENAI_API_KEY}`,
      },
      body: JSON.stringify({
        model: OPENAI_MODEL,
        stream: true,
        temperature: 0.4,
        messages: openaiMessages,
      }),
    });
  } catch (e) {
    return jsonResponse(502, { error: `Provider unreachable: ${(e as Error).message}`, code: "PROVIDER_DOWN" });
  }

  if (!upstream.ok || !upstream.body) {
    const text = await upstream.text().catch(() => "");
    return jsonResponse(502, { error: `Provider error: ${upstream.status} ${text.slice(0, 200)}`, code: "PROVIDER_ERROR" });
  }

  const reader = upstream.body.getReader();
  const decoder = new TextDecoder();
  const stream = new ReadableStream<Uint8Array>({
    async start(controller) {
      let buffer = "";
      try {
        while (true) {
          const { value, done } = await reader.read();
          if (done) break;
          buffer += decoder.decode(value, { stream: true });
          const lines = buffer.split("\n");
          buffer = lines.pop() ?? "";
          for (const line of lines) {
            const trimmed = line.trim();
            if (!trimmed || !trimmed.startsWith("data:")) continue;
            const payload = trimmed.slice(5).trim();
            if (payload === "[DONE]") {
              controller.enqueue(sseEvent({ done: true }));
              controller.close();
              return;
            }
            try {
              const json = JSON.parse(payload);
              const delta = json?.choices?.[0]?.delta?.content;
              if (typeof delta === "string" && delta.length > 0) {
                controller.enqueue(sseEvent({ delta }));
              }
            } catch {
              continue;
            }
          }
        }
        controller.enqueue(sseEvent({ done: true }));
        controller.close();
      } catch (e) {
        controller.enqueue(sseEvent({ error: `Stream failed: ${(e as Error).message}` }));
        try { controller.close(); } catch { /* noop */ }
      } finally {
        try { reader.releaseLock(); } catch { /* noop */ }
      }
    },
  });

  return new Response(stream, {
    headers: {
      "Content-Type": "text/event-stream",
      "Cache-Control": "no-cache, no-transform",
      "Connection": "keep-alive",
      "Access-Control-Allow-Origin": "*",
    },
  });
});
