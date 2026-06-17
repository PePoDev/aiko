// Aiko Chat — Supabase Edge Function.
// Streams Chat Completions from OpenAI-compatible providers as SSE, with
// automatic fallback across a code-defined chain. Validates the caller's
// Supabase JWT, folds an on-device financial snapshot (Layer 1) into the
// system prompt, and lets the model call a fixed allow-list of read-only
// Postgres RPCs (Layer 2). Each chunk is `data: {"delta":"..."}\n\n`, ending
// `data: {"done":true}`.
//
// Provider keys live only here. All data access runs under the caller's JWT
// (RLS-scoped); the function never runs model-supplied SQL. A POST carrying
// `x-line-signature` is the LINE webhook (signature verified in-code, linked
// user's token refreshed, same pipeline run in-process) — deploy with
// `--no-verify-jwt`; the app path still validates the JWT via getUser.

import {
  createClient,
  SupabaseClient,
} from "https://esm.sh/@supabase/supabase-js@2.45.0";
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

// ---- LINE bot config ----
const LINE_CHANNEL_SECRET = Deno.env.get("LINE_CHANNEL_SECRET") ?? "";
const LINE_CHANNEL_ACCESS_TOKEN = Deno.env.get("LINE_CHANNEL_ACCESS_TOKEN") ??
  "";
const PAIRING_TTL_MIN = 10;
const LINE_REPLY_ENDPOINT = "https://api.line.me/v2/bot/message/reply";
const MAX_LINE_TEXT = 4800; // LINE caps a text message at 5000 chars.
const LINE_FALLBACK =
  "Aiko is having trouble right now. Please try again in a moment.";

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

// ---- Providers & active chain ----
// Each provider is an OpenAI-compatible Chat Completions endpoint. Add one:
// declare it below, set its AI_KEY_<id> secret, add an entry to ACTIVE_CHAIN.
// The runtime tries ACTIVE_CHAIN in order; on a failure (network error,
// non-2xx, or a stream that dies before any token) it moves to the next.

interface Provider {
  readonly id: string;
  readonly label: string;
  readonly baseUrl: string;
  readonly apiKeyEnv: string;
}

interface ActiveModel {
  readonly provider: Provider;
  readonly model: string;
  readonly apiKey: string;
}

const PROVIDERS: Record<string, Provider> = {
  deepseek: {
    id: "deepseek",
    label: "DeepSeek",
    baseUrl: "https://api.deepseek.com/v1",
    apiKeyEnv: "AI_KEY_DEEPSEEK",
  },
  gemini: {
    id: "gemini",
    label: "Google Gemini",
    baseUrl: "https://generativelanguage.googleapis.com/v1beta/openai",
    apiKeyEnv: "AI_KEY_GEMINI",
  },
  openai: {
    id: "openai",
    label: "OpenAI",
    baseUrl: "https://api.openai.com/v1",
    apiKeyEnv: "AI_KEY_OPENAI",
  },
};

const ACTIVE_CHAIN: readonly { providerId: string; model: string }[] = [
  { providerId: "deepseek", model: "deepseek-v4-flash" },
  { providerId: "gemini", model: "gemini-flash" },
  { providerId: "openai", model: "gpt-oss-120b" },
];

// Skip entries whose provider/key isn't configured (missing AI_KEY_* drops
// the entry silently — runtime just moves to the next).
function buildActiveChain(): ActiveModel[] {
  return ACTIVE_CHAIN.flatMap((entry) => {
    const provider = PROVIDERS[entry.providerId];
    const apiKey = provider ? Deno.env.get(provider.apiKeyEnv) : undefined;
    return provider && apiKey ? [{ provider, model: entry.model, apiKey }] : [];
  });
}

const MAX_TOOL_ROUNDS = 4;
const REQUEST_TIMEOUT_MS = 60_000;

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

type ChatMessage = Record<string, unknown>;

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

function systemPromptFor(
  baseCurrency: string,
  financialContext?: unknown,
): string {
  return `${SYSTEM_PROMPT}\n\nUser's base currency: ${baseCurrency}. Always render currency with that code.` +
    financialContextBlock(financialContext);
}

// ---- Layer 2: read-only tool catalog (mirrors the SQL RPCs) ----
// Always on. Each tool maps 1:1 to a SECURITY INVOKER Postgres function, so
// RLS keeps results scoped to the calling user.

const DATE = { type: "string", description: "ISO date, YYYY-MM-DD" } as const;

const TOOLS = [
  {
    type: "function",
    function: {
      name: "aiko_account_summary",
      description: "Net worth and the balance/type of each active account.",
      parameters: {
        type: "object",
        properties: {},
        additionalProperties: false,
      },
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
      description:
        "Total expense per category between two dates (highest first).",
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
      description:
        "The most recent transactions (date, type, amount, merchant, category).",
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
      description:
        "Active savings goals with current/target amount and percent complete.",
      parameters: {
        type: "object",
        properties: {},
        additionalProperties: false,
      },
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
    args = {
      max_rows: Math.min(
        Math.max(Number.isFinite(n) ? Math.trunc(n) : 20, 1),
        50,
      ),
    };
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
  tools?: unknown[];
}

function payloadFor(
  entry: ActiveModel,
  messages: ChatMessage[],
  opts: { stream: boolean; tools?: unknown[] },
): ProviderPayload {
  return {
    model: entry.model,
    messages,
    temperature: 0.4,
    stream: opts.stream,
    ...(opts.tools ? { tools: opts.tools } : {}),
  };
}

function withTimeout(ms: number): { signal: AbortSignal; cancel: () => void } {
  const c = new AbortController();
  const t = setTimeout(
    () => c.abort(new Error(`Request timed out after ${ms}ms`)),
    ms,
  );
  return { signal: c.signal, cancel: () => clearTimeout(t) };
}

function providerFetch(
  entry: ActiveModel,
  payload: ProviderPayload,
  signal?: AbortSignal,
): Promise<Response> {
  return fetch(`${entry.provider.baseUrl}/chat/completions`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${entry.apiKey}`,
    },
    body: JSON.stringify(payload),
    signal,
  });
}

// Layer 2 resolution: run a single provider through MAX_TOOL_ROUNDS. Returns
// true if the provider successfully completed (even with zero tool calls),
// false on any failure so the caller can try the next entry in the chain.
async function tryResolveTools(
  supabase: SupabaseClient,
  messages: ChatMessage[],
  entry: ActiveModel,
): Promise<boolean> {
  for (let round = 0; round < MAX_TOOL_ROUNDS; round++) {
    const { signal, cancel } = withTimeout(REQUEST_TIMEOUT_MS);
    let resp: Response;
    try {
      resp = await providerFetch(
        entry,
        payloadFor(entry, messages, { stream: false, tools: TOOLS }),
        signal,
      );
    } catch {
      cancel();
      return false;
    }
    cancel();
    if (!resp.ok) return false;

    const json = await resp.json().catch(() => null);
    const message = json?.choices?.[0]?.message;
    const toolCalls = message?.tool_calls;
    if (!message || !Array.isArray(toolCalls) || toolCalls.length === 0) {
      return true;
    }

    messages.push({
      role: "assistant",
      content: message.content ?? "",
      tool_calls: toolCalls,
    });

    for (const call of toolCalls) {
      const result = await runTool(
        supabase,
        call?.function?.name,
        call?.function?.arguments,
      );
      messages.push({ role: "tool", tool_call_id: call.id, content: result });
    }
  }
  return true;
}

// Try each provider in the chain in order; the first one that successfully
// completes a tool round wins. Mid-loop errors abandon tool resolution
// silently and let the streamed final answer proceed (existing behavior).
async function resolveToolsWithChain(
  supabase: SupabaseClient,
  messages: ChatMessage[],
  chain: ActiveModel[],
): Promise<void> {
  for (const entry of chain) {
    if (await tryResolveTools(supabase, messages, entry)) return;
  }
}

// Where streamed tokens go. The app path wraps a ReadableStream controller
// (re-emitting SSE); the LINE path collects them into a single string.
interface ChatSink {
  delta(text: string): void;
  done(): void;
  fail(message: string, code?: string): void;
}

// Stream the final answer with automatic fallback. For each entry in the
// chain we attempt the request and stream its tokens. If the upstream
// fails before sending any token (network error, non-2xx, or stream break),
// we silently move to the next entry. Once tokens have flowed to the
// client we can't safely restart, so a mid-stream error is surfaced as a
// final `error` event.
async function streamWithFallback(
  chain: ActiveModel[],
  messages: ChatMessage[],
  sink: ChatSink,
): Promise<void> {
  const decoder = new TextDecoder();
  const attempts: { provider: string; model: string; error: string }[] = [];

  for (let i = 0; i < chain.length; i++) {
    const entry = chain[i];
    const { signal, cancel } = withTimeout(REQUEST_TIMEOUT_MS);
    let upstream: Response;
    try {
      upstream = await providerFetch(
        entry,
        payloadFor(entry, messages, { stream: true }),
        signal,
      );
    } catch (e) {
      cancel();
      attempts.push({
        provider: entry.provider.label,
        model: entry.model,
        error: (e as Error).message,
      });
      continue;
    }
    cancel();

    if (!upstream.ok || !upstream.body) {
      const text = await upstream.text().catch(() => "");
      attempts.push({
        provider: entry.provider.label,
        model: entry.model,
        error: `${upstream.status} ${text.slice(0, 200)}`,
      });
      continue;
    }

    const reader = upstream.body.getReader();
    let sentAny = false;
    let buffer = "";
    let failError: string | null = null;
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
            sink.done();
            try {
              reader.releaseLock();
            } catch { /* noop */ }
            return;
          }
          try {
            const json = JSON.parse(payload);
            const delta = json?.choices?.[0]?.delta?.content;
            if (typeof delta === "string" && delta.length > 0) {
              sink.delta(delta);
              sentAny = true;
            }
          } catch {
            continue;
          }
        }
      }
      sink.done();
      try {
        reader.releaseLock();
      } catch { /* noop */ }
      return;
    } catch (e) {
      failError = (e as Error).message;
    } finally {
      try {
        reader.releaseLock();
      } catch { /* noop */ }
    }

    attempts.push({
      provider: entry.provider.label,
      model: entry.model,
      error: `stream broke: ${failError ?? "unknown"}`,
    });
    if (!sentAny) continue; // no token sent yet — safe to fall back

    // Tokens already flowed; can't restart cleanly. Surface the error.
    sink.fail(`Stream failed: ${failError ?? "unknown"}`);
    return;
  }

  const summary = attempts.map((a) => `${a.provider}/${a.model}: ${a.error}`)
    .join(" | ");
  sink.fail(`All providers failed — ${summary}`, "PROVIDER_DOWN");
}

// ============================================================
// LINE bot — webhook handling + in-process chat (no second hop)
// ============================================================

const encoder = new TextEncoder();

// Verify LINE's HMAC-SHA256 signature over the raw body.
async function verifyLineSignature(
  rawBody: string,
  signature: string | null,
): Promise<boolean> {
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
  if (expected.length !== signature.length) return false;
  let diff = 0;
  for (let i = 0; i < expected.length; i++) {
    diff |= expected.charCodeAt(i) ^ signature.charCodeAt(i);
  }
  return diff === 0;
}

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

// 6 chars from an unambiguous alphabet, single active code per LINE user,
// ~10 min TTL, redeemed via the redeem_line_pairing RPC.
// ponytail: no rate limit on guessing; add one if it ever looks worth it.
function newPairingCode(): string {
  const alphabet = "ABCDEFGHJKMNPQRSTUVWXYZ23456789";
  const bytes = crypto.getRandomValues(new Uint8Array(6));
  let code = "";
  for (const b of bytes) code += alphabet[b % alphabet.length];
  return code;
}

async function startPairing(
  admin: SupabaseClient,
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

interface LinkRow {
  user_id: string;
  refresh_token: string | null;
}

// Exchange the stored refresh token for a fresh access token and rotate the
// stored one. Returns null if the link can't be refreshed (user must re-link).
async function freshAccessToken(
  admin: SupabaseClient,
  lineUserId: string,
  link: LinkRow,
): Promise<string | null> {
  if (!link.refresh_token) return null;
  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const supabaseAnon = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
  const anon = createClient(supabaseUrl, supabaseAnon, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data, error } = await anon.auth.refreshSession({
    refresh_token: link.refresh_token,
  });
  if (error || !data.session) return null;

  await admin
    .from("line_links")
    .update({
      refresh_token: data.session.refresh_token,
      updated_at: new Date().toISOString(),
    })
    .eq("line_user_id", lineUserId);

  return data.session.access_token;
}

// Run the full chat pipeline in-process as the linked user and collect the
// streamed reply into one string. Same chain/tools/system prompt as the app
// path — just a collecting sink instead of an SSE stream.
async function runAikoChat(accessToken: string, text: string): Promise<string> {
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const supabaseAnon = Deno.env.get("SUPABASE_ANON_KEY");
  if (!supabaseUrl || !supabaseAnon) return LINE_FALLBACK;

  const supabase = createClient(supabaseUrl, supabaseAnon, {
    auth: { persistSession: false },
    global: { headers: { Authorization: `Bearer ${accessToken}` } },
  });

  const chain = buildActiveChain();
  if (chain.length === 0) return LINE_FALLBACK;

  // No on-device snapshot over LINE (Layer 1). Pull base currency so money is
  // labelled correctly; Layer 2 tools (when enabled) fetch the rest.
  const { data: profile } = await supabase.from("profiles").select(
    "base_currency",
  ).maybeSingle();
  const baseCurrency =
    (profile as { base_currency?: string } | null)?.base_currency ?? "USD";

  const messages: ChatMessage[] = [
    { role: "system", content: systemPromptFor(baseCurrency) },
    { role: "user", content: text },
  ];

  await resolveToolsWithChain(supabase, messages, chain);

  let answer = "";
  const sink: ChatSink = {
    delta: (t) => {
      answer += t;
    },
    done: () => {},
    fail: () => {},
  };
  await streamWithFallback(chain, messages, sink);

  return answer.trim() || LINE_FALLBACK;
}

async function handleTextMessage(
  admin: SupabaseClient,
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
      `Your Aiko sign-in expired — let's reconnect.\n\n${await startPairing(
        admin,
        lineUserId,
      )}`,
    );
    return;
  }

  await replyToLine(replyToken, await runAikoChat(token, text));
}

async function handleLineEvents(rawBody: string): Promise<void> {
  let body: { events?: unknown };
  try {
    body = JSON.parse(rawBody);
  } catch {
    return;
  }
  const events = Array.isArray(body.events) ? body.events : [];
  if (events.length === 0) return;

  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  const admin = createClient(Deno.env.get("SUPABASE_URL") ?? "", serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  for (const event of events as Array<Record<string, unknown>>) {
    const lineUserId = (event?.source as Record<string, unknown> | undefined)
      ?.userId;
    const replyToken = event?.replyToken;
    if (typeof lineUserId !== "string" || typeof replyToken !== "string") {
      continue;
    }

    if (event.type === "follow") {
      await replyToLine(replyToken, await startPairing(admin, lineUserId));
      continue;
    }
    if (event.type === "message") {
      const message = event.message as Record<string, unknown> | undefined;
      if (message?.type === "text") {
        await handleTextMessage(
          admin,
          lineUserId,
          replyToken,
          String(message.text ?? ""),
        );
      }
    }
  }
}

// LINE webhook entry. Identified by the x-line-signature header (no Supabase
// JWT). Verifies the signature itself and never trusts unsigned POSTs.
async function handleLineWebhook(req: Request): Promise<Response> {
  if (
    !Deno.env.get("SUPABASE_URL") ||
    !Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ||
    !LINE_CHANNEL_SECRET || !LINE_CHANNEL_ACCESS_TOKEN
  ) {
    // Misconfigured — ack so LINE doesn't retry endlessly, but do nothing.
    return new Response("ok", { status: 200 });
  }

  const rawBody = await req.text();
  if (
    !(await verifyLineSignature(rawBody, req.headers.get("x-line-signature")))
  ) {
    return new Response("Bad signature", { status: 401 });
  }

  await handleLineEvents(rawBody);
  return new Response("ok", { status: 200 });
}

serve(async (req) => {
  // LINE webhook path — a POST carrying LINE's signature header.
  if (req.method === "POST" && req.headers.get("x-line-signature") !== null) {
    return handleLineWebhook(req);
  }

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
    return jsonResponse(405, {
      error: "Method not allowed",
      code: "METHOD_NOT_ALLOWED",
    });
  }

  const authHeader = req.headers.get("authorization") ?? "";
  const jwt = authHeader.startsWith("Bearer ") ? authHeader.slice(7) : null;
  if (!jwt) {
    return jsonResponse(401, {
      error: "Missing bearer token",
      code: "NO_TOKEN",
    });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const supabaseAnon = Deno.env.get("SUPABASE_ANON_KEY");
  if (!supabaseUrl || !supabaseAnon) {
    return jsonResponse(500, {
      error: "Server is not configured",
      code: "MISCONFIGURED",
    });
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

  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return jsonResponse(400, { error: "Invalid JSON", code: "BAD_JSON" });
  }
  if (!isRequestBody(body)) {
    return jsonResponse(400, {
      error: "messages array is required",
      code: "BAD_REQUEST",
    });
  }

  const chain = buildActiveChain();
  if (chain.length === 0) {
    return jsonResponse(500, {
      error:
        "Server is missing AI provider configuration. Set at least one AI_KEY_* secret matching an entry in the active chain.",
      code: "MISSING_PROVIDER_KEY",
    });
  }

  const baseCurrency = body.systemContext?.baseCurrency ??
    (typeof body.financialContext?.baseCurrency === "string"
      ? (body.financialContext.baseCurrency as string)
      : "USD");

  const messages: ChatMessage[] = [
    {
      role: "system",
      content: systemPromptFor(baseCurrency, body.financialContext),
    },
    ...body.messages.slice(-20).map((m) => ({
      role: m.role,
      content: m.content,
    })),
  ];

  // Layer 2: let the model pull deeper data first.
  await resolveToolsWithChain(supabase, messages, chain);

  // Final answer: always streamed, no tools — forces a prose reply over the
  // (possibly tool-enriched) message list. Provider/model is selected per
  // chain entry by the fallback loop.
  const stream = new ReadableStream<Uint8Array>({
    async start(controller) {
      const sink: ChatSink = {
        delta: (t) => controller.enqueue(sseEvent({ delta: t })),
        done: () => {
          controller.enqueue(sseEvent({ done: true }));
          try {
            controller.close();
          } catch { /* noop */ }
        },
        fail: (msg, code) => {
          controller.enqueue(
            sseEvent(code ? { error: msg, code } : { error: msg }),
          );
          try {
            controller.close();
          } catch { /* noop */ }
        },
      };
      await streamWithFallback(chain, messages, sink);
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
