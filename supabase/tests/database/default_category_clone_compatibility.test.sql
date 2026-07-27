begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(9);

insert into public.profiles (id, email)
values ('11111111-1111-4111-8111-111111111111', 'compat@example.test');

insert into public.accounts (
  id, user_id, name, type, currency, current_balance
) values (
  'aaaaaaaa-0000-4000-8000-000000000001',
  '11111111-1111-4111-8111-111111111111',
  'Cash', 'cash', 'THB', 0
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '11111111-1111-4111-8111-111111111111',
  true
);

insert into public.categories (
  id, user_id, name, type, "group", group_id, parent_id, icon, color,
  budget_enabled, is_active, created_at, budget_amount, budget_currency,
  budget_period, budget_rollover, alert_thresholds, updated_at, version
) values (
  '00000000-0000-0000-c200-000000000003',
  '11111111-1111-4111-8111-111111111111',
  'Coffee', 'expense', 'wants',
  '00000000-0000-0000-c300-000000000004',
  null, 'coffee', '#8B5A2B', true, true, null,
  '3000', 'THB', 'monthly', false, '[50,75,90,100]'::jsonb,
  '2026-07-25T17:58:36.262483Z', 1
) on conflict (id) do update set
  budget_amount = excluded.budget_amount,
  budget_currency = excluded.budget_currency,
  updated_at = excluded.updated_at;

select is(
  (select budget_amount from public.categories
   where id = public.default_category_clone_id(
     '11111111-1111-4111-8111-111111111111',
     '00000000-0000-0000-c200-000000000003'
   )),
  '3000',
  'legacy category upsert writes the user Coffee clone budget'
);

select ok(
  (select created_at is not null from public.categories
   where id = public.default_category_clone_id(
     '11111111-1111-4111-8111-111111111111',
     '00000000-0000-0000-c200-000000000003'
   )),
  'legacy category upsert fills created_at'
);

select is(
  (select template_id from public.categories
   where id = public.default_category_clone_id(
     '11111111-1111-4111-8111-111111111111',
     '00000000-0000-0000-c200-000000000003'
   )),
  '00000000-0000-0000-c200-000000000003'::uuid,
  'legacy category upsert records the Coffee template id'
);

select is(
  (select group_id from public.categories
   where id = public.default_category_clone_id(
     '11111111-1111-4111-8111-111111111111',
     '00000000-0000-0000-c200-000000000003'
   )),
  public.default_category_group_clone_id(
    '11111111-1111-4111-8111-111111111111',
    '00000000-0000-0000-c300-000000000004'
  ),
  'legacy category upsert maps Food & Drink to the user clone'
);

select is(
  (select count(*)::integer from public.categories
   where id = '00000000-0000-0000-c200-000000000003'
     and user_id is null
     and budget_amount is null),
  1,
  'legacy category upsert leaves global Coffee unchanged'
);

insert into public.transactions (
  id, user_id, account_id, type, amount, currency, category_id, date
) values (
  'bbbbbbbb-0000-4000-8000-000000000001',
  '11111111-1111-4111-8111-111111111111',
  'aaaaaaaa-0000-4000-8000-000000000001',
  'expense', 100, 'THB',
  '00000000-0000-0000-c200-000000000003', now()
);

select is(
  (select category_id from public.transactions
   where id = 'bbbbbbbb-0000-4000-8000-000000000001'),
  public.default_category_clone_id(
    '11111111-1111-4111-8111-111111111111',
    '00000000-0000-0000-c200-000000000003'
  ),
  'legacy transaction reference maps to the user Coffee clone'
);

insert into public.transaction_splits (
  id, user_id, transaction_id, category_id, amount
) values (
  'cccccccc-0000-4000-8000-000000000001',
  '11111111-1111-4111-8111-111111111111',
  'bbbbbbbb-0000-4000-8000-000000000001',
  '00000000-0000-0000-c200-000000000003', 100
);

select is(
  (select category_id from public.transaction_splits
   where id = 'cccccccc-0000-4000-8000-000000000001'),
  public.default_category_clone_id(
    '11111111-1111-4111-8111-111111111111',
    '00000000-0000-0000-c200-000000000003'
  ),
  'legacy split reference maps to the user Coffee clone'
);

select is(
  (select count(*)::integer from public.categories
   where user_id = '11111111-1111-4111-8111-111111111111'
     and template_id = '00000000-0000-0000-c200-000000000003'),
  1,
  'legacy replay leaves exactly one Coffee clone'
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

select is(
  (select group_id from public.categories
   where id = 'dddddddd-0000-4000-8000-000000000001'),
  public.default_category_group_clone_id(
    '11111111-1111-4111-8111-111111111111',
    '00000000-0000-0000-c300-000000000004'
  ),
  'legacy custom category maps its fixed group to the user clone'
);

select * from finish();
rollback;
