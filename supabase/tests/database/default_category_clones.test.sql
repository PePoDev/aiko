begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(11);

insert into public.profiles (id, email)
values
  ('11111111-1111-4111-8111-111111111111', 'clone-a@example.test'),
  ('22222222-2222-4222-8222-222222222222', 'clone-b@example.test');

select is(
  public.default_category_group_clone_id(
    '11111111-1111-4111-8111-111111111111',
    '00000000-0000-0000-c300-000000000004'
  ),
  '35c0421d-5cf3-506c-a571-673b06e355e4'::uuid,
  'Food & Drink group clone uses the shared UUIDv5 algorithm'
);

select is(
  public.default_category_clone_id(
    '11111111-1111-4111-8111-111111111111',
    '00000000-0000-0000-c200-000000000003'
  ),
  '72a3b441-4610-5bf3-9df7-ffe1c177faef'::uuid,
  'Coffee clone uses the shared UUIDv5 algorithm'
);

select is(
  (select count(*)::integer from public.category_groups
   where user_id = '11111111-1111-4111-8111-111111111111'
     and template_id is not null),
  13,
  'profile has 13 group clones'
);

select is(
  (select count(*)::integer from public.categories
   where user_id = '11111111-1111-4111-8111-111111111111'
     and template_id is not null),
  81,
  'profile has 81 category clones'
);

select is(
  (select count(*)::integer from public.category_groups
   where user_id = '22222222-2222-4222-8222-222222222222'
     and template_id is not null),
  13,
  'second profile has 13 group clones'
);

select is(
  (select count(*)::integer from public.categories
   where user_id = '22222222-2222-4222-8222-222222222222'
     and template_id is not null),
  81,
  'second profile has 81 category clones'
);

select is(
  (select count(*)::integer
   from public.categories a
   join public.categories b using (template_id)
   where a.user_id = '11111111-1111-4111-8111-111111111111'
     and b.user_id = '22222222-2222-4222-8222-222222222222'
     and a.id = b.id),
  0,
  'different users never share a clone id'
);

select is(
  (select count(*)::integer
   from public.categories c
   join public.category_groups g on g.id = c.group_id
   where c.user_id = '11111111-1111-4111-8111-111111111111'
     and c.template_id is not null
     and g.user_id = c.user_id
     and g.template_id is not null),
  81,
  'every category clone points to the same user group clone'
);

update public.categories
set budget_amount = '25', budget_currency = 'THB'
where id = public.default_category_clone_id(
  '11111111-1111-4111-8111-111111111111',
  '00000000-0000-0000-c200-000000000003'
);

select public.ensure_default_category_clones(
  '11111111-1111-4111-8111-111111111111'
);

select is(
  (select budget_amount from public.categories
   where id = public.default_category_clone_id(
     '11111111-1111-4111-8111-111111111111',
     '00000000-0000-0000-c200-000000000003'
   )),
  '25',
  'idempotent clone repair preserves category budgets'
);

select is(
  (select count(*)::integer from public.categories
   where user_id = '11111111-1111-4111-8111-111111111111'
     and template_id is not null),
  81,
  'idempotent clone repair does not duplicate categories'
);

insert into public.categories (
  id, user_id, name, type, "group", icon, color, created_at
) values (
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  '11111111-1111-4111-8111-111111111111',
  'Coffee', 'expense', 'custom', 'coffee', '#000000', now()
);

select is(
  (select count(*)::integer from public.categories
   where user_id = '11111111-1111-4111-8111-111111111111'
     and name = 'Coffee'),
  2,
  'same-named custom category coexists with a Coffee clone'
);

select * from finish();
rollback;
