-- Built-in categories are rendered from CategoryDefaults in the app, but
-- transactions persist their stable ids. Matching global rows are therefore
-- required for transactions.category_id's foreign key.
with income_names as (
  select ordinal::integer as sequence, name
  from unnest(array[
    'Salary',
    'Bonus',
    'Freelance',
    'Business',
    'Interest',
    'Dividends',
    'Rental Income',
    'Refunds',
    'Gift Received',
    'Other Income',
    'Capital Gains'
  ]::text[]) with ordinality as names(name, ordinal)
),
expense_names as (
  select ordinal::integer as sequence, name
  from unnest(array[
    'Groceries',
    'Dining Out',
    'Coffee',
    'Transport',
    'Fuel',
    'Rent / Mortgage',
    'Utilities',
    'Phone',
    'Internet',
    'Subscriptions',
    'Shopping',
    'Health',
    'Insurance',
    'Education',
    'Travel',
    'Entertainment',
    'Fees',
    'Taxes',
    'Other',
    'Lunch',
    'Dinner',
    'Dessert',
    'Bubble Tea',
    'Drinks / Bar',
    'Snacks',
    'Taxi / Rideshare',
    'Parking',
    'Vehicle Maintenance',
    'Tolls',
    'Home Maintenance',
    'Furniture & Appliances',
    'Pharmacy / Medicine',
    'Dental',
    'Fitness / Gym',
    'Clothing',
    'Electronics',
    'Personal Care',
    'Movies',
    'Games',
    'Music / Streaming',
    'Concerts / Events',
    'Hobbies',
    'Books',
    'Courses',
    'Flights',
    'Accommodation',
    'Foreign Fees',
    'Gifts',
    'Childcare',
    'Pets',
    'Donations / Charity',
    'Loan Payment',
    'Credit Card Payment',
    'Savings Contribution',
    'Food Delivery',
    'Public Transport',
    'Water',
    'Electricity',
    'Home Loan Interest',
    'Social Security',
    'Jewelry & Accessories',
    'Shoes & Sneakers',
    'Workshops',
    'Doctor Visit',
    'Medicine & Treatment',
    'Life Insurance',
    'Gym & Boxing',
    'Fitness Class',
    'Fitness Equipment',
    'Supplements'
  ]::text[]) with ordinality as names(name, ordinal)
),
defaults as (
  select
    format(
      '00000000-0000-0000-c100-%s',
      lpad(to_hex(sequence), 12, '0')
    )::uuid as id,
    name,
    'income'::text as type
  from income_names

  union all

  select
    format(
      '00000000-0000-0000-c200-%s',
      lpad(to_hex(sequence), 12, '0')
    )::uuid as id,
    name,
    'expense'::text as type
  from expense_names
)
insert into public.categories (
  id,
  user_id,
  name,
  type,
  budget_enabled,
  is_default,
  is_active
)
select
  id,
  null,
  name,
  type,
  type = 'expense',
  true,
  true
from defaults
on conflict (id) do nothing;
