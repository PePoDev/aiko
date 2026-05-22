alter table public.profiles enable row level security;
alter table public.accounts enable row level security;
alter table public.categories enable row level security;
alter table public.transactions enable row level security;
alter table public.transaction_splits enable row level security;
alter table public.transaction_rules enable row level security;
alter table public.budgets enable row level security;
alter table public.goals enable row level security;
alter table public.saving_plans enable row level security;
alter table public.dashboard_widget_preferences enable row level security;
alter table public.aiko_insights enable row level security;
alter table public.saved_calculator_scenarios enable row level security;
alter table public.reports enable row level security;
alter table public.attachments enable row level security;
alter table public.notification_preferences enable row level security;

create policy "profiles own rows" on public.profiles
  for all using (id = auth.uid()) with check (id = auth.uid());

create policy "accounts own rows" on public.accounts
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy "categories own rows" on public.categories
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy "transactions own rows" on public.transactions
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy "transaction_splits own rows" on public.transaction_splits
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy "transaction_rules own rows" on public.transaction_rules
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy "budgets own rows" on public.budgets
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy "goals own rows" on public.goals
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy "saving_plans own rows" on public.saving_plans
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy "dashboard_widget_preferences own rows" on public.dashboard_widget_preferences
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy "aiko_insights own rows" on public.aiko_insights
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy "saved_calculator_scenarios own rows" on public.saved_calculator_scenarios
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy "reports own rows" on public.reports
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy "attachments own rows" on public.attachments
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy "notification_preferences own rows" on public.notification_preferences
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());
