-- Short-lived pairing codes that link a LINE account to an Aiko user without
-- LIFF (which needs a separate LINE Login channel). Flow:
--   1. An unlinked LINE user messages the bot. The line-webhook function
--      (service-role, bypasses RLS) upserts a row here: line_user_id + a random
--      code with a ~10 min expiry, and replies the code + the connect-page URL.
--   2. The user opens the connect page (served by the same function on GET),
--      signs in with their normal Aiko email/password, and enters the code.
--      That page — under the user's own JWT — reads the matching pending row
--      and writes the line_links row (line_user_id -> user_id + refresh_token).
-- A used/expired code simply lapses; nothing here is sensitive (a LINE user id
-- is not a secret, and the code is single-use-by-convention and short-lived).

create table if not exists public.line_pairings (
  line_user_id text primary key,
  code text not null,
  expires_at timestamptz not null,
  created_at timestamptz not null default now()
);

create index if not exists line_pairings_code_idx on public.line_pairings (code);

alter table public.line_pairings enable row level security;

-- Authenticated users may look up a pending (unexpired) pairing to redeem it.
-- Only the LINE user id is exposed, and only while the code is live.
-- Writes happen exclusively through the webhook's service-role client.
create policy "line_pairings read pending" on public.line_pairings
  for select using (expires_at > now());
