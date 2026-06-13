-- User-defined category groups: organisational buckets ("Household", "Car",
-- "Kids") that users create to section their categories. Purely cosmetic —
-- they do not affect budgeting math (that stays on categories."group").

create table if not exists public.category_groups (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  name text not null,
  icon text not null default 'category',
  color text not null default '#3B82F6',
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists category_groups_user_id_idx
  on public.category_groups (user_id);

alter table public.category_groups enable row level security;

-- Users can only access their own groups.
create policy "category_groups own rows" on public.category_groups
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Link categories to a group. ON DELETE SET NULL keeps the category but moves
-- it back to "Ungrouped" when its group is removed. System (global) categories
-- have user_id = NULL and always keep group_id = NULL.
alter table public.categories
  add column if not exists group_id uuid
  references public.category_groups(id) on delete set null;

create index if not exists categories_group_id_idx
  on public.categories (group_id);
