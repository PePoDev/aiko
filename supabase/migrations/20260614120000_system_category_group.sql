-- Promote the category_groups table to also hold the single global "System"
-- group (user_id = NULL) that owns the built-in system categories. This
-- supersedes the note in 20260613130000_category_groups.sql that system
-- categories "always keep group_id = NULL".

-- Make user_id nullable so the global System group can exist with
-- user_id = NULL. User-owned groups are unaffected.
alter table public.category_groups
  alter column user_id drop not null;

-- Drop the single FOR ALL policy and replace with per-operation policies so
-- SELECT can reach the global System group while writes stay user-scoped.
drop policy if exists "category_groups own rows" on public.category_groups;

-- Anyone authenticated can read their own groups AND the global System group.
create policy "category_groups select"
  on public.category_groups for select
  using (user_id is null or user_id = auth.uid());

-- Users can only write rows they own.
create policy "category_groups insert"
  on public.category_groups for insert
  with check (user_id = auth.uid());

create policy "category_groups update"
  on public.category_groups for update
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy "category_groups delete"
  on public.category_groups for delete
  using (user_id = auth.uid());

-- Insert the global System group. user_id = NULL. This id matches
-- CategoryGroupDefaults.systemId in the Flutter app; it must never change.
-- sort_order 1048576 (1 << 20) mirrors CategoryGroupDefaults.systemSortOrder
-- so the group always sorts after user-created groups.
insert into public.category_groups
  (id, user_id, name, icon, color, sort_order)
values
  ('00000000-0000-0000-c300-000000000001', null, 'System', 'category', '#64748B', 1048576)
on conflict (id) do nothing;

-- File the 30 global system categories into the System group. System rows are
-- the only categories with user_id = NULL.
update public.categories
  set group_id = '00000000-0000-0000-c300-000000000001'
  where user_id is null;
