-- Extend the `transactions` table with per-cadence settings for the
-- recurring-transaction feature. The legacy `is_recurring` boolean is
-- preserved; new optional columns carry the frequency and per-cadence
-- knobs (end date, day-of-week, day-of-month, month-of-year, and an
-- optional occurrence cap). All new columns are nullable so existing rows
-- stay valid.

alter table public.transactions
  add column if not exists recurring_frequency text,
  add column if not exists recurring_end_date date,
  add column if not exists recurring_max_occurrences integer,
  add column if not exists recurring_day_of_week integer
    check (recurring_day_of_week between 1 and 7),
  add column if not exists recurring_day_of_month integer
    check (recurring_day_of_month between 1 and 31),
  add column if not exists recurring_month_of_year integer
    check (recurring_month_of_year between 1 and 12);

-- Sanity-check the frequency vocabulary. Keeping the values aligned with the
-- `RecurringFrequency` enum on the Dart side (once, daily, weekly, monthly,
-- annually).
alter table public.transactions
  drop constraint if exists transactions_recurring_frequency_check;
alter table public.transactions
  add constraint transactions_recurring_frequency_check
  check (
    recurring_frequency is null
    or recurring_frequency in ('once', 'daily', 'weekly', 'monthly', 'annually')
  );
