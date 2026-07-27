insert into public.profiles (id, email)
values
  ('11111111-1111-4111-8111-111111111111', 'legacy-a@example.test'),
  ('22222222-2222-4222-8222-222222222222', 'legacy-b@example.test');

insert into public.accounts (
  id, user_id, name, type, currency, current_balance
) values
  (
    'aaaaaaaa-0000-4000-8000-000000000001',
    '11111111-1111-4111-8111-111111111111',
    'A Cash', 'cash', 'THB', 0
  ),
  (
    'aaaaaaaa-0000-4000-8000-000000000002',
    '22222222-2222-4222-8222-222222222222',
    'B Cash', 'cash', 'THB', 0
  );

insert into public.category_groups (
  id, user_id, name, icon, color, sort_order,
  budget_amount, budget_currency
) values (
  '00000000-0000-0000-c300-000000000004',
  '11111111-1111-4111-8111-111111111111',
  'Food & Drink', 'restaurant', '#F59E0B', 1048580,
  5000, 'THB'
);

insert into public.categories (
  id, user_id, name, type, "group", group_id, icon, color,
  budget_enabled, is_default, budget_amount, budget_currency,
  budget_period, budget_rollover, alert_thresholds
) values (
  '00000000-0000-0000-c200-000000000003',
  '11111111-1111-4111-8111-111111111111',
  'Coffee', 'expense', 'wants',
  '00000000-0000-0000-c300-000000000004',
  'coffee', '#8B5A2B', true, true,
  '3000', 'THB', 'weekly', true, '[75,100]'::jsonb
);

insert into public.categories (
  id, user_id, name, type, "group", group_id, icon, color
) values (
  'dddddddd-0000-4000-8000-000000000001',
  '11111111-1111-4111-8111-111111111111',
  'Cafe Work', 'expense', 'custom',
  '00000000-0000-0000-c300-000000000004',
  'work', '#000000'
);

insert into public.transactions (
  id, user_id, account_id, type, amount, currency, category_id, date
) values
  (
    'bbbbbbbb-0000-4000-8000-000000000001',
    '11111111-1111-4111-8111-111111111111',
    'aaaaaaaa-0000-4000-8000-000000000001',
    'expense', 100, 'THB',
    '00000000-0000-0000-c200-000000000003', now()
  ),
  (
    'bbbbbbbb-0000-4000-8000-000000000002',
    '22222222-2222-4222-8222-222222222222',
    'aaaaaaaa-0000-4000-8000-000000000002',
    'expense', 200, 'THB',
    '00000000-0000-0000-c200-000000000003', now()
  );

insert into public.transaction_splits (
  id, user_id, transaction_id, category_id, amount
) values (
  'cccccccc-0000-4000-8000-000000000001',
  '11111111-1111-4111-8111-111111111111',
  'bbbbbbbb-0000-4000-8000-000000000001',
  '00000000-0000-0000-c200-000000000003', 100
);
