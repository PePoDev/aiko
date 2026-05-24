alter table public.transactions
  alter column date type timestamptz
  using date::timestamptz;
