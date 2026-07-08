-- Squashed initial schema (replaces migrations 001..20260620100000).
-- Generated from the live final schema via pg_dump; storage buckets/policies appended.

--
-- PostgreSQL database dump
--


-- Dumped from database version 17.6
-- Dumped by pg_dump version 17.6

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: public; Type: SCHEMA; Schema: -; Owner: -
--



--
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: -
--



--
-- Name: aiko_account_summary(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.aiko_account_summary() RETURNS jsonb
    LANGUAGE sql STABLE
    SET search_path TO 'public'
    AS $$
  select jsonb_build_object(
    'net_worth', coalesce(sum(
      case when a.include_in_net_worth then
        (case when a.type in ('loan', 'liability', 'creditCard') then -1 else 1 end) * a.current_balance
      else 0 end), 0),
    'accounts', coalesce(
      jsonb_agg(jsonb_build_object(
        'name', a.name,
        'type', a.type,
        'currency', a.currency,
        'balance', a.current_balance
      ) order by a.current_balance desc),
      '[]'::jsonb)
  )
  from public.accounts a
  where a.user_id = auth.uid()
    and a.is_active;
$$;


--
-- Name: aiko_budget_status(date, date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.aiko_budget_status(start_date date, end_date date) RETURNS TABLE(name text, budget_limit numeric, spent numeric)
    LANGUAGE sql STABLE
    SET search_path TO 'public'
    AS $$
  select
    b.name,
    b.amount as budget_limit,
    coalesce((
      select sum(t.amount)
      from public.transactions t
      where t.user_id = auth.uid()
        and t.type = 'expense'
        and t.category_id = b.category_id
        and t.date >= start_date
        and t.date < (end_date + 1)
    ), 0) as spent
  from public.budgets b
  where b.user_id = auth.uid()
    and b.status = 'active'
  order by b.name
  limit 50;
$$;


--
-- Name: aiko_cashflow_summary(date, date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.aiko_cashflow_summary(start_date date, end_date date) RETURNS TABLE(income numeric, expense numeric, net numeric)
    LANGUAGE sql STABLE
    SET search_path TO 'public'
    AS $$
  select
    coalesce(sum(t.amount) filter (where t.type = 'income'), 0) as income,
    coalesce(sum(t.amount) filter (where t.type = 'expense'), 0) as expense,
    coalesce(sum(t.amount) filter (where t.type = 'income'), 0)
      - coalesce(sum(t.amount) filter (where t.type = 'expense'), 0) as net
  from public.transactions t
  where t.user_id = auth.uid()
    and t.date >= start_date
    and t.date < (end_date + 1);
$$;


--
-- Name: aiko_goal_progress(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.aiko_goal_progress() RETURNS TABLE(name text, current_amount numeric, target_amount numeric, pct numeric, target_date date)
    LANGUAGE sql STABLE
    SET search_path TO 'public'
    AS $$
  select
    g.name,
    g.current_amount,
    g.target_amount,
    case when g.target_amount > 0 then round(g.current_amount / g.target_amount, 4) else 0 end as pct,
    g.target_date
  from public.goals g
  where g.user_id = auth.uid()
    and g.status = 'active'
  order by g.priority asc, g.name
  limit 50;
$$;


--
-- Name: aiko_recent_transactions(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.aiko_recent_transactions(max_rows integer DEFAULT 20) RETURNS TABLE(tx_date date, type text, amount numeric, merchant text, category text)
    LANGUAGE sql STABLE
    SET search_path TO 'public'
    AS $$
  select
    t.date::date as tx_date,
    t.type,
    t.amount,
    t.merchant,
    coalesce(c.name, 'Uncategorized') as category
  from public.transactions t
  left join public.categories c on c.id = t.category_id
  where t.user_id = auth.uid()
  order by t.date desc
  limit greatest(1, least(coalesce(max_rows, 20), 50));
$$;


--
-- Name: aiko_spending_by_category(date, date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.aiko_spending_by_category(start_date date, end_date date) RETURNS TABLE(category text, total numeric)
    LANGUAGE sql STABLE
    SET search_path TO 'public'
    AS $$
  select
    coalesce(c.name, 'Uncategorized') as category,
    sum(t.amount) as total
  from public.transactions t
  left join public.categories c on c.id = t.category_id
  where t.user_id = auth.uid()
    and t.type = 'expense'
    and t.date >= start_date
    and t.date < (end_date + 1)
  group by coalesce(c.name, 'Uncategorized')
  order by total desc
  limit 50;
$$;


--
-- Name: delete_account(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.delete_account() RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;
  delete from public.profiles where id = uid;  -- cascades finance data
  delete from auth.users where id = uid;       -- removes the login
end;
$$;


--
-- Name: redeem_line_pairing(text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.redeem_line_pairing(p_code text, p_refresh_token text) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
declare
  v_line_user_id text;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  select line_user_id into v_line_user_id
  from public.line_pairings
  where code = p_code
    and expires_at > now();

  if v_line_user_id is null then
    return false; -- invalid or expired
  end if;

  insert into public.line_links (user_id, line_user_id, refresh_token, updated_at)
  values (auth.uid(), v_line_user_id, p_refresh_token, now())
  on conflict (line_user_id) do update
    set user_id = excluded.user_id,
        refresh_token = excluded.refresh_token,
        updated_at = now();

  -- Single-use: consume the code immediately.
  delete from public.line_pairings where line_user_id = v_line_user_id;

  return true;
end;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: accounting_records; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.accounting_records (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    mode text DEFAULT 'simple'::text NOT NULL,
    account_code text,
    entry_type text NOT NULL,
    amount numeric(18,4) DEFAULT 0 NOT NULL,
    currency character(3) NOT NULL,
    transaction_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: accounts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.accounts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    name text NOT NULL,
    type text NOT NULL,
    currency character(3) NOT NULL,
    current_balance numeric(18,4) DEFAULT 0 NOT NULL,
    institution text,
    include_in_net_worth boolean DEFAULT true NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    archived_at timestamp with time zone,
    details jsonb DEFAULT '{}'::jsonb NOT NULL,
    goal_target_amount text,
    goal_target_date date,
    goal_priority text DEFAULT 'medium'::text NOT NULL,
    version integer DEFAULT 1 NOT NULL,
    CONSTRAINT accounts_goal_priority_check CHECK ((goal_priority = ANY (ARRAY['high'::text, 'medium'::text, 'low'::text]))),
    CONSTRAINT accounts_goal_shape_check CHECK (((type <> 'goal'::text) OR ((goal_target_amount IS NOT NULL) AND (goal_target_date IS NOT NULL)))),
    CONSTRAINT accounts_type_check CHECK ((type = ANY (ARRAY['cash'::text, 'bank'::text, 'ewallet'::text, 'creditCard'::text, 'loan'::text, 'investment'::text, 'asset'::text, 'liability'::text, 'goal'::text, 'other'::text])))
);


--
-- Name: aiko_character_profiles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.aiko_character_profiles (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    visibility text DEFAULT 'full'::text NOT NULL,
    tone text DEFAULT 'supportive'::text NOT NULL,
    reduce_motion boolean DEFAULT false NOT NULL,
    hide_character_art boolean DEFAULT false NOT NULL,
    serious_warning_style text DEFAULT 'professional'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: aiko_insights; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.aiko_insights (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    insight_type text NOT NULL,
    title text NOT NULL,
    description text NOT NULL,
    recommendation text NOT NULL,
    confidence_score numeric(4,3) DEFAULT 0.7 NOT NULL,
    source_data_summary jsonb DEFAULT '[]'::jsonb NOT NULL,
    related_entity_type text,
    related_entity_id uuid,
    status text DEFAULT 'new'::text NOT NULL,
    feedback text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    viewed_at timestamp with time zone,
    dismissed_at timestamp with time zone
);


--
-- Name: assets; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.assets (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    name text NOT NULL,
    asset_class text NOT NULL,
    value numeric(18,4) DEFAULT 0 NOT NULL,
    currency character(3) NOT NULL,
    liquidity_level text DEFAULT 'medium'::text NOT NULL,
    risk_level text DEFAULT 'medium'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: attachments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.attachments (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    storage_bucket text NOT NULL,
    storage_path text NOT NULL,
    file_name text NOT NULL,
    content_type text NOT NULL,
    size_bytes bigint DEFAULT 0 NOT NULL,
    linked_entity_type text NOT NULL,
    linked_entity_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    is_sensitive boolean DEFAULT false NOT NULL,
    export_policy text DEFAULT 'include'::text NOT NULL
);


--
-- Name: backup_snapshots; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.backup_snapshots (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    status text DEFAULT 'ready'::text NOT NULL,
    snapshot_scope text DEFAULT 'full'::text NOT NULL,
    storage_path text,
    checksum text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    restored_at timestamp with time zone
);


--
-- Name: categories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.categories (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid,
    name text NOT NULL,
    parent_id uuid,
    type text NOT NULL,
    "group" text DEFAULT 'custom'::text NOT NULL,
    icon text DEFAULT 'category'::text NOT NULL,
    color text DEFAULT '#3B82F6'::text NOT NULL,
    budget_enabled boolean DEFAULT true NOT NULL,
    is_default boolean DEFAULT false NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    archived_at timestamp with time zone,
    group_id uuid,
    budget_amount text,
    budget_currency text,
    budget_period text DEFAULT 'monthly'::text NOT NULL,
    budget_rollover boolean DEFAULT false NOT NULL,
    alert_thresholds jsonb DEFAULT '[50, 75, 90, 100]'::jsonb NOT NULL,
    version integer DEFAULT 1 NOT NULL
);


--
-- Name: category_groups; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.category_groups (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid,
    name text NOT NULL,
    icon text DEFAULT 'category'::text NOT NULL,
    color text DEFAULT '#3B82F6'::text NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    version integer DEFAULT 1 NOT NULL,
    budget_amount numeric,
    budget_currency text
);


--
-- Name: course_lessons; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.course_lessons (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    lesson_key text NOT NULL,
    title text NOT NULL,
    category text NOT NULL,
    progress_status text DEFAULT 'notStarted'::text NOT NULL,
    quiz_score numeric(5,2),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: credit_card_profiles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.credit_card_profiles (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    account_id uuid,
    credit_limit numeric(18,4) DEFAULT 0 NOT NULL,
    statement_balance numeric(18,4) DEFAULT 0 NOT NULL,
    minimum_payment numeric(18,4) DEFAULT 0 NOT NULL,
    apr numeric(7,4) DEFAULT 0 NOT NULL,
    rewards_type text,
    due_day integer DEFAULT 1 NOT NULL,
    statement_day integer DEFAULT 1 NOT NULL,
    annual_fee numeric(18,4) DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: debt_loan_plans; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.debt_loan_plans (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    name text NOT NULL,
    strategy text DEFAULT 'avalanche'::text NOT NULL,
    principal_balance numeric(18,4) NOT NULL,
    interest_rate numeric(7,4) DEFAULT 0 NOT NULL,
    monthly_payment numeric(18,4) DEFAULT 0 NOT NULL,
    payoff_forecast_date date,
    interest_savings_estimate numeric(18,4),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: device_sessions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.device_sessions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    device_name text NOT NULL,
    platform text NOT NULL,
    trusted boolean DEFAULT false NOT NULL,
    current_device boolean DEFAULT false NOT NULL,
    last_seen_at timestamp with time zone DEFAULT now() NOT NULL,
    revoked_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: export_packages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.export_packages (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    scope text NOT NULL,
    format text NOT NULL,
    sensitivity_acknowledged boolean DEFAULT false NOT NULL,
    status text DEFAULT 'pending'::text NOT NULL,
    storage_path text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    expires_at timestamp with time zone
);


--
-- Name: import_jobs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.import_jobs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    source_type text NOT NULL,
    status text DEFAULT 'preview'::text NOT NULL,
    mapping_json jsonb DEFAULT '{}'::jsonb NOT NULL,
    validation_issues jsonb DEFAULT '[]'::jsonb NOT NULL,
    duplicate_count integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    completed_at timestamp with time zone
);


--
-- Name: investment_holdings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.investment_holdings (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    symbol text NOT NULL,
    asset_class text NOT NULL,
    quantity numeric(24,8) DEFAULT 0 NOT NULL,
    average_cost numeric(18,4) DEFAULT 0 NOT NULL,
    current_price numeric(18,4) DEFAULT 0 NOT NULL,
    currency character(3) NOT NULL,
    market_value numeric(18,4) DEFAULT 0 NOT NULL,
    target_allocation_percent numeric(5,2),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    version integer DEFAULT 1 NOT NULL
);


--
-- Name: line_links; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.line_links (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    line_user_id text NOT NULL,
    refresh_token text,
    display_name text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: line_pairings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.line_pairings (
    line_user_id text NOT NULL,
    code text NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: notification_preferences; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.notification_preferences (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    notification_type text NOT NULL,
    enabled boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    source_module text DEFAULT 'reports'::text NOT NULL
);


--
-- Name: optimization_suggestions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.optimization_suggestions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    suggestion_type text NOT NULL,
    title text NOT NULL,
    recommendation text NOT NULL,
    confidence_score numeric(4,3) DEFAULT 0.7 NOT NULL,
    source_summary jsonb DEFAULT '[]'::jsonb NOT NULL,
    disclaimer_types text[] DEFAULT '{}'::text[] NOT NULL,
    status text DEFAULT 'new'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    dismissed_at timestamp with time zone
);


--
-- Name: profiles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.profiles (
    id uuid NOT NULL,
    display_name text DEFAULT 'Aiko User'::text NOT NULL,
    email text DEFAULT ''::text NOT NULL,
    base_currency character(3) DEFAULT 'THB'::bpchar NOT NULL,
    country character(2) DEFAULT 'TH'::bpchar NOT NULL,
    timezone text DEFAULT 'Asia/Bangkok'::text NOT NULL,
    preferred_theme text DEFAULT 'system'::text NOT NULL,
    aiko_character_visibility text DEFAULT 'full'::text NOT NULL,
    aiko_personality_setting text DEFAULT 'supportive'::text NOT NULL,
    onboarding_status text DEFAULT 'notStarted'::text NOT NULL,
    security_status text DEFAULT 'notConfigured'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    version integer DEFAULT 1 NOT NULL,
    full_name text,
    gender text DEFAULT 'preferNotToSay'::text NOT NULL,
    date_of_birth date,
    phone_number text,
    avatar_path text,
    avatar_url text
);


--
-- Name: reports; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.reports (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    report_type text NOT NULL,
    period_start date NOT NULL,
    period_end date NOT NULL,
    filters jsonb DEFAULT '{}'::jsonb NOT NULL,
    summary_json jsonb DEFAULT '{}'::jsonb NOT NULL,
    export_format text,
    status text DEFAULT 'draft'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: saved_calculator_scenarios; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.saved_calculator_scenarios (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    calculator_type text NOT NULL,
    input_json jsonb NOT NULL,
    result_json jsonb NOT NULL,
    notes text,
    converted_entity_type text,
    converted_entity_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: subscription_plans; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.subscription_plans (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    plan_tier text DEFAULT 'free'::text NOT NULL,
    status text DEFAULT 'active'::text NOT NULL,
    started_at timestamp with time zone DEFAULT now() NOT NULL,
    renews_at timestamp with time zone,
    canceled_at timestamp with time zone
);


--
-- Name: tax_records; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tax_records (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    tax_year integer NOT NULL,
    income_type text,
    amount numeric(18,4) DEFAULT 0 NOT NULL,
    deduction_type text,
    document_id uuid,
    estimate_only boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: transaction_rules; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.transaction_rules (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    rule_name text NOT NULL,
    condition_type text NOT NULL,
    condition_operator text DEFAULT 'contains'::text NOT NULL,
    condition_value text NOT NULL,
    target_category_id uuid,
    target_account_id uuid,
    tags_to_apply text[] DEFAULT '{}'::text[] NOT NULL,
    split_template jsonb,
    mark_recurring boolean DEFAULT false NOT NULL,
    priority integer DEFAULT 100 NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: transaction_splits; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.transaction_splits (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    transaction_id uuid NOT NULL,
    category_id uuid NOT NULL,
    amount numeric(18,4) NOT NULL,
    note text,
    tax_flag boolean DEFAULT false NOT NULL
);


--
-- Name: transactions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.transactions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    account_id uuid NOT NULL,
    type text NOT NULL,
    amount numeric(18,4) NOT NULL,
    currency character(3) NOT NULL,
    exchange_rate_to_base numeric(18,8),
    category_id uuid,
    date timestamp with time zone NOT NULL,
    merchant text,
    note text,
    tags text[] DEFAULT '{}'::text[] NOT NULL,
    attachment_ids uuid[] DEFAULT '{}'::uuid[] NOT NULL,
    location_label text,
    is_recurring boolean DEFAULT false NOT NULL,
    tax_flag boolean DEFAULT false NOT NULL,
    status text DEFAULT 'posted'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    recurring_frequency text,
    recurring_end_date date,
    recurring_max_occurrences integer,
    recurring_day_of_week integer,
    recurring_day_of_month integer,
    recurring_month_of_year integer,
    version integer DEFAULT 1 NOT NULL,
    reminder_at timestamp with time zone,
    CONSTRAINT transactions_recurring_day_of_month_check CHECK (((recurring_day_of_month >= 1) AND (recurring_day_of_month <= 31))),
    CONSTRAINT transactions_recurring_day_of_week_check CHECK (((recurring_day_of_week >= 1) AND (recurring_day_of_week <= 7))),
    CONSTRAINT transactions_recurring_frequency_check CHECK (((recurring_frequency IS NULL) OR (recurring_frequency = ANY (ARRAY['once'::text, 'daily'::text, 'weekly'::text, 'monthly'::text, 'annually'::text])))),
    CONSTRAINT transactions_recurring_month_of_year_check CHECK (((recurring_month_of_year >= 1) AND (recurring_month_of_year <= 12)))
);


--
-- Name: trips; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.trips (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    name text NOT NULL,
    home_currency character(3) NOT NULL,
    local_currency character(3) NOT NULL,
    budget_amount numeric(18,4) DEFAULT 0 NOT NULL,
    starts_on date NOT NULL,
    ends_on date NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: accounting_records accounting_records_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.accounting_records
    ADD CONSTRAINT accounting_records_pkey PRIMARY KEY (id);


--
-- Name: accounts accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.accounts
    ADD CONSTRAINT accounts_pkey PRIMARY KEY (id);


--
-- Name: aiko_character_profiles aiko_character_profiles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.aiko_character_profiles
    ADD CONSTRAINT aiko_character_profiles_pkey PRIMARY KEY (id);


--
-- Name: aiko_character_profiles aiko_character_profiles_user_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.aiko_character_profiles
    ADD CONSTRAINT aiko_character_profiles_user_id_key UNIQUE (user_id);


--
-- Name: aiko_insights aiko_insights_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.aiko_insights
    ADD CONSTRAINT aiko_insights_pkey PRIMARY KEY (id);


--
-- Name: assets assets_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.assets
    ADD CONSTRAINT assets_pkey PRIMARY KEY (id);


--
-- Name: attachments attachments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.attachments
    ADD CONSTRAINT attachments_pkey PRIMARY KEY (id);


--
-- Name: backup_snapshots backup_snapshots_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.backup_snapshots
    ADD CONSTRAINT backup_snapshots_pkey PRIMARY KEY (id);


--
-- Name: categories categories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categories
    ADD CONSTRAINT categories_pkey PRIMARY KEY (id);


--
-- Name: category_groups category_groups_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.category_groups
    ADD CONSTRAINT category_groups_pkey PRIMARY KEY (id);


--
-- Name: course_lessons course_lessons_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.course_lessons
    ADD CONSTRAINT course_lessons_pkey PRIMARY KEY (id);


--
-- Name: course_lessons course_lessons_user_id_lesson_key_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.course_lessons
    ADD CONSTRAINT course_lessons_user_id_lesson_key_key UNIQUE (user_id, lesson_key);


--
-- Name: credit_card_profiles credit_card_profiles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.credit_card_profiles
    ADD CONSTRAINT credit_card_profiles_pkey PRIMARY KEY (id);


--
-- Name: debt_loan_plans debt_loan_plans_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.debt_loan_plans
    ADD CONSTRAINT debt_loan_plans_pkey PRIMARY KEY (id);


--
-- Name: device_sessions device_sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.device_sessions
    ADD CONSTRAINT device_sessions_pkey PRIMARY KEY (id);


--
-- Name: export_packages export_packages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.export_packages
    ADD CONSTRAINT export_packages_pkey PRIMARY KEY (id);


--
-- Name: import_jobs import_jobs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.import_jobs
    ADD CONSTRAINT import_jobs_pkey PRIMARY KEY (id);


--
-- Name: investment_holdings investment_holdings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.investment_holdings
    ADD CONSTRAINT investment_holdings_pkey PRIMARY KEY (id);


--
-- Name: line_links line_links_line_user_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.line_links
    ADD CONSTRAINT line_links_line_user_id_key UNIQUE (line_user_id);


--
-- Name: line_links line_links_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.line_links
    ADD CONSTRAINT line_links_pkey PRIMARY KEY (id);


--
-- Name: line_pairings line_pairings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.line_pairings
    ADD CONSTRAINT line_pairings_pkey PRIMARY KEY (line_user_id);


--
-- Name: notification_preferences notification_preferences_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notification_preferences
    ADD CONSTRAINT notification_preferences_pkey PRIMARY KEY (id);


--
-- Name: notification_preferences notification_preferences_user_id_notification_type_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notification_preferences
    ADD CONSTRAINT notification_preferences_user_id_notification_type_key UNIQUE (user_id, notification_type);


--
-- Name: optimization_suggestions optimization_suggestions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.optimization_suggestions
    ADD CONSTRAINT optimization_suggestions_pkey PRIMARY KEY (id);


--
-- Name: profiles profiles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_pkey PRIMARY KEY (id);


--
-- Name: reports reports_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reports
    ADD CONSTRAINT reports_pkey PRIMARY KEY (id);


--
-- Name: saved_calculator_scenarios saved_calculator_scenarios_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.saved_calculator_scenarios
    ADD CONSTRAINT saved_calculator_scenarios_pkey PRIMARY KEY (id);


--
-- Name: subscription_plans subscription_plans_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subscription_plans
    ADD CONSTRAINT subscription_plans_pkey PRIMARY KEY (id);


--
-- Name: subscription_plans subscription_plans_user_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subscription_plans
    ADD CONSTRAINT subscription_plans_user_id_key UNIQUE (user_id);


--
-- Name: tax_records tax_records_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tax_records
    ADD CONSTRAINT tax_records_pkey PRIMARY KEY (id);


--
-- Name: transaction_rules transaction_rules_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transaction_rules
    ADD CONSTRAINT transaction_rules_pkey PRIMARY KEY (id);


--
-- Name: transaction_splits transaction_splits_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transaction_splits
    ADD CONSTRAINT transaction_splits_pkey PRIMARY KEY (id);


--
-- Name: transactions transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transactions
    ADD CONSTRAINT transactions_pkey PRIMARY KEY (id);


--
-- Name: trips trips_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.trips
    ADD CONSTRAINT trips_pkey PRIMARY KEY (id);


--
-- Name: accounting_records_transaction_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX accounting_records_transaction_id_idx ON public.accounting_records USING btree (transaction_id);


--
-- Name: accounting_records_user_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX accounting_records_user_id_idx ON public.accounting_records USING btree (user_id);


--
-- Name: accounts_user_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX accounts_user_id_idx ON public.accounts USING btree (user_id);


--
-- Name: aiko_insights_user_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX aiko_insights_user_id_idx ON public.aiko_insights USING btree (user_id);


--
-- Name: assets_user_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX assets_user_id_idx ON public.assets USING btree (user_id);


--
-- Name: attachments_user_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX attachments_user_id_idx ON public.attachments USING btree (user_id);


--
-- Name: backup_snapshots_user_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX backup_snapshots_user_id_idx ON public.backup_snapshots USING btree (user_id);


--
-- Name: categories_group_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX categories_group_id_idx ON public.categories USING btree (group_id);


--
-- Name: categories_parent_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX categories_parent_id_idx ON public.categories USING btree (parent_id);


--
-- Name: categories_user_parent_name_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX categories_user_parent_name_idx ON public.categories USING btree (user_id, COALESCE(parent_id, '00000000-0000-0000-0000-000000000000'::uuid), lower(name));


--
-- Name: category_groups_user_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX category_groups_user_id_idx ON public.category_groups USING btree (user_id);


--
-- Name: credit_card_profiles_account_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX credit_card_profiles_account_id_idx ON public.credit_card_profiles USING btree (account_id);


--
-- Name: credit_card_profiles_user_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX credit_card_profiles_user_id_idx ON public.credit_card_profiles USING btree (user_id);


--
-- Name: debt_loan_plans_user_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX debt_loan_plans_user_id_idx ON public.debt_loan_plans USING btree (user_id);


--
-- Name: device_sessions_user_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX device_sessions_user_id_idx ON public.device_sessions USING btree (user_id);


--
-- Name: export_packages_user_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX export_packages_user_id_idx ON public.export_packages USING btree (user_id);


--
-- Name: import_jobs_user_status_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX import_jobs_user_status_idx ON public.import_jobs USING btree (user_id, status);


--
-- Name: investment_holdings_user_symbol_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX investment_holdings_user_symbol_idx ON public.investment_holdings USING btree (user_id, symbol);


--
-- Name: line_links_user_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX line_links_user_id_idx ON public.line_links USING btree (user_id);


--
-- Name: line_pairings_code_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX line_pairings_code_idx ON public.line_pairings USING btree (code);


--
-- Name: optimization_suggestions_user_status_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX optimization_suggestions_user_status_idx ON public.optimization_suggestions USING btree (user_id, status);


--
-- Name: reports_user_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX reports_user_id_idx ON public.reports USING btree (user_id);


--
-- Name: saved_calculator_scenarios_user_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX saved_calculator_scenarios_user_id_idx ON public.saved_calculator_scenarios USING btree (user_id);


--
-- Name: tax_records_document_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX tax_records_document_id_idx ON public.tax_records USING btree (document_id);


--
-- Name: tax_records_user_year_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX tax_records_user_year_idx ON public.tax_records USING btree (user_id, tax_year);


--
-- Name: transaction_rules_target_account_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX transaction_rules_target_account_id_idx ON public.transaction_rules USING btree (target_account_id);


--
-- Name: transaction_rules_target_category_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX transaction_rules_target_category_id_idx ON public.transaction_rules USING btree (target_category_id);


--
-- Name: transaction_rules_user_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX transaction_rules_user_id_idx ON public.transaction_rules USING btree (user_id);


--
-- Name: transaction_splits_category_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX transaction_splits_category_id_idx ON public.transaction_splits USING btree (category_id);


--
-- Name: transaction_splits_transaction_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX transaction_splits_transaction_id_idx ON public.transaction_splits USING btree (transaction_id);


--
-- Name: transaction_splits_user_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX transaction_splits_user_id_idx ON public.transaction_splits USING btree (user_id);


--
-- Name: transactions_account_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX transactions_account_id_idx ON public.transactions USING btree (account_id);


--
-- Name: transactions_category_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX transactions_category_id_idx ON public.transactions USING btree (category_id);


--
-- Name: transactions_search_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX transactions_search_idx ON public.transactions USING btree (user_id, merchant, category_id);


--
-- Name: transactions_user_date_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX transactions_user_date_idx ON public.transactions USING btree (user_id, date DESC);


--
-- Name: trips_user_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX trips_user_id_idx ON public.trips USING btree (user_id);


--
-- Name: accounting_records accounting_records_transaction_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.accounting_records
    ADD CONSTRAINT accounting_records_transaction_id_fkey FOREIGN KEY (transaction_id) REFERENCES public.transactions(id);


--
-- Name: accounting_records accounting_records_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.accounting_records
    ADD CONSTRAINT accounting_records_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: accounts accounts_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.accounts
    ADD CONSTRAINT accounts_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: aiko_character_profiles aiko_character_profiles_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.aiko_character_profiles
    ADD CONSTRAINT aiko_character_profiles_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: aiko_insights aiko_insights_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.aiko_insights
    ADD CONSTRAINT aiko_insights_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: assets assets_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.assets
    ADD CONSTRAINT assets_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: attachments attachments_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.attachments
    ADD CONSTRAINT attachments_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: backup_snapshots backup_snapshots_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.backup_snapshots
    ADD CONSTRAINT backup_snapshots_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: categories categories_group_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categories
    ADD CONSTRAINT categories_group_id_fkey FOREIGN KEY (group_id) REFERENCES public.category_groups(id) ON DELETE SET NULL;


--
-- Name: categories categories_parent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categories
    ADD CONSTRAINT categories_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES public.categories(id);


--
-- Name: categories categories_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categories
    ADD CONSTRAINT categories_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: category_groups category_groups_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.category_groups
    ADD CONSTRAINT category_groups_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: course_lessons course_lessons_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.course_lessons
    ADD CONSTRAINT course_lessons_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: credit_card_profiles credit_card_profiles_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.credit_card_profiles
    ADD CONSTRAINT credit_card_profiles_account_id_fkey FOREIGN KEY (account_id) REFERENCES public.accounts(id) ON DELETE CASCADE;


--
-- Name: credit_card_profiles credit_card_profiles_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.credit_card_profiles
    ADD CONSTRAINT credit_card_profiles_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: debt_loan_plans debt_loan_plans_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.debt_loan_plans
    ADD CONSTRAINT debt_loan_plans_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: device_sessions device_sessions_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.device_sessions
    ADD CONSTRAINT device_sessions_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: export_packages export_packages_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.export_packages
    ADD CONSTRAINT export_packages_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: import_jobs import_jobs_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.import_jobs
    ADD CONSTRAINT import_jobs_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: investment_holdings investment_holdings_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.investment_holdings
    ADD CONSTRAINT investment_holdings_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: line_links line_links_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.line_links
    ADD CONSTRAINT line_links_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: notification_preferences notification_preferences_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notification_preferences
    ADD CONSTRAINT notification_preferences_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: optimization_suggestions optimization_suggestions_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.optimization_suggestions
    ADD CONSTRAINT optimization_suggestions_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: reports reports_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reports
    ADD CONSTRAINT reports_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: saved_calculator_scenarios saved_calculator_scenarios_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.saved_calculator_scenarios
    ADD CONSTRAINT saved_calculator_scenarios_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: subscription_plans subscription_plans_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subscription_plans
    ADD CONSTRAINT subscription_plans_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: tax_records tax_records_document_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tax_records
    ADD CONSTRAINT tax_records_document_id_fkey FOREIGN KEY (document_id) REFERENCES public.attachments(id);


--
-- Name: tax_records tax_records_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tax_records
    ADD CONSTRAINT tax_records_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: transaction_rules transaction_rules_target_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transaction_rules
    ADD CONSTRAINT transaction_rules_target_account_id_fkey FOREIGN KEY (target_account_id) REFERENCES public.accounts(id);


--
-- Name: transaction_rules transaction_rules_target_category_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transaction_rules
    ADD CONSTRAINT transaction_rules_target_category_id_fkey FOREIGN KEY (target_category_id) REFERENCES public.categories(id);


--
-- Name: transaction_rules transaction_rules_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transaction_rules
    ADD CONSTRAINT transaction_rules_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: transaction_splits transaction_splits_category_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transaction_splits
    ADD CONSTRAINT transaction_splits_category_id_fkey FOREIGN KEY (category_id) REFERENCES public.categories(id);


--
-- Name: transaction_splits transaction_splits_transaction_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transaction_splits
    ADD CONSTRAINT transaction_splits_transaction_id_fkey FOREIGN KEY (transaction_id) REFERENCES public.transactions(id) ON DELETE CASCADE;


--
-- Name: transaction_splits transaction_splits_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transaction_splits
    ADD CONSTRAINT transaction_splits_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: transactions transactions_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transactions
    ADD CONSTRAINT transactions_account_id_fkey FOREIGN KEY (account_id) REFERENCES public.accounts(id);


--
-- Name: transactions transactions_category_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transactions
    ADD CONSTRAINT transactions_category_id_fkey FOREIGN KEY (category_id) REFERENCES public.categories(id);


--
-- Name: transactions transactions_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transactions
    ADD CONSTRAINT transactions_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: trips trips_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.trips
    ADD CONSTRAINT trips_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: accounting_records Users manage own accounting records; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users manage own accounting records" ON public.accounting_records TO authenticated USING ((( SELECT auth.uid() AS uid) = user_id)) WITH CHECK ((( SELECT auth.uid() AS uid) = user_id));


--
-- Name: aiko_character_profiles Users manage own aiko character profiles; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users manage own aiko character profiles" ON public.aiko_character_profiles TO authenticated USING ((( SELECT auth.uid() AS uid) = user_id)) WITH CHECK ((( SELECT auth.uid() AS uid) = user_id));


--
-- Name: assets Users manage own assets; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users manage own assets" ON public.assets TO authenticated USING ((( SELECT auth.uid() AS uid) = user_id)) WITH CHECK ((( SELECT auth.uid() AS uid) = user_id));


--
-- Name: backup_snapshots Users manage own backup snapshots; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users manage own backup snapshots" ON public.backup_snapshots TO authenticated USING ((( SELECT auth.uid() AS uid) = user_id)) WITH CHECK ((( SELECT auth.uid() AS uid) = user_id));


--
-- Name: course_lessons Users manage own course lessons; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users manage own course lessons" ON public.course_lessons TO authenticated USING ((( SELECT auth.uid() AS uid) = user_id)) WITH CHECK ((( SELECT auth.uid() AS uid) = user_id));


--
-- Name: credit_card_profiles Users manage own credit card profiles; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users manage own credit card profiles" ON public.credit_card_profiles TO authenticated USING ((( SELECT auth.uid() AS uid) = user_id)) WITH CHECK ((( SELECT auth.uid() AS uid) = user_id));


--
-- Name: debt_loan_plans Users manage own debt loan plans; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users manage own debt loan plans" ON public.debt_loan_plans TO authenticated USING ((( SELECT auth.uid() AS uid) = user_id)) WITH CHECK ((( SELECT auth.uid() AS uid) = user_id));


--
-- Name: device_sessions Users manage own device sessions; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users manage own device sessions" ON public.device_sessions TO authenticated USING ((( SELECT auth.uid() AS uid) = user_id)) WITH CHECK ((( SELECT auth.uid() AS uid) = user_id));


--
-- Name: export_packages Users manage own export packages; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users manage own export packages" ON public.export_packages TO authenticated USING ((( SELECT auth.uid() AS uid) = user_id)) WITH CHECK ((( SELECT auth.uid() AS uid) = user_id));


--
-- Name: import_jobs Users manage own import jobs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users manage own import jobs" ON public.import_jobs TO authenticated USING ((( SELECT auth.uid() AS uid) = user_id)) WITH CHECK ((( SELECT auth.uid() AS uid) = user_id));


--
-- Name: investment_holdings Users manage own investment holdings; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users manage own investment holdings" ON public.investment_holdings TO authenticated USING ((( SELECT auth.uid() AS uid) = user_id)) WITH CHECK ((( SELECT auth.uid() AS uid) = user_id));


--
-- Name: optimization_suggestions Users manage own optimization suggestions; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users manage own optimization suggestions" ON public.optimization_suggestions TO authenticated USING ((( SELECT auth.uid() AS uid) = user_id)) WITH CHECK ((( SELECT auth.uid() AS uid) = user_id));


--
-- Name: subscription_plans Users manage own subscription plans; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users manage own subscription plans" ON public.subscription_plans TO authenticated USING ((( SELECT auth.uid() AS uid) = user_id)) WITH CHECK ((( SELECT auth.uid() AS uid) = user_id));


--
-- Name: tax_records Users manage own tax records; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users manage own tax records" ON public.tax_records TO authenticated USING ((( SELECT auth.uid() AS uid) = user_id)) WITH CHECK ((( SELECT auth.uid() AS uid) = user_id));


--
-- Name: trips Users manage own trips; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users manage own trips" ON public.trips TO authenticated USING ((( SELECT auth.uid() AS uid) = user_id)) WITH CHECK ((( SELECT auth.uid() AS uid) = user_id));


--
-- Name: accounting_records; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.accounting_records ENABLE ROW LEVEL SECURITY;

--
-- Name: accounts; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.accounts ENABLE ROW LEVEL SECURITY;

--
-- Name: accounts accounts own rows; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "accounts own rows" ON public.accounts TO authenticated USING ((user_id = ( SELECT auth.uid() AS uid))) WITH CHECK ((user_id = ( SELECT auth.uid() AS uid)));


--
-- Name: aiko_character_profiles; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.aiko_character_profiles ENABLE ROW LEVEL SECURITY;

--
-- Name: aiko_insights; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.aiko_insights ENABLE ROW LEVEL SECURITY;

--
-- Name: aiko_insights aiko_insights own rows; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "aiko_insights own rows" ON public.aiko_insights TO authenticated USING ((user_id = ( SELECT auth.uid() AS uid))) WITH CHECK ((user_id = ( SELECT auth.uid() AS uid)));


--
-- Name: assets; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.assets ENABLE ROW LEVEL SECURITY;

--
-- Name: attachments; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.attachments ENABLE ROW LEVEL SECURITY;

--
-- Name: attachments attachments own rows; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "attachments own rows" ON public.attachments TO authenticated USING ((user_id = ( SELECT auth.uid() AS uid))) WITH CHECK ((user_id = ( SELECT auth.uid() AS uid)));


--
-- Name: backup_snapshots; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.backup_snapshots ENABLE ROW LEVEL SECURITY;

--
-- Name: categories; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;

--
-- Name: categories categories delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "categories delete" ON public.categories FOR DELETE TO authenticated USING ((user_id = ( SELECT auth.uid() AS uid)));


--
-- Name: categories categories insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "categories insert" ON public.categories FOR INSERT TO authenticated WITH CHECK ((user_id = ( SELECT auth.uid() AS uid)));


--
-- Name: categories categories select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "categories select" ON public.categories FOR SELECT TO authenticated USING (((user_id IS NULL) OR (user_id = ( SELECT auth.uid() AS uid))));


--
-- Name: categories categories update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "categories update" ON public.categories FOR UPDATE TO authenticated USING ((user_id = ( SELECT auth.uid() AS uid))) WITH CHECK ((user_id = ( SELECT auth.uid() AS uid)));


--
-- Name: category_groups; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.category_groups ENABLE ROW LEVEL SECURITY;

--
-- Name: category_groups category_groups delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "category_groups delete" ON public.category_groups FOR DELETE TO authenticated USING ((user_id = ( SELECT auth.uid() AS uid)));


--
-- Name: category_groups category_groups insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "category_groups insert" ON public.category_groups FOR INSERT TO authenticated WITH CHECK ((user_id = ( SELECT auth.uid() AS uid)));


--
-- Name: category_groups category_groups select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "category_groups select" ON public.category_groups FOR SELECT TO authenticated USING (((user_id IS NULL) OR (user_id = ( SELECT auth.uid() AS uid))));


--
-- Name: category_groups category_groups update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "category_groups update" ON public.category_groups FOR UPDATE TO authenticated USING ((user_id = ( SELECT auth.uid() AS uid))) WITH CHECK ((user_id = ( SELECT auth.uid() AS uid)));


--
-- Name: course_lessons; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.course_lessons ENABLE ROW LEVEL SECURITY;

--
-- Name: credit_card_profiles; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.credit_card_profiles ENABLE ROW LEVEL SECURITY;

--
-- Name: debt_loan_plans; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.debt_loan_plans ENABLE ROW LEVEL SECURITY;

--
-- Name: device_sessions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.device_sessions ENABLE ROW LEVEL SECURITY;

--
-- Name: export_packages; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.export_packages ENABLE ROW LEVEL SECURITY;

--
-- Name: import_jobs; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.import_jobs ENABLE ROW LEVEL SECURITY;

--
-- Name: investment_holdings; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.investment_holdings ENABLE ROW LEVEL SECURITY;

--
-- Name: line_links; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.line_links ENABLE ROW LEVEL SECURITY;

--
-- Name: line_links line_links own rows; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "line_links own rows" ON public.line_links TO authenticated USING ((user_id = ( SELECT auth.uid() AS uid))) WITH CHECK ((user_id = ( SELECT auth.uid() AS uid)));


--
-- Name: line_pairings; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.line_pairings ENABLE ROW LEVEL SECURITY;

--
-- Name: notification_preferences; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.notification_preferences ENABLE ROW LEVEL SECURITY;

--
-- Name: notification_preferences notification_preferences own rows; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "notification_preferences own rows" ON public.notification_preferences TO authenticated USING ((user_id = ( SELECT auth.uid() AS uid))) WITH CHECK ((user_id = ( SELECT auth.uid() AS uid)));


--
-- Name: optimization_suggestions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.optimization_suggestions ENABLE ROW LEVEL SECURITY;

--
-- Name: profiles; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

--
-- Name: profiles profiles own rows; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "profiles own rows" ON public.profiles TO authenticated USING ((id = ( SELECT auth.uid() AS uid))) WITH CHECK ((id = ( SELECT auth.uid() AS uid)));


--
-- Name: reports; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;

--
-- Name: reports reports own rows; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "reports own rows" ON public.reports TO authenticated USING ((user_id = ( SELECT auth.uid() AS uid))) WITH CHECK ((user_id = ( SELECT auth.uid() AS uid)));


--
-- Name: saved_calculator_scenarios; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.saved_calculator_scenarios ENABLE ROW LEVEL SECURITY;

--
-- Name: saved_calculator_scenarios saved_calculator_scenarios own rows; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "saved_calculator_scenarios own rows" ON public.saved_calculator_scenarios TO authenticated USING ((user_id = ( SELECT auth.uid() AS uid))) WITH CHECK ((user_id = ( SELECT auth.uid() AS uid)));


--
-- Name: subscription_plans; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.subscription_plans ENABLE ROW LEVEL SECURITY;

--
-- Name: tax_records; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.tax_records ENABLE ROW LEVEL SECURITY;

--
-- Name: transaction_rules; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.transaction_rules ENABLE ROW LEVEL SECURITY;

--
-- Name: transaction_rules transaction_rules own rows; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "transaction_rules own rows" ON public.transaction_rules TO authenticated USING ((user_id = ( SELECT auth.uid() AS uid))) WITH CHECK ((user_id = ( SELECT auth.uid() AS uid)));


--
-- Name: transaction_splits; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.transaction_splits ENABLE ROW LEVEL SECURITY;

--
-- Name: transaction_splits transaction_splits own rows; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "transaction_splits own rows" ON public.transaction_splits TO authenticated USING ((user_id = ( SELECT auth.uid() AS uid))) WITH CHECK ((user_id = ( SELECT auth.uid() AS uid)));


--
-- Name: transactions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;

--
-- Name: transactions transactions own rows; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "transactions own rows" ON public.transactions TO authenticated USING ((user_id = ( SELECT auth.uid() AS uid))) WITH CHECK ((user_id = ( SELECT auth.uid() AS uid)));


--
-- Name: trips; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.trips ENABLE ROW LEVEL SECURITY;

--
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: -
--

GRANT USAGE ON SCHEMA public TO postgres;
GRANT USAGE ON SCHEMA public TO anon;
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT USAGE ON SCHEMA public TO service_role;


--
-- Name: FUNCTION aiko_account_summary(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.aiko_account_summary() FROM PUBLIC;
GRANT ALL ON FUNCTION public.aiko_account_summary() TO authenticated;
GRANT ALL ON FUNCTION public.aiko_account_summary() TO service_role;


--
-- Name: FUNCTION aiko_budget_status(start_date date, end_date date); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.aiko_budget_status(start_date date, end_date date) FROM PUBLIC;
GRANT ALL ON FUNCTION public.aiko_budget_status(start_date date, end_date date) TO authenticated;
GRANT ALL ON FUNCTION public.aiko_budget_status(start_date date, end_date date) TO service_role;


--
-- Name: FUNCTION aiko_cashflow_summary(start_date date, end_date date); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.aiko_cashflow_summary(start_date date, end_date date) FROM PUBLIC;
GRANT ALL ON FUNCTION public.aiko_cashflow_summary(start_date date, end_date date) TO authenticated;
GRANT ALL ON FUNCTION public.aiko_cashflow_summary(start_date date, end_date date) TO service_role;


--
-- Name: FUNCTION aiko_goal_progress(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.aiko_goal_progress() FROM PUBLIC;
GRANT ALL ON FUNCTION public.aiko_goal_progress() TO authenticated;
GRANT ALL ON FUNCTION public.aiko_goal_progress() TO service_role;


--
-- Name: FUNCTION aiko_recent_transactions(max_rows integer); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.aiko_recent_transactions(max_rows integer) FROM PUBLIC;
GRANT ALL ON FUNCTION public.aiko_recent_transactions(max_rows integer) TO authenticated;
GRANT ALL ON FUNCTION public.aiko_recent_transactions(max_rows integer) TO service_role;


--
-- Name: FUNCTION aiko_spending_by_category(start_date date, end_date date); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.aiko_spending_by_category(start_date date, end_date date) FROM PUBLIC;
GRANT ALL ON FUNCTION public.aiko_spending_by_category(start_date date, end_date date) TO authenticated;
GRANT ALL ON FUNCTION public.aiko_spending_by_category(start_date date, end_date date) TO service_role;


--
-- Name: FUNCTION delete_account(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.delete_account() FROM PUBLIC;
GRANT ALL ON FUNCTION public.delete_account() TO authenticated;
GRANT ALL ON FUNCTION public.delete_account() TO service_role;


--
-- Name: FUNCTION redeem_line_pairing(p_code text, p_refresh_token text); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.redeem_line_pairing(p_code text, p_refresh_token text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.redeem_line_pairing(p_code text, p_refresh_token text) TO authenticated;
GRANT ALL ON FUNCTION public.redeem_line_pairing(p_code text, p_refresh_token text) TO service_role;


--
-- Name: TABLE accounting_records; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.accounting_records TO anon;
GRANT ALL ON TABLE public.accounting_records TO authenticated;
GRANT ALL ON TABLE public.accounting_records TO service_role;


--
-- Name: TABLE accounts; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.accounts TO anon;
GRANT ALL ON TABLE public.accounts TO authenticated;
GRANT ALL ON TABLE public.accounts TO service_role;


--
-- Name: TABLE aiko_character_profiles; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.aiko_character_profiles TO anon;
GRANT ALL ON TABLE public.aiko_character_profiles TO authenticated;
GRANT ALL ON TABLE public.aiko_character_profiles TO service_role;


--
-- Name: TABLE aiko_insights; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.aiko_insights TO anon;
GRANT ALL ON TABLE public.aiko_insights TO authenticated;
GRANT ALL ON TABLE public.aiko_insights TO service_role;


--
-- Name: TABLE assets; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.assets TO anon;
GRANT ALL ON TABLE public.assets TO authenticated;
GRANT ALL ON TABLE public.assets TO service_role;


--
-- Name: TABLE attachments; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.attachments TO anon;
GRANT ALL ON TABLE public.attachments TO authenticated;
GRANT ALL ON TABLE public.attachments TO service_role;


--
-- Name: TABLE backup_snapshots; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.backup_snapshots TO anon;
GRANT ALL ON TABLE public.backup_snapshots TO authenticated;
GRANT ALL ON TABLE public.backup_snapshots TO service_role;


--
-- Name: TABLE categories; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.categories TO anon;
GRANT ALL ON TABLE public.categories TO authenticated;
GRANT ALL ON TABLE public.categories TO service_role;


--
-- Name: TABLE category_groups; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.category_groups TO anon;
GRANT ALL ON TABLE public.category_groups TO authenticated;
GRANT ALL ON TABLE public.category_groups TO service_role;


--
-- Name: TABLE course_lessons; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.course_lessons TO anon;
GRANT ALL ON TABLE public.course_lessons TO authenticated;
GRANT ALL ON TABLE public.course_lessons TO service_role;


--
-- Name: TABLE credit_card_profiles; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.credit_card_profiles TO anon;
GRANT ALL ON TABLE public.credit_card_profiles TO authenticated;
GRANT ALL ON TABLE public.credit_card_profiles TO service_role;


--
-- Name: TABLE debt_loan_plans; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.debt_loan_plans TO anon;
GRANT ALL ON TABLE public.debt_loan_plans TO authenticated;
GRANT ALL ON TABLE public.debt_loan_plans TO service_role;


--
-- Name: TABLE device_sessions; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.device_sessions TO anon;
GRANT ALL ON TABLE public.device_sessions TO authenticated;
GRANT ALL ON TABLE public.device_sessions TO service_role;


--
-- Name: TABLE export_packages; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.export_packages TO anon;
GRANT ALL ON TABLE public.export_packages TO authenticated;
GRANT ALL ON TABLE public.export_packages TO service_role;


--
-- Name: TABLE import_jobs; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.import_jobs TO anon;
GRANT ALL ON TABLE public.import_jobs TO authenticated;
GRANT ALL ON TABLE public.import_jobs TO service_role;


--
-- Name: TABLE investment_holdings; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.investment_holdings TO anon;
GRANT ALL ON TABLE public.investment_holdings TO authenticated;
GRANT ALL ON TABLE public.investment_holdings TO service_role;


--
-- Name: TABLE line_links; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.line_links TO anon;
GRANT ALL ON TABLE public.line_links TO authenticated;
GRANT ALL ON TABLE public.line_links TO service_role;


--
-- Name: TABLE line_pairings; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.line_pairings TO anon;
GRANT ALL ON TABLE public.line_pairings TO authenticated;
GRANT ALL ON TABLE public.line_pairings TO service_role;


--
-- Name: TABLE notification_preferences; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.notification_preferences TO anon;
GRANT ALL ON TABLE public.notification_preferences TO authenticated;
GRANT ALL ON TABLE public.notification_preferences TO service_role;


--
-- Name: TABLE optimization_suggestions; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.optimization_suggestions TO anon;
GRANT ALL ON TABLE public.optimization_suggestions TO authenticated;
GRANT ALL ON TABLE public.optimization_suggestions TO service_role;


--
-- Name: TABLE profiles; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.profiles TO anon;
GRANT ALL ON TABLE public.profiles TO authenticated;
GRANT ALL ON TABLE public.profiles TO service_role;


--
-- Name: TABLE reports; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.reports TO anon;
GRANT ALL ON TABLE public.reports TO authenticated;
GRANT ALL ON TABLE public.reports TO service_role;


--
-- Name: TABLE saved_calculator_scenarios; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.saved_calculator_scenarios TO anon;
GRANT ALL ON TABLE public.saved_calculator_scenarios TO authenticated;
GRANT ALL ON TABLE public.saved_calculator_scenarios TO service_role;


--
-- Name: TABLE subscription_plans; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.subscription_plans TO anon;
GRANT ALL ON TABLE public.subscription_plans TO authenticated;
GRANT ALL ON TABLE public.subscription_plans TO service_role;


--
-- Name: TABLE tax_records; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.tax_records TO anon;
GRANT ALL ON TABLE public.tax_records TO authenticated;
GRANT ALL ON TABLE public.tax_records TO service_role;


--
-- Name: TABLE transaction_rules; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.transaction_rules TO anon;
GRANT ALL ON TABLE public.transaction_rules TO authenticated;
GRANT ALL ON TABLE public.transaction_rules TO service_role;


--
-- Name: TABLE transaction_splits; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.transaction_splits TO anon;
GRANT ALL ON TABLE public.transaction_splits TO authenticated;
GRANT ALL ON TABLE public.transaction_splits TO service_role;


--
-- Name: TABLE transactions; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.transactions TO anon;
GRANT ALL ON TABLE public.transactions TO authenticated;
GRANT ALL ON TABLE public.transactions TO service_role;


--
-- Name: TABLE trips; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.trips TO anon;
GRANT ALL ON TABLE public.trips TO authenticated;
GRANT ALL ON TABLE public.trips TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: public; Owner: -
--



--
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: public; Owner: -
--



--
-- Name: DEFAULT PRIVILEGES FOR FUNCTIONS; Type: DEFAULT ACL; Schema: public; Owner: -
--



--
-- Name: DEFAULT PRIVILEGES FOR FUNCTIONS; Type: DEFAULT ACL; Schema: public; Owner: -
--



--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: public; Owner: -
--



--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: public; Owner: -
--



--
-- PostgreSQL database dump complete
--



--
-- Storage: buckets + object policies
--

insert into storage.buckets (id, name, public)
values
  ('receipts', 'receipts', false),
  ('documents', 'documents', false),
  ('exports', 'exports', false),
  ('public-web', 'public-web', true),
  ('avatars', 'avatars', true)
on conflict (id) do nothing;

CREATE POLICY "avatars are publicly readable" ON storage.objects FOR SELECT USING ((bucket_id = 'avatars'::text));
CREATE POLICY "users delete own storage objects" ON storage.objects FOR DELETE TO authenticated USING (((bucket_id = ANY (ARRAY['receipts'::text, 'documents'::text, 'exports'::text])) AND ((storage.foldername(name))[1] = (auth.uid())::text)));
CREATE POLICY "users delete their own avatar" ON storage.objects FOR DELETE TO authenticated USING (((bucket_id = 'avatars'::text) AND ((storage.foldername(name))[1] = (auth.uid())::text)));
CREATE POLICY "users insert own storage objects" ON storage.objects FOR INSERT TO authenticated WITH CHECK (((bucket_id = ANY (ARRAY['receipts'::text, 'documents'::text, 'exports'::text])) AND ((storage.foldername(name))[1] = (auth.uid())::text)));
CREATE POLICY "users read own storage objects" ON storage.objects FOR SELECT TO authenticated USING (((bucket_id = ANY (ARRAY['receipts'::text, 'documents'::text, 'exports'::text])) AND ((storage.foldername(name))[1] = (auth.uid())::text)));
CREATE POLICY "users update own storage objects" ON storage.objects FOR UPDATE TO authenticated USING (((bucket_id = ANY (ARRAY['receipts'::text, 'documents'::text, 'exports'::text])) AND ((storage.foldername(name))[1] = (auth.uid())::text))) WITH CHECK (((bucket_id = ANY (ARRAY['receipts'::text, 'documents'::text, 'exports'::text])) AND ((storage.foldername(name))[1] = (auth.uid())::text)));
CREATE POLICY "users update their own avatar" ON storage.objects FOR UPDATE TO authenticated USING (((bucket_id = 'avatars'::text) AND ((storage.foldername(name))[1] = (auth.uid())::text))) WITH CHECK (((bucket_id = 'avatars'::text) AND ((storage.foldername(name))[1] = (auth.uid())::text)));
CREATE POLICY "users upload their own avatar" ON storage.objects FOR INSERT TO authenticated WITH CHECK (((bucket_id = 'avatars'::text) AND ((storage.foldername(name))[1] = (auth.uid())::text)));

--
-- Self-hosted default privileges grant execute to anon at function-creation
-- time; these RPCs are for signed-in users only (matches original migrations).
--
REVOKE ALL ON FUNCTION public.aiko_account_summary() FROM anon;
REVOKE ALL ON FUNCTION public.aiko_budget_status(start_date date, end_date date) FROM anon;
REVOKE ALL ON FUNCTION public.aiko_cashflow_summary(start_date date, end_date date) FROM anon;
REVOKE ALL ON FUNCTION public.aiko_goal_progress() FROM anon;
REVOKE ALL ON FUNCTION public.aiko_recent_transactions(max_rows integer) FROM anon;
REVOKE ALL ON FUNCTION public.aiko_spending_by_category(start_date date, end_date date) FROM anon;
REVOKE ALL ON FUNCTION public.delete_account() FROM anon;
REVOKE ALL ON FUNCTION public.redeem_line_pairing(p_code text, p_refresh_token text) FROM anon;
