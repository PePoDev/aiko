-- Group-level budget: an optional envelope limit for a whole category group,
-- independent of its categories' own limits. Money pair mirrors categories'
-- budget_amount / budget_currency. Idempotent.
alter table public.category_groups add column if not exists budget_amount numeric;
alter table public.category_groups add column if not exists budget_currency text;
