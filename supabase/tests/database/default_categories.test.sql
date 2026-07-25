begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(2);

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

select * from finish();

rollback;
