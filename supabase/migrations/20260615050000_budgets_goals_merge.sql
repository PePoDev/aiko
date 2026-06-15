-- Budgets -> Categories and Goals -> Accounts merge.
-- Per the merge plan: this is a same-release migration (no dual-read window).
-- It rewrites `budgets` rows into `categories` (per-category budget fields)
-- and `goals` rows into `accounts` (with `type = 'goal'`), then drops the
-- old tables. Defensive: every step is wrapped to no-op on empty input so
-- the migration is safe to re-run on already-migrated databases.

-- 1. Extend the categories table with the new budget fields.
alter table categories
  add column if not exists budget_amount text,
  add column if not exists budget_currency text,
  add column if not exists budget_period text not null default 'monthly',
  add column if not exists budget_rollover boolean not null default false,
  add column if not exists alert_thresholds jsonb not null default '[50,75,90,100]'::jsonb;

-- 2. Allow the new 'goal' value on the accounts.type enum/text column.
--    Most schemas use a text column for `type`; if your schema uses a real
--    enum, replace this with: alter type account_type add value if not exists 'goal';
alter table accounts drop constraint if exists accounts_type_check;
alter table accounts
  add constraint accounts_type_check
  check (type in (
    'cash','bank','ewallet','creditCard','loan','investment','asset','liability','goal','other'
  ));

alter table accounts
  add column if not exists goal_target_amount text,
  add column if not exists goal_target_date date,
  add column if not exists goal_priority text not null default 'medium';

alter table accounts
  drop constraint if exists accounts_goal_priority_check;
alter table accounts
  add constraint accounts_goal_priority_check
  check (goal_priority in ('high','medium','low'));

alter table accounts
  drop constraint if exists accounts_goal_shape_check;
alter table accounts
  add constraint accounts_goal_shape_check
  check (
    (type <> 'goal')
    or (
      goal_target_amount is not null
      and goal_target_date is not null
    )
  );

-- 3. Migrate existing budgets -> categories.
--    The new schema stores one budget per category. A category can have
--    multiple legacy budgets (e.g. a user-added 50/30/20 + an app-defined
--    Daily Spending); we collapse them by taking the max amount and union
--    of alert thresholds. Default categories (user_id = NULL) are also
--    covered by the join because the inner select returns rows that joined
--    to a category, default or custom.
update categories c
set
  budget_amount = b.budget_amount,
  budget_currency = b.budget_currency,
  budget_period = b.budget_period,
  budget_rollover = b.budget_rollover,
  alert_thresholds = b.alert_thresholds
from (
  select
    category_id,
    -- `budgets.amount` is numeric; `categories.budget_amount` is text.
    (max(amount) filter (where period <> 'daily'))::text as budget_amount,
    max(currency) as budget_currency,
    coalesce(
      max(period) filter (where period <> 'daily'),
      'monthly'
    ) as budget_period,
    -- legacy `budgets` has no `rollover` column; treat all as non-rollover.
    false as budget_rollover,
    -- legacy `budgets.alert_thresholds` is int[]. Flatten every row's array
    -- into one distinct, sorted jsonb array of ints. `left join lateral`
    -- multiplies rows per threshold but leaves the max()/group aggregates
    -- above unaffected.
    coalesce(
      jsonb_agg(distinct threshold order by threshold)
        filter (where threshold is not null),
      '[50,75,90,100]'::jsonb
    ) as alert_thresholds
  from budgets
  left join lateral unnest(alert_thresholds) as threshold on true
  where category_id is not null
    and coalesce(status, 'active') = 'active'
  group by category_id
) b
where c.id = b.category_id
  and c.budget_amount is null;

-- 4. Migrate existing goals -> accounts.
insert into accounts (
  id, user_id, name, type, currency, current_balance,
  institution, include_in_net_worth, is_active,
  goal_target_amount, goal_target_date, goal_priority
)
select
  g.id,
  g.user_id,
  g.name,
  'goal',
  g.currency,
  -- `current_amount` -> `current_balance` (the goal account's saved amount).
  g.current_amount,
  null,
  true,
  true,
  -- `goals.target_amount` is numeric; `accounts.goal_target_amount` is text.
  g.target_amount::text,
  g.target_date,
  case
    when g.priority = 3 then 'high'
    when g.priority = 1 then 'low'
    else 'medium'
  end
from goals g
where not exists (
  select 1 from accounts a where a.id = g.id
);

-- 5. Drop the legacy tables.
-- saving_plans FK-references goals and is now unused (the saving plan reads
-- from the goal account row); drop it first so goals can go.
drop table if exists saving_plans;
drop table if exists budgets;
drop table if exists goals;
