create table if not exists public.aiko_character_profiles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  visibility text not null default 'full',
  tone text not null default 'supportive',
  reduce_motion boolean not null default false,
  hide_character_art boolean not null default false,
  serious_warning_style text not null default 'professional',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id)
);

create table if not exists public.import_jobs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  source_type text not null,
  status text not null default 'preview',
  mapping_json jsonb not null default '{}',
  validation_issues jsonb not null default '[]',
  duplicate_count integer not null default 0,
  created_at timestamptz not null default now(),
  completed_at timestamptz
);

create table if not exists public.export_packages (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  scope text not null,
  format text not null,
  sensitivity_acknowledged boolean not null default false,
  status text not null default 'pending',
  storage_path text,
  created_at timestamptz not null default now(),
  expires_at timestamptz
);

create table if not exists public.backup_snapshots (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'ready',
  snapshot_scope text not null default 'full',
  storage_path text,
  checksum text,
  created_at timestamptz not null default now(),
  restored_at timestamptz
);

create table if not exists public.bill_subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  merchant text not null,
  amount numeric(18, 4) not null,
  currency char(3) not null,
  billing_cycle text not null,
  next_billing_date date not null,
  category_id uuid references public.categories(id),
  cancellation_status text not null default 'active',
  lower_bill_status text not null default 'notReviewed',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.credit_card_profiles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  account_id uuid references public.accounts(id) on delete cascade,
  credit_limit numeric(18, 4) not null default 0,
  statement_balance numeric(18, 4) not null default 0,
  minimum_payment numeric(18, 4) not null default 0,
  apr numeric(7, 4) not null default 0,
  rewards_type text,
  due_day integer not null default 1,
  statement_day integer not null default 1,
  annual_fee numeric(18, 4) not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.debt_loan_plans (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  name text not null,
  strategy text not null default 'avalanche',
  principal_balance numeric(18, 4) not null,
  interest_rate numeric(7, 4) not null default 0,
  monthly_payment numeric(18, 4) not null default 0,
  payoff_forecast_date date,
  interest_savings_estimate numeric(18, 4),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.assets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  name text not null,
  asset_class text not null,
  value numeric(18, 4) not null default 0,
  currency char(3) not null,
  liquidity_level text not null default 'medium',
  risk_level text not null default 'medium',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.investment_holdings (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  symbol text not null,
  asset_class text not null,
  quantity numeric(24, 8) not null default 0,
  average_cost numeric(18, 4) not null default 0,
  current_price numeric(18, 4) not null default 0,
  currency char(3) not null,
  market_value numeric(18, 4) not null default 0,
  target_allocation_percent numeric(5, 2),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.tax_records (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  tax_year integer not null,
  income_type text,
  amount numeric(18, 4) not null default 0,
  deduction_type text,
  document_id uuid references public.attachments(id),
  estimate_only boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.accounting_records (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  mode text not null default 'simple',
  account_code text,
  entry_type text not null,
  amount numeric(18, 4) not null default 0,
  currency char(3) not null,
  transaction_id uuid references public.transactions(id),
  created_at timestamptz not null default now()
);

create table if not exists public.course_lessons (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  lesson_key text not null,
  title text not null,
  category text not null,
  progress_status text not null default 'notStarted',
  quiz_score numeric(5, 2),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, lesson_key)
);

create table if not exists public.device_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  device_name text not null,
  platform text not null,
  trusted boolean not null default false,
  current_device boolean not null default false,
  last_seen_at timestamptz not null default now(),
  revoked_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.trips (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  name text not null,
  home_currency char(3) not null,
  local_currency char(3) not null,
  budget_amount numeric(18, 4) not null default 0,
  starts_on date not null,
  ends_on date not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.optimization_suggestions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  suggestion_type text not null,
  title text not null,
  recommendation text not null,
  confidence_score numeric(4, 3) not null default 0.7,
  source_summary jsonb not null default '[]',
  disclaimer_types text[] not null default '{}',
  status text not null default 'new',
  created_at timestamptz not null default now(),
  dismissed_at timestamptz
);

create table if not exists public.subscription_plans (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  plan_tier text not null default 'free',
  status text not null default 'active',
  started_at timestamptz not null default now(),
  renews_at timestamptz,
  canceled_at timestamptz,
  unique (user_id)
);

create index if not exists import_jobs_user_status_idx on public.import_jobs(user_id, status);
create index if not exists bill_subscriptions_user_due_idx on public.bill_subscriptions(user_id, next_billing_date);
create index if not exists investment_holdings_user_symbol_idx on public.investment_holdings(user_id, symbol);
create index if not exists tax_records_user_year_idx on public.tax_records(user_id, tax_year);
create index if not exists optimization_suggestions_user_status_idx on public.optimization_suggestions(user_id, status);
