insert into public.profiles (
  id,
  display_name,
  email,
  base_currency,
  country,
  ai_consent_enabled,
  onboarding_status,
  security_status
) values (
  '00000000-0000-0000-0000-000000000001',
  'Aiko Demo',
  'demo@example.com',
  'USD',
  'US',
  true,
  'completed',
  'pinEnabled'
) on conflict (id) do nothing;

insert into public.accounts (
  id,
  user_id,
  name,
  type,
  currency,
  opening_balance,
  current_balance
) values (
  '10000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000001',
  'Cash Wallet',
  'cash',
  'USD',
  1000,
  3420
) on conflict (id) do nothing;

insert into public.categories (
  id,
  user_id,
  name,
  type,
  "group"
) values (
  '20000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000001',
  'Food and Dining',
  'expense',
  'needs'
) on conflict (id) do nothing;
