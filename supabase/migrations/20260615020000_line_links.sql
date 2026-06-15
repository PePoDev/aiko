-- Links a LINE messaging account to an Aiko (Supabase) user so the LINE bot can
-- answer with that user's RLS-scoped financial data. The user signs in with
-- their normal Aiko credentials inside a LIFF page (see the line-webhook Edge
-- function); that page writes this row under the user's own JWT.
--
-- The stored refresh_token lets the line-webhook function mint a fresh,
-- per-user access token on each inbound message and then call the existing
-- aiko-chat function as that user. The webhook reads this table with the
-- service-role key (server-side only — never shipped to a client), since an
-- incoming LINE event carries no Supabase JWT.

create table if not exists public.line_links (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  line_user_id text not null unique,
  -- Supabase refresh token captured at link time; rotated by the webhook.
  refresh_token text,
  display_name text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists line_links_user_id_idx
  on public.line_links (user_id);

alter table public.line_links enable row level security;

-- A signed-in user manages only their own link (the LIFF page upserts here
-- under the user's JWT). The webhook bypasses RLS via the service-role key.
create policy "line_links own rows" on public.line_links
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());
