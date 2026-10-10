import * as logger from "firebase-functions/logger";
import { FinanceReader, financeTool } from "./finance_tools";
const SYSTEM_PROMPT = [
  "You are Aiko, a friendly, warm, and supportive personal finance companion in the Aiko app.",
  "You are not a certified financial advisor — every response that gives numbers, recommendations, or projections MUST end with the disclaimer line given below, on its own line.",
  "Never shame or judge the user. If you don't have enough data, say so plainly and suggest the screen in Aiko that would help (Accounts, Budgets, Goals, Transactions).",
  "Prefer short, skimmable answers. Use the user's reported base currency. Round to two decimals. Avoid jargon.",
  "Do not promise features that don't exist in Aiko. Do not request sensitive data (SSN, full card numbers, passwords).",
  "Base every number on the provided snapshot or tool results — never invent figures.",
  "If the user asks something unrelated to personal finance, gently steer back to their spending, budgets, or goals.",
].join(" ");

// Disclaimers the app recognizes (it shows the trailing line below a divider).
const DISCLAIMERS = {
  en: "Aiko provides estimates, not certified financial advice.",
  th: "Aiko ให้ข้อมูลเชิงประมาณการ ไม่ใช่คำแนะนำทางการเงินจากผู้เชี่ยวชาญที่ได้รับอนุญาต",
} as const;

// The app sends its UI language ("en" or "th"); LINE sends none, so Aiko
// mirrors the language of the user's message.
function languageInstruction(locale?: string): string {
  const code = locale?.toLowerCase().split(/[-_]/)[0];
  if (code === "th") {
    return "Always reply in Thai (ภาษาไทย), using polite, warm Thai (Aiko speaks as a woman, ending sentences with ค่ะ/นะคะ where natural). Keep currency codes and app screen names readable. " +
      `Disclaimer line: "${DISCLAIMERS.th}"`;
  }
  if (code === "en") {
    return `Always reply in English. Disclaimer line: "${DISCLAIMERS.en}"`;
  }
  return "Reply in the same language as the user's latest message (Thai or English). " +
    `Disclaimer line in English: "${DISCLAIMERS.en}" — in Thai: "${DISCLAIMERS.th}"`;
}

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
// Each provider request, including reading its whole body or stream.
const REQUEST_TIMEOUT_MS = 60_000;
// The whole answer (tool rounds + final answer), so a slow provider ends with
// an error event well before the 300 s function timeout kills the request.
const CHAT_DEADLINE_MS = 240_000;
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
  locale?: string,
): string {
  return `${SYSTEM_PROMPT}\n\n${languageInstruction(locale)}\n\nUser's base currency: ${baseCurrency}. Always render currency with that code.` +
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

// A provider request is cancelled when its own timeout elapses or `parent`
// aborts (client gone, chat deadline). Body reads honor the same signal, so a
// stalled body or stream cannot hold the request open.
function requestSignal(parent?: AbortSignal): AbortSignal {
  const timeout = AbortSignal.timeout(REQUEST_TIMEOUT_MS);
  return parent ? AbortSignal.any([parent, timeout]) : timeout;
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
// each tool result to `messages`. Returns the model's answer when a round ends
// without tool calls, so the caller sends it instead of asking the provider a
// second time. Returns null when the answer still has to be streamed: every
// round asked for tools, the model wrote nothing, or an error occurred (tool
// resolution is abandoned silently and the streamed answer proceeds).
async function resolveTools(
  uid: string,
  messages: ChatMessage[],
  entry: AiModel,
  signal?: AbortSignal,
): Promise<string | null> {
  // One reader per request: tool calls share (and never repeat) Firestore reads.
  const reader = new FinanceReader(uid);
  for (let round = 0; round < MAX_TOOL_ROUNDS; round++) {
    if (signal?.aborted) return null;
    let message: { content?: unknown; tool_calls?: unknown } | undefined;
    try {
      const resp = await providerFetch(
        entry,
        payloadFor(entry, messages, { stream: false, tools: TOOLS }),
        requestSignal(signal),
      );
      if (!resp.ok) {
        await resp.body?.cancel().catch(() => {});
        return null;
      }
      message = (await resp.json())?.choices?.[0]?.message;
    } catch {
      return null;
    }
    if (!message) return null;

    const toolCalls = message.tool_calls;
    if (!Array.isArray(toolCalls) || toolCalls.length === 0) {
      const content = message.content;
      return typeof content === "string" && content.trim() !== "" ? content : null;
    }

    messages.push({
      role: "assistant",
      content: message.content ?? "",
      tool_calls: toolCalls,
    });

    // Calls of one round are independent; FinanceReader shares their reads.
    const results = await Promise.all(
      toolCalls.map((call) =>
        runTool(uid, call?.function?.name, call?.function?.arguments, reader)
      ),
    );
    toolCalls.forEach((call, i) => {
      messages.push({ role: "tool", tool_call_id: call?.id, content: results[i] });
    });
  }
  return null;
}

// Stable error codes sent to clients; provider details stay in the logs.
// PROVIDER_DOWN: no answer text was sent (provider unreachable, non-2xx,
// timeout, or an immediate stream break). STREAM_FAILED: the stream broke
// after some text was sent.
type ChatErrorCode = "PROVIDER_DOWN" | "STREAM_FAILED";

// Where answer text goes. The app path re-emits it as SSE; the LINE path
// collects it into a single reply.
interface ChatSink {
  delta(text: string): void;
  done(): void;
  fail(code: ChatErrorCode): void;
}

function failChat(sink: ChatSink, code: ChatErrorCode, detail: string): void {
  logger.warn("Aiko chat provider failure", { code, detail });
  sink.fail(code);
}

const errorText = (e: unknown): string =>
  e instanceof Error ? `${e.name}: ${e.message}` : String(e);

// Splits a finished answer into a few deltas (at a space where possible, never
// inside a surrogate pair) so the app's streaming protocol and UI stay the same.
function answerChunks(text: string, size = 80): string[] {
  const chunks: string[] = [];
  let start = 0;
  while (start < text.length) {
    let end = Math.min(start + size, text.length);
    if (end < text.length) {
      const space = text.lastIndexOf(" ", end - 1);
      if (space > start) {
        end = space + 1;
      } else if (end - 1 > start && /[\uD800-\uDBFF]/.test(text[end - 1])) {
        end -= 1;
      }
    }
    chunks.push(text.slice(start, end));
    start = end;
  }
  return chunks;
}

// Stream the final answer token-by-token. A failure before any token reaches
// the client is PROVIDER_DOWN. Once tokens have flowed we can't safely
// restart, so a mid-stream break is STREAM_FAILED.
async function streamAnswer(
  entry: AiModel,
  messages: ChatMessage[],
  sink: ChatSink,
  signal?: AbortSignal,
): Promise<void> {
  if (signal?.aborted) {
    failChat(sink, "PROVIDER_DOWN", `Not sent: ${errorText(signal.reason)}`);
    return;
  }
  const requestAbort = requestSignal(signal);
  let upstream: Response;
  try {
    upstream = await providerFetch(
      entry,
      payloadFor(entry, messages, { stream: true }),
      requestAbort,
    );
  } catch (e) {
    failChat(sink, "PROVIDER_DOWN", `Provider unreachable: ${errorText(e)}`);
    return;
  }

  if (!upstream.ok || !upstream.body) {
    const text = await upstream.text().catch(() => "");
    failChat(
      sink,
      "PROVIDER_DOWN",
      `Provider error ${upstream.status}: ${text.slice(0, 500)}`,
    );
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
    // Reads reject when the request times out or the caller aborts too.
    const reason = requestAbort.aborted ? requestAbort.reason : e;
    if (sentAny) {
      failChat(sink, "STREAM_FAILED", `Stream failed: ${errorText(reason)}`);
    } else {
      failChat(sink, "PROVIDER_DOWN", `Provider stream broke: ${errorText(reason)}`);
    }
  } finally {
    // Frees the connection even when we stop at [DONE] before the body ends.
    await reader.cancel().catch(() => {});
  }
}

// One chat answer: tool rounds, then either the answer the model already wrote
// (a message that needs no tools costs one provider call) or a streamed one.
// `signal` cancels everything, for example when the client disconnects; the
// whole answer is also bounded by CHAT_DEADLINE_MS.
async function answerChat(
  uid: string,
  messages: ChatMessage[],
  entry: AiModel,
  sink: ChatSink,
  signal?: AbortSignal,
): Promise<void> {
  const deadline = AbortSignal.timeout(CHAT_DEADLINE_MS);
  const bounded = signal ? AbortSignal.any([signal, deadline]) : deadline;
  const answer = await resolveTools(uid, messages, entry, bounded);
  if (answer !== null) {
    for (const chunk of answerChunks(answer)) sink.delta(chunk);
    sink.done();
    return;
  }
  await streamAnswer(entry, messages, sink, bounded);
}

export {
  answerChat,
  answerChunks,
  buildModel,
  isRequestBody,
  resolveTools,
  streamAnswer,
  systemPromptFor,
};
export type { AiModel, ChatErrorCode, ChatSink };
