# LINE bot — setup checklist (action needed)

The Aiko × LINE bot is built (`supabase/functions/line-webhook/`,
migration `20260615020000_line_links.sql`), but it **cannot be deployed or
tested until you provision a LINE channel and set the secrets below**.

Work top to bottom — each step unblocks the next.

---

## 1. Apply the database migration

```bash
supabase db push        # creates public.line_links (+ RLS)
```

## 2. Create the LINE channel (LINE Developers console)

https://developers.line.biz → your provider →

- [ ] Create a **Messaging API** channel.
- [ ] Copy the **Channel secret** (Basic settings).
- [ ] Issue a long-lived **Channel access token** (Messaging API tab).
- [ ] Disable the default **auto-reply** and **greeting** messages so the bot
      controls its own replies (Messaging API tab → "Auto-reply messages" off).

## 3. Create the LIFF app (same channel)

LINE console → your channel → **LIFF** tab → Add:

- [ ] Size: **Tall** (or Full).
- [ ] Endpoint URL: the **GET** URL of the function —
      `https://<project-ref>.functions.supabase.co/line-webhook`
- [ ] Scopes: **profile**, **openid**.
- [ ] Copy the **LIFF ID** (looks like `1234567890-abcdEFGh`).

## 4. Point the webhook at the function

LINE console → Messaging API tab →

- [ ] Webhook URL: `https://<project-ref>.functions.supabase.co/line-webhook`
- [ ] Toggle **Use webhook** on.

## 5. Set the Supabase secrets

```bash
supabase secrets set LINE_CHANNEL_SECRET=...
supabase secrets set LINE_CHANNEL_ACCESS_TOKEN=...
supabase secrets set LINE_LIFF_ID=...
```

> `SUPABASE_URL`, `SUPABASE_ANON_KEY`, and `SUPABASE_SERVICE_ROLE_KEY` are
> injected by the runtime — do not set them. The service-role key is read
> **only** inside this server-side function (to look up / rotate the LINE link);
> it is never sent to a client. The AI provider key stays only in `aiko-chat`.

## 6. Deploy

```bash
supabase functions deploy line-webhook --no-verify-jwt
```

> `--no-verify-jwt` is required: LINE calls carry a LINE signature, not a
> Supabase JWT. The function verifies `x-line-signature` itself and rejects
> unsigned POSTs.

---

## 7. Smoke test

- [ ] Add the bot as a friend (QR code in the Messaging API tab).
- [ ] Send any message → bot replies with a **login link** (the LIFF page).
- [ ] Open it, sign in with your **Aiko email + password** → "Connected!".
- [ ] Ask: *"How much can I safely spend?"* → Aiko answers from your data,
      ending with the standard estimates disclaimer.

## How it fits together

```
LINE message ─▶ line-webhook (POST)
                 ├─ verify x-line-signature
                 ├─ line_links[line_user_id]        (service-role lookup)
                 ├─ refresh user access token        (stored refresh_token)
                 ├─ POST aiko-chat (Bearer user JWT) ← reuses the same function
                 └─ reply via LINE Messaging API
line-webhook (GET) ─▶ LIFF login page (writes line_links under the user's JWT)
```

## Troubleshooting

| Symptom | Likely cause |
| --- | --- |
| Bot never replies | Webhook URL wrong, or "Use webhook" off, or `--no-verify-jwt` omitted |
| "Open this page from inside LINE" | LIFF endpoint URL / LIFF ID mismatch; open via the bot's link, not a browser |
| Always asks you to log in again | `line_links` write blocked (check RLS / that you signed in with a real Aiko account), or refresh token rotated/expired |
| "Aiko is having trouble" | `aiko-chat` not deployed or its `AI_API_KEY` not set |

Reference implementation details: `supabase/functions/line-webhook/README.md`.
