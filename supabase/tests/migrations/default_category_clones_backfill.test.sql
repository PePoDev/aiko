begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(7);

select is(
  (select user_id from public.categories
   where id = '00000000-0000-0000-c200-000000000003'),
  null::uuid,
  'legacy fixed Coffee row becomes a global template'
);

select is(
  (select budget_amount from public.categories
   where id = public.default_category_clone_id(
     '11111111-1111-4111-8111-111111111111',
     '00000000-0000-0000-c200-000000000003'
   )),
  '3000',
  'legacy Coffee budget moves to the original owner clone'
);

select is(
  (select budget_amount::text from public.category_groups
   where id = public.default_category_group_clone_id(
     '11111111-1111-4111-8111-111111111111',
     '00000000-0000-0000-c300-000000000004'
   )),
  '5000',
  'legacy Food & Drink budget moves to the original owner clone'
);

select is(
  (select category_id from public.transactions
   where id = 'bbbbbbbb-0000-4000-8000-000000000001'),
  public.default_category_clone_id(
    '11111111-1111-4111-8111-111111111111',
    '00000000-0000-0000-c200-000000000003'
  ),
  'first user transaction points to its Coffee clone'
);

select is(
  (select category_id from public.transactions
   where id = 'bbbbbbbb-0000-4000-8000-000000000002'),
  public.default_category_clone_id(
    '22222222-2222-4222-8222-222222222222',
    '00000000-0000-0000-c200-000000000003'
  ),
  'second user transaction points to its Coffee clone'
);

select is(
  (select category_id from public.transaction_splits
   where id = 'cccccccc-0000-4000-8000-000000000001'),
  public.default_category_clone_id(
    '11111111-1111-4111-8111-111111111111',
    '00000000-0000-0000-c200-000000000003'
  ),
  'legacy split points to the original owner Coffee clone'
);

select is(
  (select group_id from public.categories
   where id = 'dddddddd-0000-4000-8000-000000000001'),
  public.default_category_group_clone_id(
    '11111111-1111-4111-8111-111111111111',
    '00000000-0000-0000-c300-000000000004'
  ),
  'custom category fixed group reference moves to its owner clone'
);

select * from finish();
rollback;
