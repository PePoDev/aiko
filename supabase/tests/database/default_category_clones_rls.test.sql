begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(8);

insert into public.profiles (id, email)
values
  ('11111111-1111-4111-8111-111111111111', 'rls-a@example.test'),
  ('22222222-2222-4222-8222-222222222222', 'rls-b@example.test');

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

insert into public.transactions (
  id, user_id, account_id, type, amount, currency, category_id, date
) values
  (
    'bbbbbbbb-0000-4000-8000-000000000001',
    '11111111-1111-4111-8111-111111111111',
    'aaaaaaaa-0000-4000-8000-000000000001',
    'expense', 100, 'THB',
    public.default_category_clone_id(
      '11111111-1111-4111-8111-111111111111',
      '00000000-0000-0000-c200-000000000003'
    ),
    now()
  ),
  (
    'bbbbbbbb-0000-4000-8000-000000000002',
    '22222222-2222-4222-8222-222222222222',
    'aaaaaaaa-0000-4000-8000-000000000002',
    'expense', 100, 'THB',
    public.default_category_clone_id(
      '22222222-2222-4222-8222-222222222222',
      '00000000-0000-0000-c200-000000000003'
    ),
    now()
  );

insert into public.transaction_splits (
  id, user_id, transaction_id, category_id, amount
) values (
  'cccccccc-0000-4000-8000-000000000001',
  '11111111-1111-4111-8111-111111111111',
  'bbbbbbbb-0000-4000-8000-000000000001',
  public.default_category_clone_id(
    '11111111-1111-4111-8111-111111111111',
    '00000000-0000-0000-c200-000000000003'
  ),
  100
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '11111111-1111-4111-8111-111111111111',
  true
);

select is(
  (select count(*)::integer from public.categories where user_id is null),
  81,
  'user can read global category templates'
);

select is(
  (select count(*)::integer from public.categories
   where user_id = '11111111-1111-4111-8111-111111111111'
     and template_id is not null),
  81,
  'user can read own category clones'
);

select is(
  (select count(*)::integer from public.categories
   where user_id = '22222222-2222-4222-8222-222222222222'),
  0,
  'user cannot read another user category clones'
);

select results_eq(
  $$
    update public.categories
    set budget_amount = '999'
    where id = '00000000-0000-0000-c200-000000000003'
    returning id
  $$,
  $$select null::uuid where false$$,
  'user cannot update a global template'
);

select is(
  (select count(*)::integer from pg_proc
   where pronamespace = 'public'::regnamespace
     and proname in (
       'ensure_default_category_clones',
       'rewrite_legacy_category_insert',
       'rewrite_legacy_category_group_insert',
       'rewrite_template_category_reference'
     )
     and prosecdef),
  0,
  'clone and compatibility functions are security invoker'
);

select is(
  (select count(*)::integer from information_schema.routine_privileges
   where routine_schema = 'public'
     and routine_name = 'ensure_default_category_clones'
     and grantee in ('PUBLIC', 'anon')),
  0,
  'clone repair is not executable by PUBLIC or anon'
);

select throws_ok(
  $$
    insert into public.transaction_splits (
      id, user_id, transaction_id, category_id, amount
    ) values (
      'cccccccc-0000-4000-8000-000000000002',
      '11111111-1111-4111-8111-111111111111',
      'bbbbbbbb-0000-4000-8000-000000000002',
      public.default_category_clone_id(
        '11111111-1111-4111-8111-111111111111',
        '00000000-0000-0000-c200-000000000003'
      ),
      100
    )
  $$,
  '23503',
  'Split transaction must have the same owner',
  'split transaction must have the same owner'
);

select throws_ok(
  $$
    update public.transaction_splits
    set transaction_id = 'bbbbbbbb-0000-4000-8000-000000000002'
    where id = 'cccccccc-0000-4000-8000-000000000001'
  $$,
  '23503',
  'Split transaction must have the same owner',
  'split cannot be reassigned to another user transaction'
);

select * from finish();
rollback;
