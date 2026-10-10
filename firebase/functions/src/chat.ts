import { FinanceReader, financeTool } from "./finance_tools";
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

// ---- AI provider ----
// One OpenAI-compatible Chat Completions endpoint, configured via secrets:
// AI_API_KEY, AI_MODEL, AI_BASE_URL.

interface AiModel {
  readonly baseUrl: string;
  readonly model: string;
  readonly apiKey: string;
}

// The configured model, or null when AI_API_KEY/AI_MODEL/AI_BASE_URL are missing.
function buildModel(): AiModel | null {
  const apiKey = process.env.AI_API_KEY;
  const model = process.env.AI_MODEL;
  const baseUrl = process.env.AI_BASE_URL;
  if (!apiKey || !model || !baseUrl || [apiKey,model,baseUrl].includes('local-unconfigured')) return null;
  return { baseUrl, model, apiKey };
}

const MAX_TOOL_ROUNDS = 4;
const REQUEST_TIMEOUT_MS = 60_000;
const MAX_USER_MSG = 1000; // server backstop; UI caps real input at 300 chars.

// Truncate JSON sent to the model, keeping it valid by stuffing the marker
// inside a string rather than slicing mid-token.
function cap(json: string, max: number): string {
  return json.length > max
    ? `${JSON.stringify(json.slice(0, max))} /*truncated*/`
    : json;
}

const encoder = new TextEncoder();

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, content-type",
} as const;

function sseEvent(payload: Record<string, unknown>): Uint8Array {
  return encoder.encode(`data: ${JSON.stringify(payload)}\n\n`);
}

function jsonResponse(status: number, body: Record<string, unknown>): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...CORS_HEADERS },
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
  const json = cap(JSON.stringify(ctx), 6000);
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

// Read-only tools scoped to the Firebase-authenticated user.

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
// sanitized; results are user-scoped and size-capped. Errors are returned to the
// model as JSON rather than thrown, so a bad call never breaks the chat.
async function runTool(
  uid: string,
  name: string,
  argumentsJson: string | undefined,
  reader: FinanceReader,
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
    const data = await financeTool(uid, name, args, reader);
    return cap(JSON.stringify(data ?? []), 4000);
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
  entry: AiModel,
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
  entry: AiModel,
  payload: ProviderPayload,
  signal?: AbortSignal,
): Promise<Response> {
  return fetch(`${entry.baseUrl}/chat/completions`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${entry.apiKey}`,
    },
    body: JSON.stringify(payload),
    signal,
  });
}

// Layer 2 resolution: run the model through up to MAX_TOOL_ROUNDS, appending
// each tool result to `messages`. Any error abandons tool resolution silently
// and lets the streamed final answer proceed (existing behavior).
async function resolveTools(
  uid: string,
  messages: ChatMessage[],
  entry: AiModel,
): Promise<void> {
  // One reader per request: tool calls share (and never repeat) Firestore reads.
  const reader = new FinanceReader(uid);
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
      return;
    }
    cancel();
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
      const result = await runTool(
        uid,
        call?.function?.name,
        call?.function?.arguments,
        reader,
      );
      messages.push({ role: "tool", tool_call_id: call.id, content: result });
    }
  }
}

// Where streamed tokens go. The app path wraps a ReadableStream controller
// (re-emitting SSE); the LINE path collects them into a single string.
interface ChatSink {
  delta(text: string): void;
  done(): void;
  fail(message: string, code?: string): void;
}

// Stream the final answer token-by-token. A failure before any token reaches
// the client (network error, non-2xx, or an immediate stream break) is a
// PROVIDER_DOWN error. Once tokens have flowed we can't safely restart, so a
// mid-stream break is surfaced as a plain final `error` event.
async function streamAnswer(
  entry: AiModel,
  messages: ChatMessage[],
  sink: ChatSink,
): Promise<void> {
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
    sink.fail(`Provider unreachable: ${(e as Error).message}`, "PROVIDER_DOWN");
    return;
  }
  cancel();

  if (!upstream.ok || !upstream.body) {
    const text = await upstream.text().catch(() => "");
    sink.fail(`Provider error ${upstream.status}: ${text.slice(0, 200)}`, "PROVIDER_DOWN");
    return;
  }

  const decoder = new TextDecoder();
  const reader = upstream.body.getReader();
  let sentAny = false;
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
        if (!trimmed.startsWith("data:")) continue;
        const payload = trimmed.slice(5).trim();
        if (payload === "[DONE]") {
          sink.done();
          return;
        }
        try {
          const delta = JSON.parse(payload)?.choices?.[0]?.delta?.content;
          if (typeof delta === "string" && delta.length > 0) {
            sink.delta(delta);
            sentAny = true;
          }
        } catch { /* skip keepalive / non-JSON lines */ }
      }
    }
    sink.done();
  } catch (e) {
    const err = (e as Error).message;
    if (sentAny) sink.fail(`Stream failed: ${err}`);
    else sink.fail(`Provider stream broke: ${err}`, "PROVIDER_DOWN");
  } finally {
    try {
      reader.releaseLock();
    } catch { /* noop */ }
  }
}

// ============================================================
// LINE bot — webhook handling + in-process chat (no second hop)
// ============================================================

// Verify LINE's HMAC-SHA256 signature over the raw body.

export { buildModel, isRequestBody, systemPromptFor, resolveTools, streamAnswer };
