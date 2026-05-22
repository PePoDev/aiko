create extension if not exists pgcrypto with schema extensions;

create table if not exists public.profiles (
  id uuid primary key,
  display_name text not null default 'Aiko User',
  email text not null default '',
  base_currency char(3) not null default 'USD',
  country char(2) not null default 'US',
  timezone text not null default 'UTC',
  preferred_theme text not null default 'system',
  aiko_character_visibility text not null default 'full',
  aiko_personality_setting text not null default 'supportive',
  ai_consent_enabled boolean not null default false,
  onboarding_status text not null default 'notStarted',
  security_status text not null default 'notConfigured',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.accounts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  name text not null,
  type text not null,
  currency char(3) not null,
  opening_balance numeric(18, 4) not null default 0,
  current_balance numeric(18, 4) not null default 0,
  institution text,
  include_in_net_worth boolean not null default true,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  archived_at timestamptz
);

create table if not exists public.categories (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  name text not null,
  parent_id uuid references public.categories(id),
  type text not null,
  "group" text not null default 'custom',
  icon text not null default 'category',
  color text not null default '#3B82F6',
  budget_enabled boolean not null default true,
  is_default boolean not null default false,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  archived_at timestamptz
);

create table if not exists public.transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  account_id uuid not null references public.accounts(id),
  type text not null,
  amount numeric(18, 4) not null,
  currency char(3) not null,
  exchange_rate_to_base numeric(18, 8),
  category_id uuid references public.categories(id),
  date date not null,
  merchant text,
  note text,
  tags text[] not null default '{}',
  attachment_ids uuid[] not null default '{}',
  location_label text,
  is_recurring boolean not null default false,
  tax_flag boolean not null default false,
  status text not null default 'posted',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.transaction_splits (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  transaction_id uuid not null references public.transactions(id) on delete cascade,
  category_id uuid not null references public.categories(id),
  amount numeric(18, 4) not null,
  note text,
  tax_flag boolean not null default false
);

create table if not exists public.transaction_rules (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  rule_name text not null,
  condition_type text not null,
  condition_operator text not null default 'contains',
  condition_value text not null,
  target_category_id uuid references public.categories(id),
  target_account_id uuid references public.accounts(id),
  tags_to_apply text[] not null default '{}',
  split_template jsonb,
  mark_recurring boolean not null default false,
  priority integer not null default 100,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.budgets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  name text not null,
  category_id uuid references public.categories(id),
  account_id uuid references public.accounts(id),
  amount numeric(18, 4) not null,
  currency char(3) not null,
  period text not null default 'monthly',
  period_start date not null,
  period_end date not null,
  rollover_enabled boolean not null default false,
  alert_thresholds integer[] not null default '{50,75,90,100}',
  status text not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.goals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  name text not null,
  purpose text not null default 'custom',
  target_amount numeric(18, 4) not null,
  current_amount numeric(18, 4) not null default 0,
  currency char(3) not null,
  target_date date not null,
  linked_account_id uuid references public.accounts(id),
  priority integer not null default 1,
  success_probability numeric(5, 2),
  status text not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  completed_at timestamptz
);

create table if not exists public.saving_plans (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  goal_id uuid not null references public.goals(id) on delete cascade,
  frequency text not null,
  required_contribution numeric(18, 4) not null,
  suggested_contribution numeric(18, 4),
  forecasted_completion_date date not null,
  milestones jsonb not null default '[]',
  status text not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.dashboard_widget_preferences (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  widget_key text not null,
  is_visible boolean not null default true,
  position integer not null,
  size text not null default 'compact',
  dashboard_mode text not null default 'personal',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, dashboard_mode, widget_key)
);

create table if not exists public.aiko_insights (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  insight_type text not null,
  title text not null,
  description text not null,
  recommendation text not null,
  confidence_score numeric(4, 3) not null default 0.7,
  source_data_summary jsonb not null default '[]',
  related_entity_type text,
  related_entity_id uuid,
  status text not null default 'new',
  feedback text,
  created_at timestamptz not null default now(),
  viewed_at timestamptz,
  dismissed_at timestamptz
);

create table if not exists public.saved_calculator_scenarios (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  calculator_type text not null,
  input_json jsonb not null,
  result_json jsonb not null,
  notes text,
  converted_entity_type text,
  converted_entity_id uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.reports (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  report_type text not null,
  period_start date not null,
  period_end date not null,
  filters jsonb not null default '{}',
  summary_json jsonb not null default '{}',
  export_format text,
  status text not null default 'draft',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.attachments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  storage_bucket text not null,
  storage_path text not null,
  file_name text not null,
  content_type text not null,
  size_bytes bigint not null default 0,
  linked_entity_type text not null,
  linked_entity_id uuid,
  created_at timestamptz not null default now()
);

create table if not exists public.notification_preferences (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  notification_type text not null,
  enabled boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, notification_type)
);

create index if not exists transactions_user_date_idx on public.transactions(user_id, date desc);
create index if not exists transactions_search_idx on public.transactions(user_id, merchant, category_id);
create index if not exists budgets_user_period_idx on public.budgets(user_id, period_start, period_end);
create unique index if not exists categories_user_parent_name_idx
  on public.categories(user_id, coalesce(parent_id, '00000000-0000-0000-0000-000000000000'::uuid), lower(name));
