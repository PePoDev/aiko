-- Resolves the `auth_rls_initplan` PERFORMANCE advisor finding (lint 0003).
--
-- RLS policies that call `auth.uid()` directly re-evaluate it for every row
-- scanned, producing suboptimal query plans at scale. Wrapping the call in a
-- scalar subquery — `(select auth.uid())` — makes Postgres evaluate it ONCE
-- per query as an init plan and reuse the cached value.
--
-- See: https://supabase.com/docs/guides/database/postgres/row-level-security#call-functions-with-select
--
-- ALTER POLICY replaces the USING / WITH CHECK expressions in place and leaves
-- the command type (FOR ALL / SELECT / INSERT / …) and the `TO authenticated`
-- role scoping from 20260617140000 untouched. No drop/recreate needed.

-- ---- FOR ALL policies: set both USING and WITH CHECK ----
alter policy "profiles own rows" on public.profiles
  using (id = (select auth.uid())) with check (id = (select auth.uid()));

alter policy "accounts own rows" on public.accounts
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

alter policy "transactions own rows" on public.transactions
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

alter policy "transaction_splits own rows" on public.transaction_splits
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

alter policy "transaction_rules own rows" on public.transaction_rules
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

alter policy "aiko_insights own rows" on public.aiko_insights
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

alter policy "saved_calculator_scenarios own rows" on public.saved_calculator_scenarios
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

alter policy "reports own rows" on public.reports
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

alter policy "attachments own rows" on public.attachments
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

alter policy "notification_preferences own rows" on public.notification_preferences
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

alter policy "line_links own rows" on public.line_links
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

alter policy "Users manage own aiko character profiles" on public.aiko_character_profiles
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

alter policy "Users manage own import jobs" on public.import_jobs
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

alter policy "Users manage own export packages" on public.export_packages
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

alter policy "Users manage own backup snapshots" on public.backup_snapshots
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

alter policy "Users manage own credit card profiles" on public.credit_card_profiles
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

alter policy "Users manage own debt loan plans" on public.debt_loan_plans
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

alter policy "Users manage own assets" on public.assets
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

alter policy "Users manage own investment holdings" on public.investment_holdings
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

alter policy "Users manage own tax records" on public.tax_records
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

alter policy "Users manage own accounting records" on public.accounting_records
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

alter policy "Users manage own course lessons" on public.course_lessons
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

alter policy "Users manage own device sessions" on public.device_sessions
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

alter policy "Users manage own trips" on public.trips
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

alter policy "Users manage own optimization suggestions" on public.optimization_suggestions
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

alter policy "Users manage own subscription plans" on public.subscription_plans
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

-- ---- categories: split policies (SELECT reads system rows) ----
alter policy "categories select" on public.categories
  using (user_id is null or user_id = (select auth.uid()));

alter policy "categories insert" on public.categories
  with check (user_id = (select auth.uid()));

alter policy "categories update" on public.categories
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

alter policy "categories delete" on public.categories
  using (user_id = (select auth.uid()));

-- ---- category_groups: split policies (SELECT reads system group) ----
alter policy "category_groups select" on public.category_groups
  using (user_id is null or user_id = (select auth.uid()));

alter policy "category_groups insert" on public.category_groups
  with check (user_id = (select auth.uid()));

alter policy "category_groups update" on public.category_groups
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

alter policy "category_groups delete" on public.category_groups
  using (user_id = (select auth.uid()));
