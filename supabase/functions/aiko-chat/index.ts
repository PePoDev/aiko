// Aiko Chat — Supabase Edge Function
// Streams chat completions from any OpenAI-compatible provider as Server-Sent
// Events to the Aiko mobile assistant. Validates the caller's Supabase JWT,
// applies a per-user rate limit, folds the client's on-device financial
// snapshot (Layer 1) into the system prompt, and — when AI_TOOLS_ENABLED — lets
// the model pull deeper data through read-only Postgres RPCs (Layer 2). Emits
// `data: {"delta":"..."}\n\n` chunks (and a final `{"done":true}`).
//
// Security model: the provider key lives only here (never on the client). All
// data access runs through the *caller's* JWT, so Postgres RLS scopes every read
// to that user. The function never uses the service-role key, never executes
// model-supplied SQL, and only calls a fixed allow-list of read-only RPCs.

import { createClient, SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.45.0";
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

const SYSTEM_PROMPT = [
  "You are Aiko, a friendly, warm, and supportive personal finance companion in the Aiko app.",
  "You are not a certified financial advisor — every response that gives numbers, recommendations, or projections MUST end with this exact line on its own:",
  '"Aiko provides estimates, not certified financial advice."',
  "Never shame or judge the user. If you don't have enough data, say so plainly and suggest the screen in Aiko that would help (Accounts, Budgets, Goals, Transactions).",
  "Prefer short, skimmable answers. Use the user's reported base currency. Round to two decimals. Avoid jargon.",
  "Do not promise features that don't exist in Aiko. Do not request sensitive data (SSN, full card numbers, passwords).",
  "Base every number on the provided snapshot or tool results — never invent figures.",
  "If the user asks something unrelated to personal finance, gently steer back: 'I'm best with money questions — want to ask me about your spending, budgets, or goals?'",
].join(" ");

// Any OpenAI-compatible Chat Completions provider (OpenAI, OpenRouter, Together,
// Groq, a local server, etc.). Point AI_BASE_URL at the provider's v1 endpoint.
const AI_API_KEY = Deno.env.get("AI_API_KEY") ?? "";
const AI_MODEL = Deno.env.get("AI_MODEL") ?? "gpt-4o-mini";
const AI_BASE_URL = (Deno.env.get("AI_BASE_URL") ?? "https://api.openai.com/v1").replace(/\/+$/, "");
const RATE_LIMIT_PER_MIN = Number(Deno.env.get("AIKO_RATE_PER_MIN") ?? "20");

// Layer 2 (server-side tool calling) is OFF until reviewed. When false the
// function behaves exactly like Layer 1: one streamed completion, no tools.
const AI_TOOLS_ENABLED = (Deno.env.get("AI_TOOLS_ENABLED") ?? "false").toLowerCase() === "true";
const MAX_TOOL_ROUNDS = 4;

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

// deno-lint-ignore no-explicit-any
type ChatMessage = Record<string, any>;

interface RequestBody {
  messages: IncomingMessage[];
  systemContext?: { baseCurrency?: string; locale?: string };
  financialContext?: Record<string, unknown>;
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

// ---- Layer 1: on-device snapshot folded into the system prompt ----

function financialContextBlock(ctx: unknown): string {
  if (!ctx || typeof ctx !== "object") return "";
  let json = JSON.stringify(ctx);
  if (json.length > 6000) json = `${json.slice(0, 6000)}…(truncated)`;
  return [
    "\n\nUser's current financial snapshot (assembled on their device; amounts are in their base currency). Use it to answer. If a needed figure isn't present, say what's missing and which Aiko screen would have it — do not guess:",
    json,
  ].join("\n");
}

// ---- Layer 2: read-only tool catalog (mirrors the SQL RPCs) ----
// Disabled by default. Each tool maps 1:1 to a SECURITY INVOKER Postgres
// function, so RLS keeps results scoped to the calling user.

const DATE = { type: "string", description: "ISO date, YYYY-MM-DD" } as const;

const TOOLS = [
  {
    type: "function",
    function: {
      name: "aiko_account_summary",
      description: "Net worth and the balance/type of each active account.",
      parameters: { type: "object", properties: {}, additionalProperties: false },
    },
  },
  {
    type: "function",
    function: {
      name: "aiko_budget_status",
      description: "Per-budget limit and amount spent for a date range.",
      parameters: {
        type: "object",
        properties: { start_date: DATE, end_date: DATE },
        required: ["start_date", "end_date"],
        additionalProperties: false,
      },
    },
  },
  {
    type: "function",
    function: {
      name: "aiko_spending_by_category",
      description: "Total expense per category between two dates (highest first).",
      parameters: {
        type: "object",
        properties: { start_date: DATE, end_date: DATE },
        required: ["start_date", "end_date"],
        additionalProperties: false,
      },
    },
  },
  {
    type: "function",
    function: {
      name: "aiko_cashflow_summary",
      description: "Total income vs. total expense between two dates.",
      parameters: {
        type: "object",
        properties: { start_date: DATE, end_date: DATE },
        required: ["start_date", "end_date"],
        additionalProperties: false,
      },
    },
  },
  {
    type: "function",
    function: {
      name: "aiko_recent_transactions",
      description: "The most recent transactions (date, type, amount, merchant, category).",
      parameters: {
        type: "object",
        properties: {
          max_rows: { type: "integer", description: "1-50, default 20" },
        },
        additionalProperties: false,
      },
    },
  },
  {
    type: "function",
    function: {
      name: "aiko_goal_progress",
      description: "Active savings goals with current/target amount and percent complete.",
      parameters: { type: "object", properties: {}, additionalProperties: false },
    },
  },
];

const TOOL_NAMES = new Set(TOOLS.map((t) => t.function.name));

// Execute one model-requested tool. Names are allow-listed; arguments are
// sanitized; results are RLS-scoped and size-capped. Errors are returned to the
// model as JSON rather than thrown, so a bad call never breaks the chat.
async function runTool(
  supabase: SupabaseClient,
  name: string,
  argumentsJson: string | undefined,
): Promise<string> {
  if (!TOOL_NAMES.has(name)) return JSON.stringify({ error: "unknown tool" });

  let args: Record<string, unknown> = {};
  try {
    args = argumentsJson ? JSON.parse(argumentsJson) : {};
  } catch {
    args = {};
  }

  if (name === "aiko_recent_transactions") {
    const n = Number((args as { max_rows?: unknown }).max_rows ?? 20);
    args = { max_rows: Math.min(Math.max(Number.isFinite(n) ? Math.trunc(n) : 20, 1), 50) };
  }

  try {
    const { data, error } = await supabase.rpc(name, args);
    if (error) return JSON.stringify({ error: error.message });
    let out = JSON.stringify(data ?? []);
    if (out.length > 4000) out = `${out.slice(0, 4000)}…(truncated)`;
    return out;
  } catch (e) {
    return JSON.stringify({ error: (e as Error).message });
  }
}

interface ProviderPayload {
  model: string;
  messages: ChatMessage[];
  stream: boolean;
  temperature: number;
  // deno-lint-ignore no-explicit-any
  tools?: any[];
}

function providerFetch(payload: ProviderPayload): Promise<Response> {
  return fetch(`${AI_BASE_URL}/chat/completions`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${AI_API_KEY}`,
    },
    body: JSON.stringify(payload),
  });
}

// Layer 2 resolution loop: non-streamed completions that may request tools,
// executed and fed back until the model is ready to answer (or we hit the
// round cap). Mutates and returns the message list. Best-effort: any provider
// hiccup just stops tool resolution and lets the final streamed answer proceed.
async function resolveTools(supabase: SupabaseClient, messages: ChatMessage[]): Promise<void> {
  for (let round = 0; round < MAX_TOOL_ROUNDS; round++) {
    let resp: Response;
    try {
      resp = await providerFetch({
        model: AI_MODEL,
        messages,
        stream: false,
        temperature: 0.4,
        tools: TOOLS,
      });
    } catch {
      return;
    }
    if (!resp.ok) return;

    const json = await resp.json().catch(() => null);
    const message = json?.choices?.[0]?.message;
    const toolCalls = message?.tool_calls;
    if (!message || !Array.isArray(toolCalls) || toolCalls.length === 0) return;

    messages.push({
      role: "assistant",
      content: message.content ?? "",
      tool_calls: toolCalls,
    });

    for (const call of toolCalls) {
      const result = await runTool(supabase, call?.function?.name, call?.function?.arguments);
      messages.push({ role: "tool", tool_call_id: call.id, content: result });
    }
  }
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

  // Anon client carrying the caller's JWT → every query/RPC is RLS-scoped to
  // this user. The service-role key is never used here.
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

  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return jsonResponse(400, { error: "Invalid JSON", code: "BAD_JSON" });
  }
  if (!isRequestBody(body)) {
    return jsonResponse(400, { error: "messages array is required", code: "BAD_REQUEST" });
  }

  if (!AI_API_KEY) {
    return jsonResponse(500, { error: "Server is missing AI_API_KEY", code: "MISSING_PROVIDER_KEY" });
  }

  const baseCurrency = body.systemContext?.baseCurrency ??
    (typeof body.financialContext?.baseCurrency === "string"
      ? (body.financialContext.baseCurrency as string)
      : "USD");
  const systemWithContext =
    `${SYSTEM_PROMPT}\n\nUser's base currency: ${baseCurrency}. Always render currency with that code.` +
    financialContextBlock(body.financialContext);

  const messages: ChatMessage[] = [
    { role: "system", content: systemWithContext },
    ...body.messages.slice(-20).map((m) => ({ role: m.role, content: m.content })),
  ];

  // Layer 2: let the model pull deeper data first (off by default).
  if (AI_TOOLS_ENABLED) {
    await resolveTools(supabase, messages);
  }

  // Final answer: always streamed, no tools — forces a prose reply over the
  // (possibly tool-enriched) message list.
  let upstream: Response;
  try {
    upstream = await providerFetch({
      model: AI_MODEL,
      messages,
      stream: true,
      temperature: 0.4,
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
