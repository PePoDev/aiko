-- Drop the Bills & Subscriptions feature table.
--
-- Bills and subscriptions are now modeled as recurring transactions on the
-- `transactions` table, so the dedicated `bill_subscriptions` table and its
-- RLS policy are no longer needed. The Dart side stopped reading and writing
-- this table when the legacy Bills screen was removed.

drop policy if exists "Users manage own bill subscriptions"
  on public.bill_subscriptions;

drop index if exists public.bill_subscriptions_user_due_idx;

drop table if exists public.bill_subscriptions;
