-- Resolves the `unindexed_foreign_keys` PERFORMANCE advisor finding (lint 0001).
--
-- A foreign key does NOT auto-create an index on the referencing (child) column.
-- Without one, cascade deletes/updates and parent->child joins degrade to a
-- sequential scan of the child table. This adds a single-column B-tree index on
-- every flagged FK column. `IF NOT EXISTS` makes the migration idempotent and
-- safe to re-run.
--
-- Note: `transactions_user_date_idx` already leads with `user_id`, but the
-- advisor flags the FK by constraint name, not by checking covering indexes, so
-- `transactions_user_id_fkey` is NOT in this list (already covered). The FKs
-- below are the ones genuinely missing a covering index.
--
-- The 3 `unused_index` findings (line_links_user_id_idx,
-- profiles_deletion_scheduled_at_idx, categories_group_id_idx) are intentionally
-- KEPT: each serves a real query path (LINE webhook lookup, hourly purge cron,
-- category grouping) that simply hasn't fired since the dev DB's stats reset.
-- Dropping them would regress production; INFO-level unused-on-dev is expected.

-- ---- accounting_records ----
create index if not exists accounting_records_transaction_id_idx
  on public.accounting_records (transaction_id);
create index if not exists accounting_records_user_id_idx
  on public.accounting_records (user_id);

-- ---- accounts ----
create index if not exists accounts_user_id_idx
  on public.accounts (user_id);

-- ---- aiko_insights ----
create index if not exists aiko_insights_user_id_idx
  on public.aiko_insights (user_id);

-- ---- assets ----
create index if not exists assets_user_id_idx
  on public.assets (user_id);

-- ---- attachments ----
create index if not exists attachments_user_id_idx
  on public.attachments (user_id);

-- ---- backup_snapshots ----
create index if not exists backup_snapshots_user_id_idx
  on public.backup_snapshots (user_id);

-- ---- categories (self-reference for hierarchy) ----
create index if not exists categories_parent_id_idx
  on public.categories (parent_id);

-- ---- credit_card_profiles ----
create index if not exists credit_card_profiles_account_id_idx
  on public.credit_card_profiles (account_id);
create index if not exists credit_card_profiles_user_id_idx
  on public.credit_card_profiles (user_id);

-- ---- debt_loan_plans ----
create index if not exists debt_loan_plans_user_id_idx
  on public.debt_loan_plans (user_id);

-- ---- device_sessions ----
create index if not exists device_sessions_user_id_idx
  on public.device_sessions (user_id);

-- ---- export_packages ----
create index if not exists export_packages_user_id_idx
  on public.export_packages (user_id);

-- ---- reports ----
create index if not exists reports_user_id_idx
  on public.reports (user_id);

-- ---- saved_calculator_scenarios ----
create index if not exists saved_calculator_scenarios_user_id_idx
  on public.saved_calculator_scenarios (user_id);

-- ---- tax_records ----
create index if not exists tax_records_document_id_idx
  on public.tax_records (document_id);

-- ---- transaction_rules ----
create index if not exists transaction_rules_target_account_id_idx
  on public.transaction_rules (target_account_id);
create index if not exists transaction_rules_target_category_id_idx
  on public.transaction_rules (target_category_id);
create index if not exists transaction_rules_user_id_idx
  on public.transaction_rules (user_id);

-- ---- transaction_splits ----
create index if not exists transaction_splits_category_id_idx
  on public.transaction_splits (category_id);
create index if not exists transaction_splits_transaction_id_idx
  on public.transaction_splits (transaction_id);
create index if not exists transaction_splits_user_id_idx
  on public.transaction_splits (user_id);

-- ---- transactions ----
create index if not exists transactions_account_id_idx
  on public.transactions (account_id);
create index if not exists transactions_category_id_idx
  on public.transactions (category_id);

-- ---- trips ----
create index if not exists trips_user_id_idx
  on public.trips (user_id);
