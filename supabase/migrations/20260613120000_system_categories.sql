-- Make user_id nullable so system (global) categories can exist with
-- user_id = NULL. User-owned custom categories are unaffected.
alter table public.categories
  alter column user_id drop not null;

-- Drop the single FOR ALL policy and replace with per-operation policies so
-- SELECT can reach system rows while writes stay user-scoped.
drop policy if exists "categories own rows" on public.categories;

-- Anyone authenticated can read their own categories AND system ones.
create policy "categories select"
  on public.categories for select
  using (user_id is null or user_id = auth.uid());

-- Users can only write rows they own.
create policy "categories insert"
  on public.categories for insert
  with check (user_id = auth.uid());

create policy "categories update"
  on public.categories for update
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy "categories delete"
  on public.categories for delete
  using (user_id = auth.uid());

-- Insert the 30 global system categories. user_id = NULL, is_default = true.
-- These ids match CategoryDefaults in the Flutter app; they must never change.
insert into public.categories
  (id, user_id, name, type, "group", icon, color, budget_enabled, is_default, is_active)
values
  -- Income
  ('00000000-0000-0000-c100-000000000001', null, 'Salary',       'income', 'custom',     'salary',      '#22C55E', false, true, true),
  ('00000000-0000-0000-c100-000000000002', null, 'Bonus',        'income', 'custom',     'gift',        '#16A34A', false, true, true),
  ('00000000-0000-0000-c100-000000000003', null, 'Freelance',    'income', 'business',   'work',        '#14B8A6', false, true, true),
  ('00000000-0000-0000-c100-000000000004', null, 'Business',     'income', 'business',   'business',    '#0EA5E9', false, true, true),
  ('00000000-0000-0000-c100-000000000005', null, 'Interest',     'income', 'savings',    'savings',     '#06B6D4', false, true, true),
  ('00000000-0000-0000-c100-000000000006', null, 'Dividends',    'income', 'investment', 'investment',  '#8B5CF6', false, true, true),
  ('00000000-0000-0000-c100-000000000007', null, 'Rental',       'income', 'investment', 'home',        '#6366F1', false, true, true),
  ('00000000-0000-0000-c100-000000000008', null, 'Refunds',      'income', 'custom',     'refund',      '#10B981', false, true, true),
  ('00000000-0000-0000-c100-000000000009', null, 'Gift',         'income', 'custom',     'gift',        '#EC4899', false, true, true),
  ('00000000-0000-0000-c100-00000000000a', null, 'Other',        'income', 'custom',     'category',    '#64748B', false, true, true),
  -- Expense
  ('00000000-0000-0000-c200-000000000001', null, 'Groceries',     'expense', 'needs',   'groceries',     '#F97316', true, true, true),
  ('00000000-0000-0000-c200-000000000002', null, 'Dining',        'expense', 'wants',   'dining',        '#EF4444', true, true, true),
  ('00000000-0000-0000-c200-000000000003', null, 'Coffee',        'expense', 'wants',   'coffee',        '#8B5A2B', true, true, true),
  ('00000000-0000-0000-c200-000000000004', null, 'Transport',     'expense', 'needs',   'transport',     '#3B82F6', true, true, true),
  ('00000000-0000-0000-c200-000000000005', null, 'Fuel',          'expense', 'needs',   'fuel',          '#2563EB', true, true, true),
  ('00000000-0000-0000-c200-000000000006', null, 'Rent',          'expense', 'needs',   'home',          '#7C3AED', true, true, true),
  ('00000000-0000-0000-c200-000000000007', null, 'Utilities',     'expense', 'needs',   'utilities',     '#0EA5E9', true, true, true),
  ('00000000-0000-0000-c200-000000000008', null, 'Phone',         'expense', 'needs',   'phone',         '#06B6D4', true, true, true),
  ('00000000-0000-0000-c200-000000000009', null, 'Internet',      'expense', 'needs',   'internet',      '#0284C7', true, true, true),
  ('00000000-0000-0000-c200-00000000000a', null, 'Subscriptions', 'expense', 'wants',   'subscriptions', '#A855F7', true, true, true),
  ('00000000-0000-0000-c200-00000000000b', null, 'Shopping',      'expense', 'wants',   'shopping',      '#EC4899', true, true, true),
  ('00000000-0000-0000-c200-00000000000c', null, 'Health',        'expense', 'needs',   'health',        '#10B981', true, true, true),
  ('00000000-0000-0000-c200-00000000000d', null, 'Insurance',     'expense', 'needs',   'insurance',     '#14B8A6', true, true, true),
  ('00000000-0000-0000-c200-00000000000e', null, 'Education',     'expense', 'needs',   'education',     '#F59E0B', true, true, true),
  ('00000000-0000-0000-c200-00000000000f', null, 'Travel',        'expense', 'wants',   'travel',        '#38BDF8', true, true, true),
  ('00000000-0000-0000-c200-000000000010', null, 'Entertainment', 'expense', 'wants',   'entertainment', '#F43F5E', true, true, true),
  ('00000000-0000-0000-c200-000000000011', null, 'Fees',          'expense', 'custom',  'fee',           '#64748B', true, true, true),
  ('00000000-0000-0000-c200-000000000012', null, 'Taxes',         'expense', 'tax',     'tax',           '#DC2626', true, true, true),
  ('00000000-0000-0000-c200-000000000013', null, 'Other',         'expense', 'custom',  'category',      '#64748B', true, true, true)
on conflict (id) do nothing;
