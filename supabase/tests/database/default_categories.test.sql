begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(6);

select is(
  (
    select count(*)::integer
    from public.categories
    where user_id is null
      and (
        id::text like '00000000-0000-0000-c100-%'
        or id::text like '00000000-0000-0000-c200-%'
      )
  ),
  81,
  'all built-in categories are seeded as global rows'
);

select ok(
  exists(
    select 1
    from public.categories
    where id = '00000000-0000-0000-c200-000000000003'::uuid
      and user_id is null
      and name = 'Coffee'
  ),
  'Coffee category exists for transaction foreign keys'
);

select is(
  (
    select count(*)::integer
    from public.category_groups
    where user_id is null
  ),
  13,
  'all built-in category groups are seeded as global rows'
);

select is(
  (
    select count(*)::integer
    from public.categories
    where user_id is null
      and group_id is not null
  ),
  81,
  'all built-in categories point to a global group'
);

select is(
  (
    select count(*)::integer
    from public.categories
    where user_id is null
      and (budget_amount is not null or budget_currency is not null)
  ),
  0,
  'global category templates are budget-free'
);

select is(
  (
    select count(*)::integer
    from public.category_groups
    where user_id is null
      and (budget_amount is not null or budget_currency is not null)
  ),
  0,
  'global category group templates are budget-free'
);

select * from finish();

rollback;
