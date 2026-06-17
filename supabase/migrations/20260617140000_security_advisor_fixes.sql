-- Resolves the Supabase Database Security Advisor findings:
--
--   0014 extension_in_public                         -> pg_net in `public`
--   0028 anon_security_definer_function_executable   -> redeem_line_pairing
--   0029 authenticated_security_definer_function_executable -> redeem_line_pairing
--   0012 auth_allow_anonymous_sign_ins               -> all RLS policies default to PUBLIC
--
-- (auth_leaked_password_protection is a Dashboard Auth setting, not a SQL fix:
--  Authentication → Providers → Email → Leaked password protection = ON.)

-- =============================================================================
-- 1. Move pg_net out of the `public` schema (lint 0014).
-- =============================================================================
-- pg_net is `relocatable = false` but hardcodes its own `net` schema (every
-- object is created as `net.*`), so it CANNOT be relocated in place
-- (`alter extension pg_net set schema extensions` errors). The supported path
-- is drop + recreate WITH SCHEMA extensions: `pg_extension.extnamespace` moves
-- to `extensions`, and the `net` schema + `net.http_post` etc. are recreated
-- unchanged, so the pg_cron purge job keeps calling `net.http_post`.
--
-- Side effect: the transient `net.http_request_queue` / `net._http_response`
-- unlogged tables (queued/in-flight requests, 6h response TTL) are dropped.
-- Safe to run — the only consumer is the hourly purge cron, which re-queues on
-- its next tick.
drop extension if exists pg_net;
create extension pg_net with schema extensions;

-- =============================================================================
-- 2. Lock down redeem_line_pairing (lints 0028 + 0029).
-- =============================================================================
-- Postgres grants EXECUTE to PUBLIC for every new function; `anon` and
-- `authenticated` inherit that grant. The function already did
-- `grant execute to authenticated`, but never revoked PUBLIC, so `anon` could
-- still call it. `redeem_line_pairing` is intentionally SECURITY DEFINER
-- (it writes `line_links` server-side, and the `line_pairings` table is not
-- client-readable), so we keep SECURITY DEFINER and just close the PUBLIC hole.
revoke execute on function public.redeem_line_pairing(text, text) from public, anon;

-- =============================================================================
-- 3. Scope every RLS policy to `authenticated` (lint 0012).
-- =============================================================================
-- A policy created without `TO <role>` defaults to `TO PUBLIC`, which `anon`
-- inherits — so every table read as "anonymous access allowed". The app has
-- no anonymous-sign-in flow, so every policy is tightened to `TO authenticated`.
-- Postgres has no ALTER POLICY for the role list, so each is dropped + recreated.
-- The predicates are unchanged; only the role scoping is added.

-- ---- 002_initial_product_rls.sql: FOR ALL policies (same predicate for all ops) ----
drop policy if exists "profiles own rows" on public.profiles;
create policy "profiles own rows" on public.profiles
  for all to authenticated
  using (id = auth.uid()) with check (id = auth.uid());

drop policy if exists "accounts own rows" on public.accounts;
create policy "accounts own rows" on public.accounts
  for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists "transactions own rows" on public.transactions;
create policy "transactions own rows" on public.transactions
  for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists "transaction_splits own rows" on public.transaction_splits;
create policy "transaction_splits own rows" on public.transaction_splits
  for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists "transaction_rules own rows" on public.transaction_rules;
create policy "transaction_rules own rows" on public.transaction_rules
  for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists "aiko_insights own rows" on public.aiko_insights;
create policy "aiko_insights own rows" on public.aiko_insights
  for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists "saved_calculator_scenarios own rows" on public.saved_calculator_scenarios;
create policy "saved_calculator_scenarios own rows" on public.saved_calculator_scenarios
  for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists "reports own rows" on public.reports;
create policy "reports own rows" on public.reports
  for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists "attachments own rows" on public.attachments;
create policy "attachments own rows" on public.attachments
  for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists "notification_preferences own rows" on public.notification_preferences;
create policy "notification_preferences own rows" on public.notification_preferences
  for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- ---- line_links (20260615020000): FOR ALL -> add TO authenticated ----
drop policy if exists "line_links own rows" on public.line_links;
create policy "line_links own rows" on public.line_links
  for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- ---- 005_product_expansion_rls.sql: FOR ALL policies -> add TO authenticated ----
drop policy if exists "Users manage own aiko character profiles" on public.aiko_character_profiles;
create policy "Users manage own aiko character profiles"
  on public.aiko_character_profiles for all to authenticated
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "Users manage own import jobs" on public.import_jobs;
create policy "Users manage own import jobs"
  on public.import_jobs for all to authenticated
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "Users manage own export packages" on public.export_packages;
create policy "Users manage own export packages"
  on public.export_packages for all to authenticated
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "Users manage own backup snapshots" on public.backup_snapshots;
create policy "Users manage own backup snapshots"
  on public.backup_snapshots for all to authenticated
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "Users manage own credit card profiles" on public.credit_card_profiles;
create policy "Users manage own credit card profiles"
  on public.credit_card_profiles for all to authenticated
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "Users manage own debt loan plans" on public.debt_loan_plans;
create policy "Users manage own debt loan plans"
  on public.debt_loan_plans for all to authenticated
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "Users manage own assets" on public.assets;
create policy "Users manage own assets"
  on public.assets for all to authenticated
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "Users manage own investment holdings" on public.investment_holdings;
create policy "Users manage own investment holdings"
  on public.investment_holdings for all to authenticated
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "Users manage own tax records" on public.tax_records;
create policy "Users manage own tax records"
  on public.tax_records for all to authenticated
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "Users manage own accounting records" on public.accounting_records;
create policy "Users manage own accounting records"
  on public.accounting_records for all to authenticated
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "Users manage own course lessons" on public.course_lessons;
create policy "Users manage own course lessons"
  on public.course_lessons for all to authenticated
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "Users manage own device sessions" on public.device_sessions;
create policy "Users manage own device sessions"
  on public.device_sessions for all to authenticated
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "Users manage own trips" on public.trips;
create policy "Users manage own trips"
  on public.trips for all to authenticated
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "Users manage own optimization suggestions" on public.optimization_suggestions;
create policy "Users manage own optimization suggestions"
  on public.optimization_suggestions for all to authenticated
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "Users manage own subscription plans" on public.subscription_plans;
create policy "Users manage own subscription plans"
  on public.subscription_plans for all to authenticated
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ---- categories: split policies already exist, just add TO authenticated ----
-- (SELECT reads system rows with user_id IS NULL, writes stay user-scoped.)
drop policy if exists "categories select" on public.categories;
create policy "categories select" on public.categories
  for select to authenticated
  using (user_id is null or user_id = auth.uid());

drop policy if exists "categories insert" on public.categories;
create policy "categories insert" on public.categories
  for insert to authenticated with check (user_id = auth.uid());

drop policy if exists "categories update" on public.categories;
create policy "categories update" on public.categories
  for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists "categories delete" on public.categories;
create policy "categories delete" on public.categories
  for delete to authenticated using (user_id = auth.uid());

-- ---- category_groups: split policies, add TO authenticated ----
drop policy if exists "category_groups select" on public.category_groups;
create policy "category_groups select" on public.category_groups
  for select to authenticated
  using (user_id is null or user_id = auth.uid());

drop policy if exists "category_groups insert" on public.category_groups;
create policy "category_groups insert" on public.category_groups
  for insert to authenticated with check (user_id = auth.uid());

drop policy if exists "category_groups update" on public.category_groups;
create policy "category_groups update" on public.category_groups
  for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists "category_groups delete" on public.category_groups;
create policy "category_groups delete" on public.category_groups
  for delete to authenticated using (user_id = auth.uid());

-- ---- Storage: private buckets scoped to authenticated; avatars stays public-read ----
-- receipts/documents/exports are private buckets. Their policies were implicitly
-- PUBLIC; scope to authenticated.
drop policy if exists "users read own storage objects" on storage.objects;
create policy "users read own storage objects" on storage.objects
  for select to authenticated using (
    bucket_id in ('receipts', 'documents', 'exports')
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "users insert own storage objects" on storage.objects;
create policy "users insert own storage objects" on storage.objects
  for insert to authenticated with check (
    bucket_id in ('receipts', 'documents', 'exports')
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "users update own storage objects" on storage.objects;
create policy "users update own storage objects" on storage.objects
  for update to authenticated using (
    bucket_id in ('receipts', 'documents', 'exports')
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id in ('receipts', 'documents', 'exports')
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "users delete own storage objects" on storage.objects;
create policy "users delete own storage objects" on storage.objects
  for delete to authenticated using (
    bucket_id in ('receipts', 'documents', 'exports')
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- Avatar policies: the `avatars` bucket is intentionally public-readable (a
-- stable URL renders across devices without signed URLs), so the SELECT stays
-- WITHOUT `TO authenticated` (true anonymous read). Writes stay authenticated.
-- This is the one intentional exception; the Advisor will keep flagging the
-- `avatars are publicly readable` SELECT — that is by design for a public
-- avatar bucket and accepted.
drop policy if exists "users upload their own avatar" on storage.objects;
create policy "users upload their own avatar" on storage.objects
  for insert to authenticated with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "users update their own avatar" on storage.objects;
create policy "users update their own avatar" on storage.objects
  for update to authenticated using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "users delete their own avatar" on storage.objects;
create policy "users delete their own avatar" on storage.objects
  for delete to authenticated using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- =============================================================================
-- 4. Best-effort hardening of pg_cron's internal tables (lint 0012 for
--    cron.job / job_run_details).
-- =============================================================================
-- These are scheduler internals, not user data — the app/API roles must never
-- touch them. On self-hosted Supabase (postgres = superuser) this drops pg_cron's
-- default policies (which default to PUBLIC) and revokes all API-role access.
--
-- On Supabase Cloud the migration role is NOT the owner of cron.* (the platform
-- installs pg_cron, so `create extension if not exists pg_cron` in an earlier
-- migration no-op'd and the platform retained ownership). ALTER/DROP/REVOKE on
-- extension-owned tables raise `insufficient_privilege` (42501), which we catch
-- and accept: the finding is a FALSE POSITIVE there anyway, because pg_cron's
-- default policy `USING (username = current_user)` returns 0 rows for anon
-- (no scheduled job runs as `username = 'anon'`). RLS with no matching rows is
-- functionally deny-by-default, so anon cannot read cron data.
do $$
begin
  alter table cron.job disable row level security;
  alter table cron.job_run_details disable row level security;
  drop policy if exists cron_job_policy on cron.job;
  drop policy if exists cron_job_run_details_policy on cron.job_run_details;
  revoke all on cron.job from public, anon, authenticated;
  revoke all on cron.job_run_details from public, anon, authenticated;
  revoke all on sequence cron.jobid_seq from public, anon, authenticated;
  revoke all on sequence cron.runid_seq from public, anon, authenticated;
exception
  when insufficient_privilege then
    raise notice 'Skipped cron.* hardening (migration role is not the owner on Supabase Cloud). The auth_allow_anonymous_sign_ins finding for cron.job/job_run_details is an accepted false positive: the default policy USING (username = current_user) already returns 0 rows for anon.';
end
$$;
