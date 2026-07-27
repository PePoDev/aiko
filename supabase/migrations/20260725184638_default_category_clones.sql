create extension if not exists "uuid-ossp" with schema extensions;

create or replace function public.default_category_group_clone_id(
  p_user_id uuid,
  p_template_id uuid
) returns uuid
language sql
immutable
strict
parallel safe
set search_path = ''
as $$
  select extensions.uuid_generate_v5(
    'ee336da0-4337-4fa0-b100-ec0dddcb5b95'::uuid,
    'group:' || p_user_id::text || ':' || p_template_id::text
  );
$$;

create or replace function public.default_category_clone_id(
  p_user_id uuid,
  p_template_id uuid
) returns uuid
language sql
immutable
strict
parallel safe
set search_path = ''
as $$
  select extensions.uuid_generate_v5(
    'ee336da0-4337-4fa0-b100-ec0dddcb5b95'::uuid,
    'category:' || p_user_id::text || ':' || p_template_id::text
  );
$$;

alter table public.category_groups add column template_id uuid;
alter table public.categories add column template_id uuid;

drop index if exists public.categories_user_parent_name_idx;
create unique index categories_user_parent_name_custom_uidx
  on public.categories (
    user_id,
    coalesce(parent_id, '00000000-0000-0000-0000-000000000000'::uuid),
    lower(name)
  )
  where user_id is not null and template_id is null;

create temporary table migration_default_group_templates (
  id uuid primary key,
  name text not null,
  icon text not null,
  color text not null,
  sort_order integer not null
) on commit drop;

insert into migration_default_group_templates values
  ('00000000-0000-0000-c300-000000000002', 'Income & Earnings', 'salary', '#16A34A', 1048577),
  ('00000000-0000-0000-c300-000000000003', 'Investments & Savings', 'investing', '#8B5CF6', 1048578),
  ('00000000-0000-0000-c300-000000000004', 'Food & Drink', 'food', '#F97316', 1048579),
  ('00000000-0000-0000-c300-000000000005', 'Transport', 'transport', '#3B82F6', 1048580),
  ('00000000-0000-0000-c300-000000000006', 'Housing & Utilities', 'home', '#7C3AED', 1048581),
  ('00000000-0000-0000-c300-000000000007', 'Health & Fitness', 'health', '#10B981', 1048582),
  ('00000000-0000-0000-c300-000000000008', 'Shopping & Personal', 'shopping', '#EC4899', 1048583),
  ('00000000-0000-0000-c300-000000000009', 'Entertainment & Leisure', 'entertainment', '#F43F5E', 1048584),
  ('00000000-0000-0000-c300-00000000000a', 'Education', 'education', '#F59E0B', 1048585),
  ('00000000-0000-0000-c300-00000000000b', 'Travel', 'travel', '#38BDF8', 1048586),
  ('00000000-0000-0000-c300-00000000000c', 'Family & Giving', 'gift', '#6366F1', 1048587),
  ('00000000-0000-0000-c300-00000000000d', 'Bills & Financial', 'fee', '#DC2626', 1048588),
  ('00000000-0000-0000-c300-000000000001', 'Other', 'category', '#64748B', 1048675);

create temporary table migration_default_category_templates (
  id uuid primary key,
  name text not null,
  type text not null,
  budget_group text not null,
  group_id uuid not null,
  icon text not null,
  color text not null,
  budget_enabled boolean not null
) on commit drop;

insert into migration_default_category_templates values
  ('00000000-0000-0000-c100-000000000001', 'Salary', 'income', 'custom', '00000000-0000-0000-c300-000000000002', 'salary', '#22C55E', false),
  ('00000000-0000-0000-c100-000000000002', 'Bonus', 'income', 'custom', '00000000-0000-0000-c300-000000000002', 'gift', '#16A34A', false),
  ('00000000-0000-0000-c100-000000000003', 'Freelance', 'income', 'business', '00000000-0000-0000-c300-000000000002', 'work', '#14B8A6', false),
  ('00000000-0000-0000-c100-000000000004', 'Business', 'income', 'business', '00000000-0000-0000-c300-000000000002', 'business', '#0EA5E9', false),
  ('00000000-0000-0000-c100-000000000008', 'Refunds', 'income', 'custom', '00000000-0000-0000-c300-000000000002', 'refund', '#10B981', false),
  ('00000000-0000-0000-c100-000000000009', 'Gift Received', 'income', 'custom', '00000000-0000-0000-c300-000000000002', 'gift', '#EC4899', false),
  ('00000000-0000-0000-c100-00000000000a', 'Other Income', 'income', 'custom', '00000000-0000-0000-c300-000000000002', 'category', '#64748B', false),
  ('00000000-0000-0000-c100-000000000005', 'Interest', 'income', 'savings', '00000000-0000-0000-c300-000000000003', 'savings', '#06B6D4', false),
  ('00000000-0000-0000-c100-000000000006', 'Dividends', 'income', 'investment', '00000000-0000-0000-c300-000000000003', 'investment', '#8B5CF6', false),
  ('00000000-0000-0000-c100-000000000007', 'Rental Income', 'income', 'investment', '00000000-0000-0000-c300-000000000003', 'home', '#6366F1', false),
  ('00000000-0000-0000-c100-00000000000b', 'Capital Gains', 'income', 'investment', '00000000-0000-0000-c300-000000000003', 'investing', '#7C3AED', false),
  ('00000000-0000-0000-c200-000000000001', 'Groceries', 'expense', 'needs', '00000000-0000-0000-c300-000000000004', 'groceries', '#F97316', true),
  ('00000000-0000-0000-c200-000000000002', 'Dining Out', 'expense', 'wants', '00000000-0000-0000-c300-000000000004', 'dining', '#EF4444', true),
  ('00000000-0000-0000-c200-000000000003', 'Coffee', 'expense', 'wants', '00000000-0000-0000-c300-000000000004', 'coffee', '#8B5A2B', true),
  ('00000000-0000-0000-c200-000000000014', 'Lunch', 'expense', 'wants', '00000000-0000-0000-c300-000000000004', 'lunch', '#FB923C', true),
  ('00000000-0000-0000-c200-000000000015', 'Dinner', 'expense', 'wants', '00000000-0000-0000-c300-000000000004', 'dinner', '#DC2626', true),
  ('00000000-0000-0000-c200-000000000016', 'Dessert', 'expense', 'wants', '00000000-0000-0000-c300-000000000004', 'dessert', '#F472B6', true),
  ('00000000-0000-0000-c200-000000000017', 'Bubble Tea', 'expense', 'wants', '00000000-0000-0000-c300-000000000004', 'bubble_tea', '#A78BFA', true),
  ('00000000-0000-0000-c200-000000000018', 'Drinks / Bar', 'expense', 'wants', '00000000-0000-0000-c300-000000000004', 'drink', '#C084FC', true),
  ('00000000-0000-0000-c200-000000000019', 'Snacks', 'expense', 'wants', '00000000-0000-0000-c300-000000000004', 'snack', '#FBBF24', true),
  ('00000000-0000-0000-c200-000000000037', 'Food Delivery', 'expense', 'wants', '00000000-0000-0000-c300-000000000004', 'food_delivery', '#F97316', true),
  ('00000000-0000-0000-c200-000000000004', 'Transport', 'expense', 'needs', '00000000-0000-0000-c300-000000000005', 'transport', '#3B82F6', true),
  ('00000000-0000-0000-c200-000000000038', 'Public Transport', 'expense', 'needs', '00000000-0000-0000-c300-000000000005', 'public_transport', '#1E40AF', true),
  ('00000000-0000-0000-c200-000000000005', 'Fuel', 'expense', 'needs', '00000000-0000-0000-c300-000000000005', 'fuel', '#2563EB', true),
  ('00000000-0000-0000-c200-00000000001a', 'Taxi / Rideshare', 'expense', 'needs', '00000000-0000-0000-c300-000000000005', 'taxi', '#1D4ED8', true),
  ('00000000-0000-0000-c200-00000000001b', 'Parking', 'expense', 'needs', '00000000-0000-0000-c300-000000000005', 'parking', '#0369A1', true),
  ('00000000-0000-0000-c200-00000000001c', 'Vehicle Maintenance', 'expense', 'needs', '00000000-0000-0000-c300-000000000005', 'maintenance', '#0891B2', true),
  ('00000000-0000-0000-c200-00000000001d', 'Tolls', 'expense', 'needs', '00000000-0000-0000-c300-000000000005', 'tolls', '#0284C7', true),
  ('00000000-0000-0000-c200-000000000006', 'Rent / Mortgage', 'expense', 'needs', '00000000-0000-0000-c300-000000000006', 'home', '#7C3AED', true),
  ('00000000-0000-0000-c200-000000000007', 'Utilities', 'expense', 'needs', '00000000-0000-0000-c300-000000000006', 'utilities', '#0EA5E9', true),
  ('00000000-0000-0000-c200-000000000008', 'Phone', 'expense', 'needs', '00000000-0000-0000-c300-000000000006', 'phone', '#06B6D4', true),
  ('00000000-0000-0000-c200-000000000009', 'Internet', 'expense', 'needs', '00000000-0000-0000-c300-000000000006', 'internet', '#0284C7', true),
  ('00000000-0000-0000-c200-00000000001e', 'Home Maintenance', 'expense', 'needs', '00000000-0000-0000-c300-000000000006', 'maintenance', '#A855F7', true),
  ('00000000-0000-0000-c200-00000000001f', 'Furniture & Appliances', 'expense', 'wants', '00000000-0000-0000-c300-000000000006', 'furniture', '#9333EA', true),
  ('00000000-0000-0000-c200-00000000000c', 'Health', 'expense', 'needs', '00000000-0000-0000-c300-000000000007', 'health', '#10B981', true),
  ('00000000-0000-0000-c200-00000000000d', 'Insurance', 'expense', 'needs', '00000000-0000-0000-c300-000000000007', 'insurance', '#14B8A6', true),
  ('00000000-0000-0000-c200-000000000020', 'Pharmacy / Medicine', 'expense', 'needs', '00000000-0000-0000-c300-000000000007', 'pharmacy', '#059669', true),
  ('00000000-0000-0000-c200-000000000021', 'Dental', 'expense', 'needs', '00000000-0000-0000-c300-000000000007', 'dental', '#0D9488', true),
  ('00000000-0000-0000-c200-000000000022', 'Fitness / Gym', 'expense', 'wants', '00000000-0000-0000-c300-000000000007', 'gym', '#22C55E', true),
  ('00000000-0000-0000-c200-000000000040', 'Doctor Visit', 'expense', 'needs', '00000000-0000-0000-c300-000000000007', 'doctor', '#047857', true),
  ('00000000-0000-0000-c200-000000000041', 'Medicine & Treatment', 'expense', 'needs', '00000000-0000-0000-c300-000000000007', 'medicine_treatment', '#065F46', true),
  ('00000000-0000-0000-c200-000000000042', 'Life Insurance', 'expense', 'needs', '00000000-0000-0000-c300-000000000007', 'life_insurance', '#0F766E', true),
  ('00000000-0000-0000-c200-000000000043', 'Gym & Boxing', 'expense', 'wants', '00000000-0000-0000-c300-000000000007', 'boxing', '#16A34A', true),
  ('00000000-0000-0000-c200-000000000044', 'Fitness Class', 'expense', 'wants', '00000000-0000-0000-c300-000000000007', 'fitness_class', '#15803D', true),
  ('00000000-0000-0000-c200-000000000045', 'Fitness Equipment', 'expense', 'wants', '00000000-0000-0000-c300-000000000007', 'fitness_equipment', '#166534', true),
  ('00000000-0000-0000-c200-000000000046', 'Supplements', 'expense', 'wants', '00000000-0000-0000-c300-000000000007', 'supplements', '#84CC16', true),
  ('00000000-0000-0000-c200-00000000000b', 'Shopping', 'expense', 'wants', '00000000-0000-0000-c300-000000000008', 'shopping', '#EC4899', true),
  ('00000000-0000-0000-c200-000000000023', 'Clothing', 'expense', 'wants', '00000000-0000-0000-c300-000000000008', 'clothing', '#DB2777', true),
  ('00000000-0000-0000-c200-000000000024', 'Electronics', 'expense', 'wants', '00000000-0000-0000-c300-000000000008', 'electronics', '#BE185D', true),
  ('00000000-0000-0000-c200-000000000025', 'Personal Care', 'expense', 'wants', '00000000-0000-0000-c300-000000000008', 'personal_care', '#F472B6', true),
  ('00000000-0000-0000-c200-00000000003d', 'Jewelry & Accessories', 'expense', 'wants', '00000000-0000-0000-c300-000000000008', 'jewelry', '#C084FC', true),
  ('00000000-0000-0000-c200-00000000003e', 'Shoes & Sneakers', 'expense', 'wants', '00000000-0000-0000-c300-000000000008', 'shoes', '#9333EA', true),
  ('00000000-0000-0000-c200-000000000010', 'Entertainment', 'expense', 'wants', '00000000-0000-0000-c300-000000000009', 'entertainment', '#F43F5E', true),
  ('00000000-0000-0000-c200-00000000000a', 'Subscriptions', 'expense', 'wants', '00000000-0000-0000-c300-000000000009', 'subscriptions', '#A855F7', true),
  ('00000000-0000-0000-c200-000000000026', 'Movies', 'expense', 'wants', '00000000-0000-0000-c300-000000000009', 'movie', '#BE123C', true),
  ('00000000-0000-0000-c200-000000000027', 'Games', 'expense', 'wants', '00000000-0000-0000-c300-000000000009', 'game', '#9F1239', true),
  ('00000000-0000-0000-c200-000000000028', 'Music / Streaming', 'expense', 'wants', '00000000-0000-0000-c300-000000000009', 'music', '#E11D48', true),
  ('00000000-0000-0000-c200-000000000029', 'Concerts / Events', 'expense', 'wants', '00000000-0000-0000-c300-000000000009', 'concert', '#FB7185', true),
  ('00000000-0000-0000-c200-00000000002a', 'Hobbies', 'expense', 'wants', '00000000-0000-0000-c300-000000000009', 'hobby', '#F59E0B', true),
  ('00000000-0000-0000-c200-00000000000e', 'Education', 'expense', 'needs', '00000000-0000-0000-c300-00000000000a', 'education', '#F59E0B', true),
  ('00000000-0000-0000-c200-00000000002b', 'Books', 'expense', 'needs', '00000000-0000-0000-c300-00000000000a', 'book', '#D97706', true),
  ('00000000-0000-0000-c200-00000000002c', 'Courses', 'expense', 'needs', '00000000-0000-0000-c300-00000000000a', 'courses', '#B45309', true),
  ('00000000-0000-0000-c200-00000000003f', 'Workshops', 'expense', 'needs', '00000000-0000-0000-c300-00000000000a', 'workshop', '#92400E', true),
  ('00000000-0000-0000-c200-00000000000f', 'Travel', 'expense', 'wants', '00000000-0000-0000-c300-00000000000b', 'travel', '#38BDF8', true),
  ('00000000-0000-0000-c200-00000000002d', 'Flights', 'expense', 'wants', '00000000-0000-0000-c300-00000000000b', 'flights', '#0EA5E9', true),
  ('00000000-0000-0000-c200-00000000002e', 'Accommodation', 'expense', 'wants', '00000000-0000-0000-c300-00000000000b', 'hotel', '#0284C7', true),
  ('00000000-0000-0000-c200-00000000002f', 'Foreign Fees', 'expense', 'wants', '00000000-0000-0000-c300-00000000000b', 'foreign_fees', '#0EA5E9', true),
  ('00000000-0000-0000-c200-000000000030', 'Gifts', 'expense', 'wants', '00000000-0000-0000-c300-00000000000c', 'gifts', '#6366F1', true),
  ('00000000-0000-0000-c200-000000000031', 'Childcare', 'expense', 'needs', '00000000-0000-0000-c300-00000000000c', 'childcare', '#8B5CF6', true),
  ('00000000-0000-0000-c200-000000000032', 'Pets', 'expense', 'needs', '00000000-0000-0000-c300-00000000000c', 'pets', '#A855F7', true),
  ('00000000-0000-0000-c200-000000000033', 'Donations / Charity', 'expense', 'custom', '00000000-0000-0000-c300-00000000000c', 'donation', '#4F46E5', true),
  ('00000000-0000-0000-c200-000000000011', 'Fees', 'expense', 'custom', '00000000-0000-0000-c300-00000000000d', 'fee', '#64748B', true),
  ('00000000-0000-0000-c200-000000000012', 'Taxes', 'expense', 'tax', '00000000-0000-0000-c300-00000000000d', 'tax', '#DC2626', true),
  ('00000000-0000-0000-c200-000000000034', 'Loan Payment', 'expense', 'debt', '00000000-0000-0000-c300-00000000000d', 'loan', '#B91C1C', true),
  ('00000000-0000-0000-c200-000000000035', 'Credit Card Payment', 'expense', 'debt', '00000000-0000-0000-c300-00000000000d', 'credit_card', '#991B1B', true),
  ('00000000-0000-0000-c200-000000000036', 'Savings Contribution', 'expense', 'savings', '00000000-0000-0000-c300-00000000000d', 'savings', '#16A34A', true),
  ('00000000-0000-0000-c200-000000000039', 'Water', 'expense', 'needs', '00000000-0000-0000-c300-00000000000d', 'water', '#0EA5E9', true),
  ('00000000-0000-0000-c200-00000000003a', 'Electricity', 'expense', 'needs', '00000000-0000-0000-c300-00000000000d', 'electricity', '#FACC15', true),
  ('00000000-0000-0000-c200-00000000003b', 'Home Loan Interest', 'expense', 'debt', '00000000-0000-0000-c300-00000000000d', 'loan_interest', '#7C2D12', true),
  ('00000000-0000-0000-c200-00000000003c', 'Social Security', 'expense', 'custom', '00000000-0000-0000-c300-00000000000d', 'social_security', '#1E40AF', true),
  ('00000000-0000-0000-c200-000000000013', 'Other', 'expense', 'custom', '00000000-0000-0000-c300-000000000001', 'category', '#64748B', true);

do $$
begin
  if (select count(*) from migration_default_group_templates) <> 13 then
    raise exception 'expected 13 default category groups';
  end if;
  if (select count(*) from migration_default_category_templates) <> 81 then
    raise exception 'expected 81 default categories';
  end if;
end;
$$;

create temporary table migration_legacy_group_overlays on commit drop as
select cg.*
from public.category_groups cg
join migration_default_group_templates template on template.id = cg.id
where cg.user_id is not null;

create temporary table migration_legacy_category_overlays on commit drop as
select c.*
from public.categories c
join migration_default_category_templates template on template.id = c.id
where c.user_id is not null;

insert into public.category_groups (
  id, user_id, template_id, name, icon, color, sort_order,
  created_at, updated_at, version, budget_amount, budget_currency
)
select
  id, null, null, name, icon, color, sort_order,
  now(), now(), 1, null, null
from migration_default_group_templates
on conflict (id) do update set
  user_id = null,
  template_id = null,
  name = excluded.name,
  icon = excluded.icon,
  color = excluded.color,
  sort_order = excluded.sort_order,
  budget_amount = null,
  budget_currency = null,
  updated_at = now();

insert into public.categories (
  id, user_id, template_id, name, parent_id, type, "group", group_id,
  icon, color, budget_enabled, is_default, is_active, created_at,
  updated_at, budget_amount, budget_currency, budget_period,
  budget_rollover, alert_thresholds, version
)
select
  id, null, null, name, null, type, budget_group, group_id,
  icon, color, budget_enabled, true, true, now(), now(),
  null, null, 'monthly', false, '[50,75,90,100]'::jsonb, 1
from migration_default_category_templates
on conflict (id) do update set
  user_id = null,
  template_id = null,
  name = excluded.name,
  parent_id = null,
  type = excluded.type,
  "group" = excluded."group",
  group_id = excluded.group_id,
  icon = excluded.icon,
  color = excluded.color,
  budget_enabled = excluded.budget_enabled,
  is_default = true,
  is_active = true,
  budget_amount = null,
  budget_currency = null,
  budget_period = 'monthly',
  budget_rollover = false,
  alert_thresholds = '[50,75,90,100]'::jsonb,
  updated_at = now();

create or replace function public.ensure_default_category_clones(
  p_user_id uuid default auth.uid()
) returns void
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
begin
  if p_user_id is null then
    raise exception 'A user id is required' using errcode = '22004';
  end if;
  if auth.uid() is not null and p_user_id <> auth.uid() then
    raise exception 'Cannot create category clones for another user'
      using errcode = '42501';
  end if;

  insert into public.category_groups (
    id, user_id, template_id, name, icon, color, sort_order,
    created_at, updated_at, version, budget_amount, budget_currency
  )
  select
    public.default_category_group_clone_id(p_user_id, template.id),
    p_user_id,
    template.id,
    template.name,
    template.icon,
    template.color,
    template.sort_order,
    now(), now(), 1, null, null
  from public.category_groups template
  where template.user_id is null
    and template.template_id is null
    and template.id::text like '00000000-0000-0000-c300-%'
  on conflict (id) do update set
    template_id = excluded.template_id,
    name = excluded.name,
    icon = excluded.icon,
    color = excluded.color,
    sort_order = excluded.sort_order;

  insert into public.categories (
    id, user_id, template_id, name, parent_id, type, "group", group_id,
    icon, color, budget_enabled, is_default, is_active, created_at,
    updated_at, budget_amount, budget_currency, budget_period,
    budget_rollover, alert_thresholds, version
  )
  select
    public.default_category_clone_id(p_user_id, template.id),
    p_user_id,
    template.id,
    template.name,
    case
      when template.parent_id is null then null
      else public.default_category_clone_id(p_user_id, template.parent_id)
    end,
    template.type,
    template."group",
    public.default_category_group_clone_id(p_user_id, template.group_id),
    template.icon,
    template.color,
    template.budget_enabled,
    true,
    true,
    now(), now(), null, null, 'monthly', false,
    '[50,75,90,100]'::jsonb, 1
  from public.categories template
  where template.user_id is null
    and template.template_id is null
    and template.is_default
  on conflict (id) do update set
    template_id = excluded.template_id,
    name = excluded.name,
    parent_id = excluded.parent_id,
    type = excluded.type,
    "group" = excluded."group",
    group_id = excluded.group_id,
    icon = excluded.icon,
    color = excluded.color,
    is_default = true;
end;
$$;

do $$
declare
  profile record;
begin
  for profile in select id from public.profiles loop
    perform public.ensure_default_category_clones(profile.id);
  end loop;
end;
$$;

update public.category_groups clone
set
  budget_amount = legacy.budget_amount,
  budget_currency = legacy.budget_currency,
  updated_at = legacy.updated_at,
  version = legacy.version
from migration_legacy_group_overlays legacy
where clone.id = public.default_category_group_clone_id(
  legacy.user_id,
  legacy.id
);

update public.categories clone
set
  budget_enabled = legacy.budget_enabled,
  budget_amount = legacy.budget_amount,
  budget_currency = legacy.budget_currency,
  budget_period = legacy.budget_period,
  budget_rollover = legacy.budget_rollover,
  alert_thresholds = legacy.alert_thresholds,
  updated_at = legacy.updated_at,
  version = legacy.version
from migration_legacy_category_overlays legacy
where clone.id = public.default_category_clone_id(
  legacy.user_id,
  legacy.id
);

update public.categories category
set group_id = public.default_category_group_clone_id(
  category.user_id,
  category.group_id
)
where category.user_id is not null
  and exists (
    select 1
    from public.category_groups template
    where template.id = category.group_id
      and template.user_id is null
      and template.template_id is null
  );

update public.categories category
set parent_id = public.default_category_clone_id(
  category.user_id,
  category.parent_id
)
where category.user_id is not null
  and exists (
    select 1
    from public.categories template
    where template.id = category.parent_id
      and template.user_id is null
      and template.template_id is null
      and template.is_default
  );

update public.transactions transaction
set category_id = public.default_category_clone_id(
  transaction.user_id,
  transaction.category_id
)
where exists (
  select 1
  from public.categories template
  where template.id = transaction.category_id
    and template.user_id is null
    and template.template_id is null
    and template.is_default
);

update public.transaction_splits split
set category_id = public.default_category_clone_id(
  split.user_id,
  split.category_id
)
where exists (
  select 1
  from public.categories template
  where template.id = split.category_id
    and template.user_id is null
    and template.template_id is null
    and template.is_default
);

alter table public.category_groups
  add constraint category_groups_template_id_fkey
  foreign key (template_id) references public.category_groups(id) on delete restrict;
alter table public.categories
  add constraint categories_template_id_fkey
  foreign key (template_id) references public.categories(id) on delete restrict;

alter table public.category_groups
  add constraint category_groups_clone_owner_check
  check (template_id is null or user_id is not null),
  add constraint category_groups_clone_id_check
  check (
    template_id is null
    or id = public.default_category_group_clone_id(user_id, template_id)
  ),
  add constraint category_groups_global_budget_check
  check (
    user_id is not null
    or (budget_amount is null and budget_currency is null)
  );

alter table public.categories
  add constraint categories_clone_owner_check
  check (template_id is null or user_id is not null),
  add constraint categories_clone_id_check
  check (
    template_id is null
    or id = public.default_category_clone_id(user_id, template_id)
  ),
  add constraint categories_global_budget_check
  check (
    user_id is not null
    or (budget_amount is null and budget_currency is null)
  );

create unique index category_groups_user_template_uidx
  on public.category_groups (user_id, template_id)
  where template_id is not null;
create index category_groups_template_id_idx
  on public.category_groups (template_id)
  where template_id is not null;
create unique index categories_user_template_uidx
  on public.categories (user_id, template_id)
  where template_id is not null;
create index categories_template_id_idx
  on public.categories (template_id)
  where template_id is not null;

create or replace function public.rewrite_legacy_category_group_insert()
returns trigger
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  template public.category_groups%rowtype;
begin
  if new.user_id is null then
    return new;
  end if;

  select * into template
  from public.category_groups candidate
  where candidate.id = new.id
    and candidate.user_id is null
    and candidate.template_id is null;

  if not found then
    return new;
  end if;

  new.id := public.default_category_group_clone_id(new.user_id, template.id);
  new.template_id := template.id;
  new.name := template.name;
  new.icon := template.icon;
  new.color := template.color;
  new.sort_order := template.sort_order;
  new.created_at := coalesce(new.created_at, now());
  return new;
end;
$$;

create or replace function public.rewrite_legacy_category_insert()
returns trigger
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  template public.categories%rowtype;
begin
  if new.user_id is null then
    return new;
  end if;

  select * into template
  from public.categories candidate
  where candidate.id = new.id
    and candidate.user_id is null
    and candidate.template_id is null
    and candidate.is_default;

  if not found then
    return new;
  end if;

  new.id := public.default_category_clone_id(new.user_id, template.id);
  new.template_id := template.id;
  new.name := template.name;
  new.parent_id := case
    when template.parent_id is null then null
    else public.default_category_clone_id(new.user_id, template.parent_id)
  end;
  new.type := template.type;
  new."group" := template."group";
  new.group_id := public.default_category_group_clone_id(
    new.user_id,
    template.group_id
  );
  new.icon := template.icon;
  new.color := template.color;
  new.is_default := true;
  new.created_at := coalesce(new.created_at, now());
  return new;
end;
$$;

create or replace function public.validate_category_group_clone()
returns trigger
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
begin
  if new.template_id is not null and not exists (
    select 1 from public.category_groups template
    where template.id = new.template_id
      and template.user_id is null
      and template.template_id is null
  ) then
    raise exception 'Category group template must be global'
      using errcode = '23503';
  end if;
  return new;
end;
$$;

create or replace function public.validate_category_clone()
returns trigger
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  template_group_id uuid;
begin
  if new.template_id is not null then
    select template.group_id into template_group_id
    from public.categories template
    where template.id = new.template_id
      and template.user_id is null
      and template.template_id is null
      and template.is_default;
    if not found then
      raise exception 'Category template must be global'
        using errcode = '23503';
    end if;
    if new.group_id is distinct from public.default_category_group_clone_id(
      new.user_id,
      template_group_id
    ) then
      raise exception 'Category clone must use its owner group clone'
        using errcode = '23503';
    end if;
  end if;

  if new.group_id is not null and not exists (
    select 1 from public.category_groups category_group
    where category_group.id = new.group_id
      and category_group.user_id is not distinct from new.user_id
  ) then
    raise exception 'Category group must have the same owner'
      using errcode = '23503';
  end if;
  return new;
end;
$$;

create or replace function public.rewrite_template_category_reference()
returns trigger
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
begin
  if new.category_id is null then
    return new;
  end if;

  if exists (
    select 1 from public.categories template
    where template.id = new.category_id
      and template.user_id is null
      and template.template_id is null
      and template.is_default
  ) then
    new.category_id := public.default_category_clone_id(
      new.user_id,
      new.category_id
    );
  end if;

  if not exists (
    select 1 from public.categories category
    where category.id = new.category_id
      and category.user_id = new.user_id
  ) then
    raise exception 'Transaction category must have the same owner'
      using errcode = '23503';
  end if;
  return new;
end;
$$;

create trigger category_groups_10_rewrite_legacy_template_insert
before insert on public.category_groups
for each row execute function public.rewrite_legacy_category_group_insert();
create trigger category_groups_90_validate_clone
before insert or update on public.category_groups
for each row execute function public.validate_category_group_clone();
create trigger categories_10_rewrite_legacy_template_insert
before insert on public.categories
for each row execute function public.rewrite_legacy_category_insert();
create trigger categories_90_validate_clone
before insert or update on public.categories
for each row execute function public.validate_category_clone();
create trigger transactions_10_rewrite_template_category
before insert or update of user_id, category_id on public.transactions
for each row execute function public.rewrite_template_category_reference();
create trigger transaction_splits_10_rewrite_template_category
before insert or update of user_id, category_id on public.transaction_splits
for each row execute function public.rewrite_template_category_reference();

create or replace function public.on_profile_insert_ensure_default_category_clones()
returns trigger
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
begin
  perform public.ensure_default_category_clones(new.id);
  return new;
end;
$$;

create trigger profiles_10_ensure_default_category_clones
after insert on public.profiles
for each row execute function public.on_profile_insert_ensure_default_category_clones();

create or replace function public.aiko_budget_status(start_date date, end_date date)
returns table(name text, budget_limit numeric, spent numeric)
language sql
stable
set search_path = public
as $$
  select
    c.name,
    coalesce(nullif(c.budget_amount, '')::numeric, 0) as budget_limit,
    coalesce((
      select sum(t.amount)
      from public.transactions t
      where t.user_id = auth.uid()
        and t.type = 'expense'
        and t.category_id = c.id
        and t.date >= start_date
        and t.date < (end_date + 1)
    ), 0) as spent
  from public.categories c
  where c.user_id = auth.uid()
    and c.is_active
    and c.budget_enabled
    and c.budget_amount is not null
    and c.budget_amount <> ''
  order by c.name
  limit 50;
$$;

revoke all on function public.default_category_group_clone_id(uuid, uuid)
  from public, anon;
revoke all on function public.default_category_clone_id(uuid, uuid)
  from public, anon;
revoke all on function public.ensure_default_category_clones(uuid)
  from public, anon;
revoke all on function public.rewrite_legacy_category_group_insert()
  from public, anon;
revoke all on function public.rewrite_legacy_category_insert()
  from public, anon;
revoke all on function public.validate_category_group_clone()
  from public, anon;
revoke all on function public.validate_category_clone()
  from public, anon;
revoke all on function public.rewrite_template_category_reference()
  from public, anon;
revoke all on function public.on_profile_insert_ensure_default_category_clones()
  from public, anon;

grant execute on function public.default_category_group_clone_id(uuid, uuid)
  to authenticated, service_role;
grant execute on function public.default_category_clone_id(uuid, uuid)
  to authenticated, service_role;
grant execute on function public.ensure_default_category_clones(uuid)
  to authenticated, service_role;

notify pgrst, 'reload schema';
