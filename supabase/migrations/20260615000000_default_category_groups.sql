-- Replace the single global "System" category group with 13 meaningful
-- default groups (Food & Drink, Transport, Health & Fitness, …, Other) and
-- expand the 30 built-in system categories to a budget-friendly taxonomy of
-- 66. Existing category UUIDs are preserved so live transactions keep working;
-- only their `group_id` is re-filed (and a handful of display names updated).
--
-- Pattern recap (extend, never reshuffle):
--   c100… = income categories    (was 10 rows, now 11)
--   c200… = expense categories   (was 19 rows, now 55)
--   c300… = category groups      (was 1 row "System", now 13 rows)
--
-- The "Other" group keeps the same UUID as the old "System" group
-- (…-c300-0001) — just renamed — and continues to absorb unfiled custom
-- categories (`group_id` null/empty). See CategoryGroupDefaults.unfiledGroupId.

-- ── 1. Insert the 12 new default groups ────────────────────────────────────
insert into public.category_groups
  (id, user_id, name, icon, color, sort_order)
values
  ('00000000-0000-0000-c300-000000000002', null, 'Income & Earnings',      'salary',      '#16A34A', (1<<20) + 1),
  ('00000000-0000-0000-c300-000000000003', null, 'Investments & Savings', 'investing',   '#8B5CF6', (1<<20) + 2),
  ('00000000-0000-0000-c300-000000000004', null, 'Food & Drink',          'food',        '#F97316', (1<<20) + 3),
  ('00000000-0000-0000-c300-000000000005', null, 'Transport',             'transport',   '#3B82F6', (1<<20) + 4),
  ('00000000-0000-0000-c300-000000000006', null, 'Housing & Utilities',   'home',        '#7C3AED', (1<<20) + 5),
  ('00000000-0000-0000-c300-000000000007', null, 'Health & Fitness',      'health',      '#10B981', (1<<20) + 6),
  ('00000000-0000-0000-c300-000000000008', null, 'Shopping & Personal',   'shopping',    '#EC4899', (1<<20) + 7),
  ('00000000-0000-0000-c300-000000000009', null, 'Entertainment & Leisure','entertainment','#F43F5E', (1<<20) + 8),
  ('00000000-0000-0000-c300-00000000000a', null, 'Education',             'education',   '#F59E0B', (1<<20) + 9),
  ('00000000-0000-0000-c300-00000000000b', null, 'Travel',                'travel',      '#38BDF8', (1<<20) + 10),
  ('00000000-0000-0000-c300-00000000000c', null, 'Family & Giving',       'gift',        '#6366F1', (1<<20) + 11),
  ('00000000-0000-0000-c300-00000000000d', null, 'Bills & Financial',     'fee',         '#DC2626', (1<<20) + 12)
on conflict (id) do nothing;

-- ── 2. Rename the existing "System" group to "Other" (id unchanged) ───────
update public.category_groups
  set name = 'Other', icon = 'category', color = '#64748B'
  where id = '00000000-0000-0000-c300-000000000001';

-- ── 3. Insert the 36 new default categories ────────────────────────────────
insert into public.categories
  (id, user_id, name, type, "group", icon, color, budget_enabled, is_default, is_active)
values
  -- Income side
  ('00000000-0000-0000-c100-00000000000b', null, 'Capital Gains',     'income', 'investment', 'investing', '#7C3AED', false, true, true),
  -- Food & Drink
  ('00000000-0000-0000-c200-000000000014', null, 'Lunch',             'expense', 'wants',   'lunch',     '#FB923C', true, true, true),
  ('00000000-0000-0000-c200-000000000015', null, 'Dinner',            'expense', 'wants',   'dinner',    '#DC2626', true, true, true),
  ('00000000-0000-0000-c200-000000000016', null, 'Dessert',           'expense', 'wants',   'dessert',   '#F472B6', true, true, true),
  ('00000000-0000-0000-c200-000000000017', null, 'Bubble Tea',        'expense', 'wants',   'bubble_tea','#A78BFA', true, true, true),
  ('00000000-0000-0000-c200-000000000018', null, 'Drinks / Bar',      'expense', 'wants',   'drink',     '#C084FC', true, true, true),
  ('00000000-0000-0000-c200-000000000019', null, 'Snacks',            'expense', 'wants',   'snack',     '#FBBF24', true, true, true),
  -- Transport
  ('00000000-0000-0000-c200-00000000001a', null, 'Taxi / Rideshare',  'expense', 'needs',   'taxi',      '#1D4ED8', true, true, true),
  ('00000000-0000-0000-c200-00000000001b', null, 'Parking',           'expense', 'needs',   'parking',   '#0369A1', true, true, true),
  ('00000000-0000-0000-c200-00000000001c', null, 'Vehicle Maintenance','expense','needs',   'maintenance','#0891B2', true, true, true),
  ('00000000-0000-0000-c200-00000000001d', null, 'Tolls',             'expense', 'needs',   'tolls',     '#0284C7', true, true, true),
  -- Housing & Utilities
  ('00000000-0000-0000-c200-00000000001e', null, 'Home Maintenance',  'expense', 'needs',   'maintenance','#A855F7', true, true, true),
  ('00000000-0000-0000-c200-00000000001f', null, 'Furniture & Appliances','expense','wants', 'furniture', '#9333EA', true, true, true),
  -- Health & Fitness
  ('00000000-0000-0000-c200-000000000020', null, 'Pharmacy / Medicine','expense', 'needs',   'pharmacy',  '#059669', true, true, true),
  ('00000000-0000-0000-c200-000000000021', null, 'Dental',            'expense', 'needs',   'dental',    '#0D9488', true, true, true),
  ('00000000-0000-0000-c200-000000000022', null, 'Fitness / Gym',     'expense', 'wants',   'gym',       '#22C55E', true, true, true),
  -- Shopping & Personal
  ('00000000-0000-0000-c200-000000000023', null, 'Clothing',          'expense', 'wants',   'clothing',  '#DB2777', true, true, true),
  ('00000000-0000-0000-c200-000000000024', null, 'Electronics',       'expense', 'wants',   'electronics','#BE185D', true, true, true),
  ('00000000-0000-0000-c200-000000000025', null, 'Personal Care',     'expense', 'wants',   'personal_care','#F472B6', true, true, true),
  -- Entertainment & Leisure
  ('00000000-0000-0000-c200-000000000026', null, 'Movies',            'expense', 'wants',   'movie',     '#BE123C', true, true, true),
  ('00000000-0000-0000-c200-000000000027', null, 'Games',             'expense', 'wants',   'game',      '#9F1239', true, true, true),
  ('00000000-0000-0000-c200-000000000028', null, 'Music / Streaming', 'expense', 'wants',   'music',     '#E11D48', true, true, true),
  ('00000000-0000-0000-c200-000000000029', null, 'Concerts / Events', 'expense', 'wants',   'concert',   '#FB7185', true, true, true),
  ('00000000-0000-0000-c200-00000000002a', null, 'Hobbies',           'expense', 'wants',   'hobby',     '#F59E0B', true, true, true),
  -- Education
  ('00000000-0000-0000-c200-00000000002b', null, 'Books',             'expense', 'needs',   'book',      '#D97706', true, true, true),
  ('00000000-0000-0000-c200-00000000002c', null, 'Courses',           'expense', 'needs',   'courses',   '#B45309', true, true, true),
  -- Travel
  ('00000000-0000-0000-c200-00000000002d', null, 'Flights',           'expense', 'wants',   'flights',   '#0EA5E9', true, true, true),
  ('00000000-0000-0000-c200-00000000002e', null, 'Accommodation',     'expense', 'wants',   'hotel',     '#0284C7', true, true, true),
  ('00000000-0000-0000-c200-00000000002f', null, 'Foreign Fees',      'expense', 'wants',   'foreign_fees','#0EA5E9', true, true, true),
  -- Family & Giving
  ('00000000-0000-0000-c200-000000000030', null, 'Gifts',             'expense', 'wants',   'gifts',     '#6366F1', true, true, true),
  ('00000000-0000-0000-c200-000000000031', null, 'Childcare',         'expense', 'needs',   'childcare', '#8B5CF6', true, true, true),
  ('00000000-0000-0000-c200-000000000032', null, 'Pets',              'expense', 'needs',   'pets',      '#A855F7', true, true, true),
  ('00000000-0000-0000-c200-000000000033', null, 'Donations / Charity','expense','custom',  'donation',  '#4F46E5', true, true, true),
  -- Bills & Financial
  ('00000000-0000-0000-c200-000000000034', null, 'Loan Payment',      'expense', 'debt',    'loan',      '#B91C1C', true, true, true),
  ('00000000-0000-0000-c200-000000000035', null, 'Credit Card Payment','expense','debt',    'credit_card','#991B1B', true, true, true),
  ('00000000-0000-0000-c200-000000000036', null, 'Savings Contribution','expense','savings','savings',   '#16A34A', true, true, true)
on conflict (id) do nothing;

-- ── 4. Re-file every default category into its new group ──────────────────
-- Income & Earnings
update public.categories set group_id = '00000000-0000-0000-c300-000000000002'
  where id in (
    '00000000-0000-0000-c100-000000000001', -- Salary
    '00000000-0000-0000-c100-000000000002', -- Bonus
    '00000000-0000-0000-c100-000000000003', -- Freelance
    '00000000-0000-0000-c100-000000000004', -- Business
    '00000000-0000-0000-c100-000000000008', -- Refunds
    '00000000-0000-0000-c100-000000000009', -- Gift Received
    '00000000-0000-0000-c100-00000000000a'  -- Other Income
  );

-- Investments & Savings
update public.categories set group_id = '00000000-0000-0000-c300-000000000003'
  where id in (
    '00000000-0000-0000-c100-000000000005', -- Interest
    '00000000-0000-0000-c100-000000000006', -- Dividends
    '00000000-0000-0000-c100-000000000007'  -- Rental Income
  );

-- Food & Drink
update public.categories set group_id = '00000000-0000-0000-c300-000000000004'
  where id in (
    '00000000-0000-0000-c200-000000000001', -- Groceries
    '00000000-0000-0000-c200-000000000002', -- Dining Out
    '00000000-0000-0000-c200-000000000003', -- Coffee
    '00000000-0000-0000-c200-000000000014', -- Lunch
    '00000000-0000-0000-c200-000000000015', -- Dinner
    '00000000-0000-0000-c200-000000000016', -- Dessert
    '00000000-0000-0000-c200-000000000017', -- Bubble Tea
    '00000000-0000-0000-c200-000000000018', -- Drinks / Bar
    '00000000-0000-0000-c200-000000000019'  -- Snacks
  );

-- Transport
update public.categories set group_id = '00000000-0000-0000-c300-000000000005'
  where id in (
    '00000000-0000-0000-c200-000000000004', -- Transport
    '00000000-0000-0000-c200-000000000005', -- Fuel
    '00000000-0000-0000-c200-00000000001a', -- Taxi / Rideshare
    '00000000-0000-0000-c200-00000000001b', -- Parking
    '00000000-0000-0000-c200-00000000001c', -- Vehicle Maintenance
    '00000000-0000-0000-c200-00000000001d'  -- Tolls
  );

-- Housing & Utilities
update public.categories set group_id = '00000000-0000-0000-c300-000000000006'
  where id in (
    '00000000-0000-0000-c200-000000000006', -- Rent / Mortgage
    '00000000-0000-0000-c200-000000000007', -- Utilities
    '00000000-0000-0000-c200-000000000008', -- Phone
    '00000000-0000-0000-c200-000000000009', -- Internet
    '00000000-0000-0000-c200-00000000001e', -- Home Maintenance
    '00000000-0000-0000-c200-00000000001f'  -- Furniture & Appliances
  );

-- Health & Fitness
update public.categories set group_id = '00000000-0000-0000-c300-000000000007'
  where id in (
    '00000000-0000-0000-c200-00000000000c', -- Health
    '00000000-0000-0000-c200-00000000000d', -- Insurance
    '00000000-0000-0000-c200-000000000020', -- Pharmacy / Medicine
    '00000000-0000-0000-c200-000000000021', -- Dental
    '00000000-0000-0000-c200-000000000022'  -- Fitness / Gym
  );

-- Shopping & Personal
update public.categories set group_id = '00000000-0000-0000-c300-000000000008'
  where id in (
    '00000000-0000-0000-c200-00000000000b', -- Shopping
    '00000000-0000-0000-c200-000000000023', -- Clothing
    '00000000-0000-0000-c200-000000000024', -- Electronics
    '00000000-0000-0000-c200-000000000025'  -- Personal Care
  );

-- Entertainment & Leisure
update public.categories set group_id = '00000000-0000-0000-c300-000000000009'
  where id in (
    '00000000-0000-0000-c200-000000000010', -- Entertainment
    '00000000-0000-0000-c200-00000000000a', -- Subscriptions
    '00000000-0000-0000-c200-000000000026', -- Movies
    '00000000-0000-0000-c200-000000000027', -- Games
    '00000000-0000-0000-c200-000000000028', -- Music / Streaming
    '00000000-0000-0000-c200-000000000029', -- Concerts / Events
    '00000000-0000-0000-c200-00000000002a'  -- Hobbies
  );

-- Education
update public.categories set group_id = '00000000-0000-0000-c300-00000000000a'
  where id in (
    '00000000-0000-0000-c200-00000000000e', -- Education
    '00000000-0000-0000-c200-00000000002b', -- Books
    '00000000-0000-0000-c200-00000000002c'  -- Courses
  );

-- Travel
update public.categories set group_id = '00000000-0000-0000-c300-00000000000b'
  where id in (
    '00000000-0000-0000-c200-00000000000f', -- Travel
    '00000000-0000-0000-c200-00000000002d', -- Flights
    '00000000-0000-0000-c200-00000000002e', -- Accommodation
    '00000000-0000-0000-c200-00000000002f'  -- Foreign Fees
  );

-- Family & Giving
update public.categories set group_id = '00000000-0000-0000-c300-00000000000c'
  where id in (
    '00000000-0000-0000-c200-000000000030', -- Gifts
    '00000000-0000-0000-c200-000000000031', -- Childcare
    '00000000-0000-0000-c200-000000000032', -- Pets
    '00000000-0000-0000-c200-000000000033'  -- Donations / Charity
  );

-- Bills & Financial
update public.categories set group_id = '00000000-0000-0000-c300-00000000000d'
  where id in (
    '00000000-0000-0000-c200-000000000011', -- Fees
    '00000000-0000-0000-c200-000000000012', -- Taxes
    '00000000-0000-0000-c200-000000000034', -- Loan Payment
    '00000000-0000-0000-c200-000000000035', -- Credit Card Payment
    '00000000-0000-0000-c200-000000000036'  -- Savings Contribution
  );

-- Other (the renamed "System" group, c300…0001) holds the catch-all Other
-- expense. No re-file needed for existing rows; the rename happened in step 2.

-- ── 5. Display renames (ids unchanged) ────────────────────────────────────
update public.categories set name = 'Gift Received'  where id = '00000000-0000-0000-c100-000000000009';
update public.categories set name = 'Other Income'   where id = '00000000-0000-0000-c100-00000000000a';
update public.categories set name = 'Rental Income'  where id = '00000000-0000-0000-c100-000000000007';
update public.categories set name = 'Dining Out'     where id = '00000000-0000-0000-c200-000000000002';
update public.categories set name = 'Rent / Mortgage' where id = '00000000-0000-0000-c200-000000000006';
