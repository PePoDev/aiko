-- Layer 2 of Aiko's data access: a fixed catalog of read-only RPCs the chat
-- edge function exposes to the model as tools. These are NOT yet enabled in
-- production (the edge function gates them behind AI_TOOLS_ENABLED, default
-- off) — they ship here so the SQL can be reviewed before turning it on.
--
-- Security:
--   * SECURITY INVOKER — each runs as the calling user, so table RLS applies.
--   * Every body also filters `user_id = auth.uid()` as defense-in-depth.
--   * `set search_path = public` blocks search_path hijacking.
--   * Read-only (plain SELECT), bounded with LIMIT, no model-supplied SQL.
--   * EXECUTE granted only to `authenticated` (revoked from public/anon).

-- Net worth plus the balance/type of each active account.
create or replace function public.aiko_account_summary()
returns jsonb
language sql
stable
security invoker
set search_path = public
as $$
  select jsonb_build_object(
    'net_worth', coalesce(sum(
      case when a.include_in_net_worth then
        (case when a.type in ('loan', 'liability', 'creditCard') then -1 else 1 end) * a.current_balance
      else 0 end), 0),
    'accounts', coalesce(
      jsonb_agg(jsonb_build_object(
        'name', a.name,
        'type', a.type,
        'currency', a.currency,
        'balance', a.current_balance
      ) order by a.current_balance desc),
      '[]'::jsonb)
  )
  from public.accounts a
  where a.user_id = auth.uid()
    and a.is_active;
$$;

-- Per active budget: its limit and amount spent (matching expense transactions
-- in the date range by the budget's category). Approximate for budgets that use
-- multi-category inclusion — refine before enabling if needed.
create or replace function public.aiko_budget_status(start_date date, end_date date)
returns table(name text, budget_limit numeric, spent numeric)
language sql
stable
security invoker
set search_path = public
as $$
  select
    b.name,
    b.amount as budget_limit,
    coalesce((
      select sum(t.amount)
      from public.transactions t
      where t.user_id = auth.uid()
        and t.type = 'expense'
        and t.category_id = b.category_id
        and t.date >= start_date
        and t.date < (end_date + 1)
    ), 0) as spent
  from public.budgets b
  where b.user_id = auth.uid()
    and b.status = 'active'
  order by b.name
  limit 50;
$$;

-- Total expense per category between two dates, highest first.
create or replace function public.aiko_spending_by_category(start_date date, end_date date)
returns table(category text, total numeric)
language sql
stable
security invoker
set search_path = public
as $$
  select
    coalesce(c.name, 'Uncategorized') as category,
    sum(t.amount) as total
  from public.transactions t
  left join public.categories c on c.id = t.category_id
  where t.user_id = auth.uid()
    and t.type = 'expense'
    and t.date >= start_date
    and t.date < (end_date + 1)
  group by coalesce(c.name, 'Uncategorized')
  order by total desc
  limit 50;
$$;

-- Total income vs. expense (and the net) between two dates.
create or replace function public.aiko_cashflow_summary(start_date date, end_date date)
returns table(income numeric, expense numeric, net numeric)
language sql
stable
security invoker
set search_path = public
as $$
  select
    coalesce(sum(t.amount) filter (where t.type = 'income'), 0) as income,
    coalesce(sum(t.amount) filter (where t.type = 'expense'), 0) as expense,
    coalesce(sum(t.amount) filter (where t.type = 'income'), 0)
      - coalesce(sum(t.amount) filter (where t.type = 'expense'), 0) as net
  from public.transactions t
  where t.user_id = auth.uid()
    and t.date >= start_date
    and t.date < (end_date + 1);
$$;

-- The most recent transactions (capped at 50 regardless of the requested size).
create or replace function public.aiko_recent_transactions(max_rows int default 20)
returns table(tx_date date, type text, amount numeric, merchant text, category text)
language sql
stable
security invoker
set search_path = public
as $$
  select
    t.date::date as tx_date,
    t.type,
    t.amount,
    t.merchant,
    coalesce(c.name, 'Uncategorized') as category
  from public.transactions t
  left join public.categories c on c.id = t.category_id
  where t.user_id = auth.uid()
  order by t.date desc
  limit greatest(1, least(coalesce(max_rows, 20), 50));
$$;

-- Active savings goals with progress.
create or replace function public.aiko_goal_progress()
returns table(name text, current_amount numeric, target_amount numeric, pct numeric, target_date date)
language sql
stable
security invoker
set search_path = public
as $$
  select
    g.name,
    g.current_amount,
    g.target_amount,
    case when g.target_amount > 0 then round(g.current_amount / g.target_amount, 4) else 0 end as pct,
    g.target_date
  from public.goals g
  where g.user_id = auth.uid()
    and g.status = 'active'
  order by g.priority asc, g.name
  limit 50;
$$;

revoke execute on function
  public.aiko_account_summary(),
  public.aiko_budget_status(date, date),
  public.aiko_spending_by_category(date, date),
  public.aiko_cashflow_summary(date, date),
  public.aiko_recent_transactions(int),
  public.aiko_goal_progress()
from public, anon;

grant execute on function
  public.aiko_account_summary(),
  public.aiko_budget_status(date, date),
  public.aiko_spending_by_category(date, date),
  public.aiko_cashflow_summary(date, date),
  public.aiko_recent_transactions(int),
  public.aiko_goal_progress()
to authenticated;
