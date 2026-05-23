alter table public.budgets
  add column if not exists included_category_ids text[] not null default '{}',
  add column if not exists is_app_defined boolean not null default false;

create unique index if not exists budgets_one_app_defined_daily_spending_per_user
  on public.budgets(user_id)
  where is_app_defined = true and name = 'Daily Spending' and status != 'archived';
