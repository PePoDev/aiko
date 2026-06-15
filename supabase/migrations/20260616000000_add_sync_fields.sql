-- Brick models send `deleted_at` + `version` on every row and select them back.
-- These columns were never created, so PostgREST rejected every sync with HTTP 400.
-- Add them to all syncable tables (idempotent).
alter table public.profiles             add column if not exists deleted_at timestamptz;
alter table public.profiles             add column if not exists version integer not null default 1;
alter table public.accounts             add column if not exists deleted_at timestamptz;
alter table public.accounts             add column if not exists version integer not null default 1;
alter table public.categories           add column if not exists deleted_at timestamptz;
alter table public.categories           add column if not exists version integer not null default 1;
alter table public.category_groups      add column if not exists deleted_at timestamptz;
alter table public.category_groups      add column if not exists version integer not null default 1;
alter table public.transactions         add column if not exists deleted_at timestamptz;
alter table public.transactions         add column if not exists version integer not null default 1;
alter table public.investment_holdings  add column if not exists deleted_at timestamptz;
alter table public.investment_holdings  add column if not exists version integer not null default 1;
