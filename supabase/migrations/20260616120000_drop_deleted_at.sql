-- Soft-delete removed: deletes are now hard deletes that propagate a remote
-- DELETE through Brick, so the `deleted_at` tombstone column is no longer used.
-- Drop it from every syncable table (idempotent). `version` is kept for LWW.
alter table public.profiles             drop column if exists deleted_at;
alter table public.accounts             drop column if exists deleted_at;
alter table public.categories           drop column if exists deleted_at;
alter table public.category_groups      drop column if exists deleted_at;
alter table public.transactions         drop column if exists deleted_at;
alter table public.investment_holdings  drop column if exists deleted_at;
