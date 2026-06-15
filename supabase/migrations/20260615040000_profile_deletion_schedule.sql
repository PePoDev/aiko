-- Deferred account deletion: a 3-day grace period.
-- When a user requests deletion, the `delete-account` Edge Function sets
-- `deletion_scheduled_at = now() + 3 days` and emails them. A scheduled job
-- (`purge-deleted-accounts`) hard-deletes accounts once that time passes.
-- Signing back in before then clears this column and cancels the deletion.
alter table public.profiles
  add column if not exists deletion_scheduled_at timestamptz;

-- The purge job filters on `deletion_scheduled_at <= now()`; index only the
-- rows that are actually scheduled (the column is NULL for everyone else).
create index if not exists profiles_deletion_scheduled_at_idx
  on public.profiles (deletion_scheduled_at)
  where deletion_scheduled_at is not null;
