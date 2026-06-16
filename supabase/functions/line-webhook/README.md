# Aiko × LINE bot (`line-webhook`)

Lets users chat with Aiko from LINE using their **own** financial data. The bot
hands out a short pairing code; the user opens the function's connect page
(plain web — no LIFF), signs in once with their normal Aiko email/password and
enters the code. After that, every LINE message is answered by the existing
**`aiko-chat`** function called with that user's JWT (so Postgres RLS scopes the
data).

```
LINE message ─▶ line-webhook (POST)
                 ├─ verify x-line-signature (HMAC-SHA256, channel secret)
                 ├─ look up line_links[line_user_id]      (service-role)
                 │    └─ if unlinked: upsert line_pairings(code) + reply the code
                 ├─ refresh the user's access token        (anon + stored refresh_token)
                 ├─ POST aiko-chat  (Bearer <user jwt>)    ← reuses the same function
                 └─ reply via LINE Messaging API
line-webhook (GET) ─▶ connect page: sign in + enter code → write line_links (user's JWT)
```

## One-time setup

### 1. Database

```bash
supabase db push   # applies 20260615020000_line_links.sql + 20260617010000_line_pairings.sql
```

### 2. LINE Developers console (https://developers.line.biz)

1. Create a **Messaging API** channel. Note the **Channel secret** and issue a
   long-lived **Channel access token**.
2. Set the **Webhook URL** to this function's URL
   (`https://<project-ref>.functions.supabase.co/line-webhook`) and enable
   "Use webhook". Disable auto-reply/greeting messages so the bot controls
   replies. (No LIFF app — linking uses a pairing code.)

### 3. Supabase secrets

```bash
supabase secrets set LINE_CHANNEL_SECRET=...
supabase secrets set LINE_CHANNEL_ACCESS_TOKEN=...
# SUPABASE_URL / SUPABASE_ANON_KEY / SUPABASE_SERVICE_ROLE_KEY are injected by
# the runtime. The service-role key is read ONLY here (server-side) to look up
# and rotate the LINE link — it is never sent to a client.
```

### 4. Deploy

```bash
supabase functions deploy line-webhook --no-verify-jwt
```

> `--no-verify-jwt` is required: LINE's webhook calls carry a LINE signature,
> not a Supabase JWT. This function verifies LINE's `x-line-signature` itself
> and never trusts unsigned POSTs.

## Using it

1. Add the bot as a LINE friend (QR from the console).
2. Send any message → the bot replies with a 6-char pairing code + connect link.
3. Open the link (any browser), sign in with your Aiko email/password, enter the
   code → "Connected!".
4. Ask Aiko about your money in LINE — e.g. "How much can I safely spend?".

## Notes & limits

- Replies are non-streamed: the webhook collects the full `aiko-chat` SSE stream
  and sends one LINE text message (capped at ~4800 chars).
- The disclaimer rule in `aiko-chat`'s system prompt still applies — numeric
  answers end with "Aiko provides estimates, not certified financial advice."
- Pairing codes are 6 chars, single active per LINE user, ~10 min TTL; redeemed
  on the connect page under the user's JWT. Re-linking just means messaging the
  bot again for a fresh code; `line_links` is upserted on `line_user_id`.
- The provider/AI key lives only in `aiko-chat`; this function never sees it.
