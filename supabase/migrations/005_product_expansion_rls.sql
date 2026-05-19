alter table public.aiko_character_profiles enable row level security;
alter table public.import_jobs enable row level security;
alter table public.export_packages enable row level security;
alter table public.backup_snapshots enable row level security;
alter table public.bill_subscriptions enable row level security;
alter table public.credit_card_profiles enable row level security;
alter table public.debt_loan_plans enable row level security;
alter table public.assets enable row level security;
alter table public.investment_holdings enable row level security;
alter table public.tax_records enable row level security;
alter table public.accounting_records enable row level security;
alter table public.course_lessons enable row level security;
alter table public.device_sessions enable row level security;
alter table public.trips enable row level security;
alter table public.optimization_suggestions enable row level security;
alter table public.subscription_plans enable row level security;

create policy "Users manage own aiko character profiles"
  on public.aiko_character_profiles for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "Users manage own import jobs"
  on public.import_jobs for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "Users manage own export packages"
  on public.export_packages for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "Users manage own backup snapshots"
  on public.backup_snapshots for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "Users manage own bill subscriptions"
  on public.bill_subscriptions for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "Users manage own credit card profiles"
  on public.credit_card_profiles for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "Users manage own debt loan plans"
  on public.debt_loan_plans for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "Users manage own assets"
  on public.assets for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "Users manage own investment holdings"
  on public.investment_holdings for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "Users manage own tax records"
  on public.tax_records for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "Users manage own accounting records"
  on public.accounting_records for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "Users manage own course lessons"
  on public.course_lessons for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "Users manage own device sessions"
  on public.device_sessions for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "Users manage own trips"
  on public.trips for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "Users manage own optimization suggestions"
  on public.optimization_suggestions for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "Users manage own subscription plans"
  on public.subscription_plans for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
