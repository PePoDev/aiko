# `aiko-chat` Edge Function

Server-Sent Events proxy that streams OpenAI Chat Completions back to the
Aiko mobile assistant.

## What it does

1. Validates the caller's Supabase JWT (`Authorization: Bearer <jwt>`).
2. Confirms `profiles.ai_consent_enabled` is `true` for the user — otherwise returns `403 AI_CONSENT_OFF`.
3. Enforces a per-user in-memory rate limit (default `20` requests / minute) — returns `429 RATE_LIMITED`.
4. Sends the conversation (last 20 messages) to OpenAI's Chat Completions endpoint with `stream: true`.
5. Re-emits each token as `data: {"delta":"..."}\n\n` and closes with `data: {"done":true}\n\n`.

The mobile client (`HttpChatEngine` in `lib/features/aiko_assistant/application/chat_engine.dart`) calls `${SUPABASE_URL}/functions/v1/aiko-chat`.

## Required secrets

Set these on the Supabase project (do **not** put them in the mobile app or `.env`):

```sh
supabase secrets set OPENAI_API_KEY=sk-...
# Optional overrides:
supabase secrets set OPENAI_MODEL=gpt-4o-mini
supabase secrets set AIKO_RATE_PER_MIN=20
```

`SUPABASE_URL` and `SUPABASE_ANON_KEY` are set automatically by the Supabase CLI/runtime.

## Deploy

```sh
supabase functions deploy aiko-chat --no-verify-jwt
```

`--no-verify-jwt` is **not** used here — the function itself validates the JWT and reads the user, so the gateway-level verification is left enabled. The function uses the caller's bearer token to load the profile and call Supabase Auth.

## Local development

```sh
supabase functions serve aiko-chat --env-file ./supabase/functions/.env.local
```

The `.env.local` file should contain `OPENAI_API_KEY=sk-...`. It is git-ignored.

## Response shape

`text/event-stream` (SSE) — one event per line of the OpenAI stream.

```
data: {"delta":"You"}

data: {"delta":" have"}

data: {"delta":" $612"}

data: {"done":true}
```

## Error responses

Errors before the stream starts are JSON with a `code` the client can switch on:

| Status | `code`               | Meaning                          |
| ------ | -------------------- | -------------------------------- |
| 400    | `BAD_REQUEST`        | `messages` array missing/malformed |
| 400    | `BAD_JSON`           | Request body was not valid JSON   |
| 401    | `NO_TOKEN`           | Missing `Authorization` header   |
| 401    | `BAD_TOKEN`          | JWT rejected by Supabase Auth     |
| 403    | `AI_CONSENT_OFF`     | User has not enabled AI in Aiko   |
| 405    | `METHOD_NOT_ALLOWED` | Non-POST request                 |
| 429    | `RATE_LIMITED`       | Per-user rate limit exceeded      |
| 500    | `MISCONFIGURED`      | Function missing Supabase env     |
| 500    | `MISSING_PROVIDER_KEY` | `OPENAI_API_KEY` not set        |
| 500    | `PROFILE_LOAD_FAILED` | `profiles` table read failed     |
| 502    | `PROVIDER_DOWN`      | OpenAI unreachable                |
| 502    | `PROVIDER_ERROR`     | OpenAI returned non-OK            |

After the stream has started, errors are sent as `data: {"error":"..."}` events and the connection is closed.

## System prompt

The function prefixes every call with a fixed system prompt that defines Aiko's persona and forces the standard disclaimer line at the end of any answer that includes numbers or recommendations. The user's reported `baseCurrency` is injected so answers render in the right currency.
