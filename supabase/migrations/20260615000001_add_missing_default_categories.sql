-- Add 15 missing default categories identified from the design reference:
-- - Food Delivery
-- - Public Transport
-- - Water
-- - Electricity
-- - Home Loan Interest
-- - Social Security
-- - Jewelry & Accessories
-- - Shoes & Sneakers
-- - Workshops
-- - Doctor Visit
-- - Medicine & Treatment
-- - Life Insurance
-- - Gym & Boxing
-- - Fitness Class
-- - Fitness Equipment
-- - Supplements
--
-- Ids continue the …-c200-… block from 0037 → 0046. Each row lands in the
-- matching existing default group via group_id (no group restructuring; the
-- design reference's separate Health / Fitness / Work / Donation / Gifts
-- groups are intentionally deferred — this migration only fills in
-- categories that fit the current 13-group taxonomy).
--
-- `on conflict (id) do nothing` keeps the migration idempotent.

insert into public.categories
  (id, user_id, name, type, "group", icon, color, budget_enabled, is_default, is_active)
values
  -- Food & Drink
  ('00000000-0000-0000-c200-000000000037', null, 'Food Delivery',       'expense', 'wants',  'food_delivery',      '#F97316', true, true, true),
  -- Transport
  ('00000000-0000-0000-c200-000000000038', null, 'Public Transport',    'expense', 'needs',  'public_transport',   '#1E40AF', true, true, true),
  -- Bills & Financial
  ('00000000-0000-0000-c200-000000000039', null, 'Water',               'expense', 'needs',  'water',              '#0EA5E9', true, true, true),
  ('00000000-0000-0000-c200-00000000003a', null, 'Electricity',         'expense', 'needs',  'electricity',        '#FACC15', true, true, true),
  ('00000000-0000-0000-c200-00000000003b', null, 'Home Loan Interest',  'expense', 'debt',   'loan_interest',      '#7C2D12', true, true, true),
  ('00000000-0000-0000-c200-00000000003c', null, 'Social Security',     'expense', 'custom', 'social_security',    '#1E40AF', true, true, true),
  -- Shopping & Personal
  ('00000000-0000-0000-c200-00000000003d', null, 'Jewelry & Accessories','expense','wants',  'jewelry',            '#C084FC', true, true, true),
  ('00000000-0000-0000-c200-00000000003e', null, 'Shoes & Sneakers',    'expense', 'wants',  'shoes',              '#9333EA', true, true, true),
  -- Education
  ('00000000-0000-0000-c200-00000000003f', null, 'Workshops',           'expense', 'needs',  'workshop',           '#92400E', true, true, true),
  -- Health & Fitness
  ('00000000-0000-0000-c200-000000000040', null, 'Doctor Visit',        'expense', 'needs',  'doctor',             '#047857', true, true, true),
  ('00000000-0000-0000-c200-000000000041', null, 'Medicine & Treatment','expense', 'needs',  'medicine_treatment', '#065F46', true, true, true),
  ('00000000-0000-0000-c200-000000000042', null, 'Life Insurance',      'expense', 'needs',  'life_insurance',     '#0F766E', true, true, true),
  ('00000000-0000-0000-c200-000000000043', null, 'Gym & Boxing',        'expense', 'wants',  'boxing',             '#16A34A', true, true, true),
  ('00000000-0000-0000-c200-000000000044', null, 'Fitness Class',       'expense', 'wants',  'fitness_class',      '#15803D', true, true, true),
  ('00000000-0000-0000-c200-000000000045', null, 'Fitness Equipment',   'expense', 'wants',  'fitness_equipment',  '#166534', true, true, true),
  ('00000000-0000-0000-c200-000000000046', null, 'Supplements',         'expense', 'wants',  'supplements',        '#84CC16', true, true, true)
on conflict (id) do nothing;
