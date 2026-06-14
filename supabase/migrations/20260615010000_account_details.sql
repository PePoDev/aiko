-- supabase/migrations/20260615010000_account_details.sql
alter table public.accounts
  add column if not exists details jsonb not null default '{}'::jsonb;

-- RLS policies already cover the new column via existing account_id checks.
-- No additional policy required.
