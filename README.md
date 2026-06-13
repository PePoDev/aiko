# Aiko — Personal Finance Management App

<p align="center">
  <strong>AI-powered personal finance, guided by Aiko.</strong><br/>
  Track money · Budget · Save · Invest · Plan — with a friendly AI companion.
</p>

> This README is the single canonical source of truth for both human contributors
> and coding agents. It covers product scope, the visual design system, and
> implementation rules. If screen code, product behavior, or UI appearance
> conflicts with this file, update the code (or surface the conflict) unless this
> file is wrong.

---

## What Is Aiko?

Aiko is a cross-platform personal finance app for iOS and Android, built with Flutter and powered by Supabase Cloud. At its core is **Aiko** — a cute, anime-style AI assistant with blue hair who helps users understand their money, build wealth, and reach financial goals through friendly, non-judgmental guidance.

Aiko is a calm, data-first personal finance app. The UI makes money, risk, progress, and next actions easy to scan before it adds personality. Aiko, the assistant character, appears only where warmth or explanation helps a user decide.

Aiko is not just an expense tracker. It's a **personal financial operating system** combining:

- **Daily money tracking** with 13 transaction types
- **Smart budgeting** (envelope, zero-based, 50/30/20)
- **SMART financial goals** with saving plans and success probability
- **Cash flow analysis** and spending pace monitoring
- **Credit card, debt, and loan management** with payoff strategies
- **Portfolio tracking** and asset allocation
- **Tax organization** and analytics
- **60+ financial calculators** covering loans, retirement, investments, and more
- **AI-driven insights** and personalized recommendations
- **Ask Aiko** — a natural-language chat assistant for financial questions
- **Monthly Aiko Review** — a comprehensive financial health summary
- **PFM Learning Hub** — courses, lessons, and quizzes
- **Travel Mode** — multi-currency tracking with live exchange rates

---

## Brand Identity & Voice

- **App Name:** Aiko (financial companion avatar: blue-haired, supportive, smart, calm, non-judgmental).
- **Brand Voice:** Warm, clear, positive reinforcement, solution-oriented — never shame-based.
- **Primary Color:** Blue (`#3B82F6`) representing trust and stability.
- **Color System:** Primary blue (`#3B82F6` | Deep `#1D4ED8` | Soft `#93C5FD` | Pale `#EFF6FF`). Semantic: Success Green (savings, income), Warning Orange (bills, limits), Danger Red (overspending), Purple (Premium/AI), Teal (analytics, portfolio).
- **Character Principle:** *Data first, Aiko enhanced.* The character guides onboarding, dashboard greetings, monthly reviews, and insights without obscuring critical data or charts.

### Product Register

Aiko is product UI, not a marketing site. It should feel trustworthy, native, repeatable, and efficient for daily finance work. Use familiar app patterns, dense but readable hierarchy, consistent components, explanatory motion, and AI warmth only when it clarifies, reassures, or guides a decision.

Avoid decorative gradients, glassmorphism, ornamental cards, nested cards, oversized task-screen heroes, meaningless purple/blue accents, and Aiko artwork covering numbers, charts, forms, or actions. Category forms do not control budget inclusion; budget forms own it.

### Voice

Tone is clear, supportive, specific, and non-judgmental.

- Use: "Groceries are pacing high. Lower flexible spending by $18 this week to stay on track."
- Avoid: "You overspent again."

### Design Tenets

1. Data first, Aiko enhanced.
2. One primary action per screen region.
3. Every financial number needs context: period, account, category, target, or status.
4. Lists are compact by default; detail screens can breathe.
5. Cards represent real objects, metrics, or grouped tasks.
6. Forms disclose advanced controls only when the feature owns that choice.
7. Empty states teach the next action; errors explain recovery.
8. Dark mode is first-class.
9. Every tappable control has a 48px minimum touch target.

---

## Design Ideas

The May 31, 2026 reference idea boards are implemented as in-app flows and supplemental detail states. They guide layout density, screen hierarchy, icon coverage, and Aiko placement. They are coverage targets, not a separate theme — existing feature screens remain the source of truth, and idea-specific states are integrated as subroutes, menu tools, or inline actions to avoid duplicated screens. See [Route and Idea Coverage](#route-and-idea-coverage) for the route map.

| Idea | Coverage |
| --- | --- |
| Idea 1 | Core app screens: splash, onboarding, login, dashboard, notifications, accounts, safe-to-spend, customization |
| Idea 2 | Transactions, transaction detail, add/split transaction, receipt review, search filters, categories, account detail |
| Idea 3 | Budget, pace, safe-to-spend, goals, saving plans, cash flow, Sankey, reports, monthly report |
| Idea 4 | Credit cards, debt payoff, loans, net worth, assets, portfolio, allocation, tax center, tax analytics |
| Idea 5 | Ask Aiko, Aiko insights/review/optimize, calculators, learning hub, travel mode, settings, profile security |

Product rule: when an idea board overlaps an existing feature, improve the existing flow instead of creating a parallel screen.

### Idea Boards

![Idea 1 core app screens](screenshots/idea-1.png)

![Idea 2 transactions categories and accounts](screenshots/idea-2.png)

![Idea 3 budget goals cash flow and reports](screenshots/idea-3.png)

![Idea 4 credit debt portfolio and tax](screenshots/idea-4.png)

![Idea 5 Aiko AI calculators settings and extras](screenshots/idea-5.png)

---

## Tech Stack

| Component | Technology |
| --- | --- |
| Mobile App | Flutter & Dart (SDK ^3.11.5) |
| State Management | Riverpod |
| Navigation | GoRouter |
| Backend | Supabase Cloud (Auth, Postgres, Storage, RLS) |
| Offline Store | Brick offline-first with SQLite (`sqflite`) |
| Sync | Brick request queue to Supabase after local writes |
| Money Arithmetic | `decimal` (no floating-point errors) |
| Charts | `fl_chart` |
| Security | `flutter_secure_storage`, `local_auth` (PIN + biometric) |
| IDs | `uuid` |
| Data Export | `csv`, `share_plus`, `path_provider` |
| Formatting | `intl` (locale-aware) |

---

## Getting Started

### Prerequisites

- [Flutter](https://flutter.dev/docs/get-started/install) (stable channel, SDK ^3.11.5)
- A [Supabase Cloud](https://supabase.com/) project (free tier works for development)
- [Supabase CLI](https://supabase.com/docs/guides/cli) (for database migrations)
- Android Studio / Xcode for device emulators

### 1. Clone and Install Dependencies

```bash
git clone <repository-url>
cd aiko
flutter pub get
```

Generate Brick adapters and SQLite migrations whenever offline models change:

```bash
dart run build_runner build
```

### 2. Configure Environment

Copy the example env file and fill in your Supabase credentials:

```bash
cp .env.example .env
```

Edit `.env`:

```sh
SUPABASE_URL=https://your-project-ref.supabase.co
SUPABASE_ANON_KEY=your-cloud-anon-key
```

> **⚠️ Security:** Never put a Supabase service-role key in the mobile app, `.env`, dart-defines, or any client-visible config.

### 3. Push Database Migrations

Link your Supabase project and push the schema:

```bash
supabase login
supabase link --project-ref <your-project-ref>
supabase db push
```

This creates all required tables with Row Level Security policies. See [Database Schema](#database-schema) for details.

Optionally apply seed data to a **development-only** project:

```bash
# Only for dev/demo — never on production
psql <your-supabase-db-url> -f supabase/seed.sql
```

### 4. Run the App

```bash
# Android
flutter run -d android \
  --dart-define=SUPABASE_URL=https://your-project-ref.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<your-cloud-anon-key>

# iOS
flutter run -d ios \
  --dart-define=SUPABASE_URL=https://your-project-ref.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<your-cloud-anon-key>
```

> Without `SUPABASE_URL` and `SUPABASE_ANON_KEY`, the app runs in local-only offline mode. Core finance data is stored in SQLite through Brick; cloud sync starts when Supabase is configured and the user is authenticated.

---

## Project Structure

```sh
lib/
├── brick/                       # Brick offline models, adapters, SQLite schema
├── main.dart                    # Entry point
├── app/                         # App wiring (router, bootstrap, providers)
├── core/                        # Framework utilities (no UI)
│   ├── config/                  # Environment & constants
│   ├── errors/                  # Exception handling
│   ├── formatting/              # Currency, date, number formatters
│   ├── monetization/            # Feature gating (Free/Premium/Pro)
│   ├── money/                   # Decimal-safe Money type
│   ├── notifications/           # Local notification scheduling
│   ├── offline/                 # Offline user context and local-first store
│   ├── prediction/              # Forecasting, Monte Carlo, seasonality
│   ├── security/                # PIN, biometric, encryption
│   ├── storage/                 # Local & secure storage
│   ├── supabase/                # Supabase client initialization
│   └── sync/                    # Multi-device sync & conflict resolution
├── features/                    # 28 feature modules
│   ├── accounting/              # Accounting: chart of accounts, statements
│   ├── accounts/                # Financial account management
│   ├── aiko_assistant/          # Ask Aiko chat interface
│   ├── aiko_character/          # Aiko avatar, expressions, placement rules
│   ├── aiko_optimize/           # AI optimization engine
│   ├── assets/                  # Assets, allocation, net worth
│   ├── auth/                    # Authentication (Supabase Auth)
│   ├── budgets/                 # Budgets (envelope, zero-based, 50/30/20)
│   ├── calculators/             # 60+ financial calculators
│   ├── categories/              # Category management
│   ├── credit_cards/            # Credit card management
│   ├── dashboard/               # Customizable home dashboard
│   ├── debt_loans/              # Debt/loan tracking, payoff plans
│   ├── devices/                 # Multi-device management
│   ├── export/                  # Data export (CSV/PDF/Excel/JSON/Image)
│   ├── goals/                   # SMART goals, saving plans
│   ├── insights/                # Spending insights, cash flow, pace, review
│   ├── learning_hub/            # PFM courses & lessons
│   ├── monetization/            # Subscription plans & paywall
│   ├── onboarding/              # 10-step onboarding flow
│   ├── overview/                # Idea-backed supplemental detail routes
│   ├── investments/               # Investment holdings, allocation, portfolio tracking
│   ├── settings/                # Settings screens
│   ├── tax_center/              # Tax management & analytics
│   ├── transactions/            # Transaction CRUD, rules, search
│   └── travel_mode/             # Multi-currency & travel budgets
├── shared/                      # Cross-feature widgets, state, test data
└── theme/                       # Design system (colors, typography, themes)

supabase/
├── migrations/                  # 18 Postgres migrations (tables + RLS + functions)
├── seed.sql                     # Development seed data
└── storage/                     # Storage bucket configuration

assets/
├── icons/                       # App and reusable SVG icons (`aiko_*.svg`)
└── images/aiko/                 # Aiko character expressions (6 variants)

test/                            # Unit tests
integration_test/                # Integration tests
```

---

## Information Architecture & Navigation

The app uses GoRouter for routing and is structured around a bottom navigation shell with 5 primary tabs:

1. **Overview (`/home`)** — Customizable dashboard with independently managed panels (Aiko greeting, Daily spending, Safe this week, Daily summary, Net earnings, Category budgets, Spending calendar, Upcoming due dates, This Month Overview, Cash flow mapping, Aiko Goal Simulator), primary-color action icons, and a scrollable Edit layout action at the bottom of the page content.
2. **Transactions (`/transactions`)** — Unified search, filters, recurring entries, and auto-categorization rules.
3. **Aiko Assistant (`/aiko`)** — Direct chat UI (`/aiko-assistant`), optimization engine (`/aiko-optimize`), and personalized course hub.
4. **Planning (`/planning`)** — Budget, goals, recurring transactions, credit/debt, net worth, assets, tax, portfolio, and travel planning entry points.
5. **Settings (`/settings`)** — Profile, security, privacy, sync, notification, language, and secondary workspace entry points.

Planning intentionally does not show Accounts or Categories cards. Those remain direct feature routes or contextual tools owned by their feature flows.

### Secondary Routes

| Route | Purpose |
| --- | --- |
| `/accounts` | Bank/Cash/Wallet accounts |
| `/credit-cards` | Credit card limit & payment tracking |
| `/bills` | Recurring bills & subscription cancellations |
| `/goals` | SMART savings & debt payoff progress |
| `/portfolio` | Investment holdings & asset allocation |
| `/assets` | Physical asset tracking & Net Worth |
| `/tax-center` | Tax deduction logs & reports |
| `/calculators` | Built-in financial calculator hub |
| `/learning-hub` | Financial education courses & quizzes |
| `/settings` | Profile, Security (PIN/Biometric), Sync settings |

---

## Offline-First Data Architecture

Aiko reads and writes core finance data locally first. The app uses [Brick](https://github.com/GetDutchie/brick) with SQLite for the local store and Supabase as the remote provider.

- Local writes are optimistic: accounts, categories, transactions, budgets, goals, and profiles are persisted to SQLite immediately.
- When Supabase is configured and the user is signed in, Brick queues HTTP writes and syncs them to Supabase in the background.
- When Supabase is unavailable, repositories return local data or safe empty/default states instead of blocking the UI.
- Domain models still use Aiko's `Money` type; Brick models store primitive fields and map back to domain objects through `lib/brick/offline_model_mappers.dart`.
- Screens must continue to use Riverpod providers and feature repositories. They should not call Supabase, Brick, or SQLite directly.

---

## Architecture Conventions

### Feature Module Pattern

Feature modules under `lib/features/<name>/` follow the current layered layout:

```sh
<feature>/
├── application/               # Feature services, orchestration, business workflows
├── data/                      # Repositories, DTOs, persistence and sync adapters
├── domain/                    # Immutable domain models and value objects
└── presentation/              # Screens, widgets, controllers, UI-only state
```

- Screens compose UI and consume Riverpod providers with `ref.watch` / `ref.read`.
- Application services hold feature-specific business logic and coordinate repositories.
- Repositories handle persistence and sync. Screens should never call Supabase, Brick, or SQLite directly.
- Domain models stay framework-light and use explicit mapping for persistence formats.
- Brick models live under `lib/brick/models/` for offline-first entities. They store primitives only and map to domain models through `lib/brick/offline_model_mappers.dart`.

### Offline-First Rules

- Core finance entities (profiles, accounts, categories, transactions, budgets, goals) read and write the local Brick/SQLite store first.
- When Supabase is configured and a user is authenticated, Brick queues writes through its HTTP client and syncs to Supabase in the background.
- Repositories must gracefully handle offline/no-session states by returning local data, empty lists, or safe defaults instead of surfacing backend errors in normal UI flows.
- Do not use `AikoSupabase.requireSession()` in user-facing repositories unless the operation truly cannot work offline. Prefer `tryClient()` plus an offline fallback.
- After editing files in `lib/brick/models/`, run `dart run build_runner build` and commit generated adapters, schema, and migrations.
- System (default) categories are global Supabase rows (`user_id = NULL`) inserted by migration and injected in-memory at the provider layer via `CategoryDefaults` (`lib/features/categories/domain/category_defaults.dart`). They are never stored in Brick/SQLite per user and are not writable by users. Their fixed UUIDs are stable constants — never change them.

### State Management Rules

- Use Riverpod for all state. Avoid `setState` outside trivial local widget state such as focus, animation, or ephemeral text field UI.
- Top-level providers live in `lib/app/providers.dart`.
- Feature-specific providers and services live inside the relevant feature module.
- Shared cross-feature state lives in `lib/shared/state/`.

### Routing Rules

- All routes are defined in `lib/app/app_router.dart` using GoRouter.
- Bottom navigation uses the authenticated shell with 5 tabs: Overview (`/home`), Transactions, Aiko, Planning, and Settings.
- Planning and Settings own secondary feature entry points. Do not add Accounts or Categories as Planning cards; keep those as direct feature routes or contextual links.
- Route paths use kebab-case, for example `/credit-cards`, `/debt-loans`, and `/tax-center`.
- Idea-inspired screens must belong to the existing feature owner. Add subroutes, menus, or inline tools instead of duplicating a main screen.
- Supplemental routes include dashboard, transaction, budget, goal, report, credit/debt, portfolio, tax, calculator, Aiko, and security detail states.

### Money and Currency Rules

- Never use `double` for money. Use `Money` from `lib/core/money/money.dart`, which wraps `Decimal`.
- Currency formatting uses `lib/core/formatting/currency_formatter.dart` with locale-aware `intl`.
- The user's base currency is stored in their profile. Multi-currency is supported for travel mode and portfolio features.

### Naming Conventions

- Files: `snake_case.dart`
- Classes: `PascalCase`
- Variables and functions: `camelCase`
- Route paths: `/kebab-case`
- Database tables and columns: `snake_case`
- Feature directories: `snake_case`

---

## Core Features

### 🏠 Customizable Dashboard

Drag-and-drop widget dashboard with Aiko welcome card, separately managed Daily spending, Safe this week, Daily summary, Net earnings, Category budgets, Spending calendar, Upcoming due dates, This Month Overview, Cash flow mapping, Aiko Goal Simulator panels, quick-add transaction, and scrollable Edit layout action.

### 💰 Money Tracking & Automation

13 transaction types (income, expense, transfer, refund, investment buy/sell, dividend, interest, loan payment, credit card payment, tax payment, fee, adjustment). Split transactions, receipt attachments, recurring transactions (Once, Daily, Weekly, Monthly, Annually — each with its own end date and cadence-specific settings), and duplicate detection.

- **Quick Entry:** Amount-first flow, receipt scanning (OCR), and voice input.
- **Transaction Rules:** Automate categories, tags, splits, or names based on merchant keywords, accounts, or amounts.

### 📊 Smart Budgeting

Monthly, weekly, yearly, and custom-period budgets. Category-level and account-level budgets. Envelope, zero-based, and 50/30/20 templates. Rollover support. Aiko alerts at 50%, 75%, 90%, and 100% usage.

- **Safe-to-Spend (Leftover):** Real-time spending safety cushion: `Leftover = Income - Fixed Bills - Reserves - Debt - Goals - Current Spending`.
- **Pace:** Real-time indicator comparing current spending velocity against budget limits.

### 🎯 Financial Goals

SMART goals with target amount and date. Priority ranking, auto-calculated monthly contributions, goal progress forecast, and success probability via Monte Carlo simulations. Saving plans with milestone alerts.

### 📈 Insights & Predictions

Spending trends, cash flow analysis with Sankey diagrams, pace monitoring, leftover/safe-to-spend calculation. End-of-month forecasts, budget overrun prediction, net worth projection, and retirement readiness estimates.

### 🤖 Aiko AI Assistant

Natural-language chat for financial questions. Personalized spending insights, budget recommendations, debt payoff strategies, and monthly financial reviews.

### 💳 Credit Card & Debt Management

Credit card tracking with statement balances, APR, rewards, due dates, and credit utilization. Debt payoff plans using snowball or avalanche methods. Extra payment simulation with interest savings estimates.

### 📱 Portfolio, Assets & Tax

Investment holdings with performance charts, allocation analysis, dividends, and realized/unrealized gains. Asset allocation by class, currency, geography, and risk level. Net worth tracking with trend charts. Tax Center for tax-deductible expense flagging, capital gains, document storage, and estimated tax reports.

### 🌍 Travel Mode

Multi-currency accounts, automatic exchange rate updates, travel budgets, foreign transaction fee tracking, and trip-based expense reports.

---

## Financial Calculator Suite (~60 Tools)

Saved calculations store as `SavedCalculatorScenario` and can be converted into active budgets or goals. Compare scenarios side-by-side and convert results into goals or plans.

- **Finance & Investment:** Time Value of Money (TVM), Compound Interest, ROI, IRR/NPV, Savings Goal, Certificate of Deposit (CD), Bond, Tax Equivalent Yield, Rule of 72.
- **Loan & Mortgage:** Loan Amortization & Comparison, Refinance, APR, Rent vs. Buy, Home Affordability, bi-weekly payments, Rental Property.
- **Retirement:** Retirement Savings & Income Planner, Traditional vs. Roth IRAs, Required Minimum Distributions (RMD), Social Security Estimator, Annuity.
- **Credit Card & Auto:** CC Payoff & Minimum Payment, Balance Transfer, Auto Loan vs. Lease.
- **Stock & Portfolio:** Weighted Average Cost of Capital (WACC), Black-Scholes Options, Expected Return, CAPM, Holding Period Return, Capital Gains.
- **Everyday & Tax:** Salary to Hourly, Paycheck Tax, Inflation, Effective Rate, Margin/Markup, Tip & Percentage.

---

## Prediction and AI System

- Rule-based forecasting powers MVP predictions such as end-of-month balance, budget overrun risk, and goal completion.
- Moving averages track recurring expense trends.
- Seasonality detection identifies monthly spending patterns.
- Monte Carlo simulations support advanced goal and retirement probability under three scenarios (optimistic, expected, conservative).
- Scenario modeling supports optimistic, normal, and conservative outcomes.
- Prediction logic lives in `lib/core/prediction/`.
- AI suggestions are stored as `AikoInsight` records in Supabase.

**Aiko Insights System.** AI evaluates transaction telemetry to generate recommendations in four dimensions:

- *Descriptive:* "You spent $450 on dining out this month."
- *Diagnostic:* "Dining out increased by 20% due to restaurant visits on weekends."
- *Predictive:* "At this pace, you will exceed your dining budget in 5 days."
- *Prescriptive:* "Limit flexible weekend spending to $15/day to stay on track."

**Safety & disclaimers.** Aiko operates as an informative dashboard and advisor. AI features must include the disclaimer: *AI insights are estimates, not certified financial, investment, or tax advice.*

---

## Database Schema

The Supabase backend uses 15 core tables, all protected by Row Level Security:

| Table | Purpose |
| --- | --- |
| `profiles` | User profile, preferences, base currency |
| `accounts` | Financial accounts (cash, bank, e-wallet, credit card, loan, investment, asset) |
| `transactions` | All financial transactions (13 types) |
| `categories` | Hierarchical spending categories — 30 global system rows (`user_id = NULL`, `is_default = true`) plus user-created custom rows |
| `transaction_rules` | Auto-categorization rules |
| `budgets` | Budget definitions and alert thresholds |
| `goals` | Financial goals and progress tracking |
| `credit_cards` | Credit card details and metrics |
| `assets` | Asset records by class and risk level |
| `liabilities` | Debt and loan records |
| `investment_holdings` | Portfolio holdings and market values |
| `tax_records` | Tax-year income, deductions, documents |
| `saved_calculator_scenarios` | Saved calculator inputs and results |
| `aiko_insights` | AI-generated financial insights |
| `devices` | Registered devices for sync |

All tables enforce `user_id = auth.uid()` via RLS policies — users can only access their own data. Exception: `categories` uses split policies — SELECT allows `user_id IS NULL OR user_id = auth.uid()` so global system categories are readable by all authenticated users; INSERT/UPDATE/DELETE remain scoped to `auth.uid()`.

### Entity Field Reference

| Entity | Fields |
| :--- | :--- |
| **User** | `id` (UUID), `name`, `email`, `base_currency`, `country`, `timezone`, `preferred_theme`, `aiko_personality_setting`, `created_at` |
| **Account** | `id`, `user_id`, `name`, `type` (cash, bank, card, loan, etc), `currency`, `current_balance`, `is_active` |
| **Transaction** | `id`, `user_id`, `account_id`, `type`, `amount`, `currency`, `exchange_rate`, `category_id`, `date`, `merchant`, `note`, `tags`, `is_recurring`, `tax_flag` |
| **Category** | `id`, `user_id`, `name`, `parent_id`, `type`, `icon`, `color`, `budget_enabled` |
| **TransactionRule** | `id`, `user_id`, `rule_name`, `condition_type`, `condition_value`, `target_category_id`, `target_account_id`, `tags_to_apply`, `priority`, `is_active` |
| **Budget** | `id`, `user_id`, `category_id`, `amount`, `period` (weekly, monthly, custom), `rollover_enabled`, `alert_thresholds` |
| **Goal** | `id`, `user_id`, `name`, `target_amount`, `current_amount`, `target_date`, `linked_account_id`, `priority`, `success_probability` |
| **CreditCard** | `id`, `user_id`, `account_id`, `credit_limit`, `statement_day`, `due_day`, `apr`, `rewards_type` |
| **Asset** | `id`, `user_id`, `name`, `asset_class`, `value`, `currency`, `liquidity_level`, `risk_level` |
| **Liability** | `id`, `user_id`, `name`, `type`, `balance`, `interest_rate`, `monthly_payment`, `due_date` |
| **InvestmentHolding** | `id`, `user_id`, `symbol`, `asset_class`, `quantity`, `average_cost`, `current_price`, `currency`, `market_value` |
| **TaxRecord** | `id`, `user_id`, `tax_year`, `income_type`, `amount`, `deduction_type`, `document_id` |
| **Subscription** | `id`, `user_id`, `merchant`, `amount`, `billing_cycle`, `next_billing_date`, `category_id`, `cancellation_status` |
| **SavedScenario** | `id`, `user_id`, `calculator_type`, `input_json`, `result_json`, `notes`, `created_at` |
| **AikoInsight** | `id`, `user_id`, `insight_type`, `title`, `description`, `recommendation`, `confidence_score`, `source_data`, `dismissed_at`, `created_at` |

---

## Supabase Backend Rules

- Migrations live in `supabase/migrations/`. Never edit existing migrations; create new ones.
- All tables use Row Level Security. Users can only access rows where `user_id = auth.uid()`.
- Never put the Supabase service-role key in the mobile app, `.env`, dart-defines, or any client-visible config.
- Seed data in `supabase/seed.sql` is for development/demo only.
- Push migrations to cloud with `supabase link --project-ref <ref>` followed by `supabase db push`.

---

## Design System

This section is the source of truth for Aiko's visual system, screen patterns, and component rules. If screen code conflicts with it, update the screen or shared component unless product requirements say otherwise. Do not add one-off colors or radii to feature screens when a token or theme value exists.

### Tokens

Use a three-layer model:

| Layer | Purpose | Flutter home |
| --- | --- | --- |
| Primitive | Raw colors, type sizes, spacing, radius | `AikoColors`, `AikoTypography` |
| Semantic | Meaning: primary, danger, surface, muted, outline | `ColorScheme`, theme extensions |
| Component | Button, card, input, sheet, chip, nav specs | `AikoTheme`, shared widgets |

Theme values live in `lib/theme/aiko_colors.dart`, `lib/theme/aiko_theme.dart`, `lib/theme/aiko_typography.dart`, and `lib/theme/aiko_spacing.dart`.

### Color

Primitive and semantic colors:

| Role | Light | Dark | Use |
| --- | ---: | ---: | --- |
| Primary | `#3B82F6` | `#93C5FD` | Primary actions, selected state, active nav |
| Secondary | `#1D4ED8` | `#3B82F6` | Strong selection, key blue charts |
| AI/Premium | `#7C3AED` | `#B894F5` | Aiko, AI, optimization, premium |
| Scaffold | `#D8E0F5` | `#0F172A` | Main background |
| Alternate scaffold | `#F6F8FF` | `#0F172A` | Light alternate screens |
| Surface | `#EEF2FF` | `#121C31` | Cards, sheets, grouped controls |
| Surface strong | `#E3E9FF` | `#1B2740` | Selected or high-emphasis panels |
| Text primary | `#0F172A` | theme on-surface | Primary text |
| Text secondary | `#293348` | theme on-surface-variant | Secondary text |
| Text muted | `#778196` | theme muted | Metadata and helper text |
| Outline | `#BAC3D6` | `#414B60` | Focusable or visible borders |
| Outline subtle | `#DCE4F8` | `#293348` | Dividers and quiet outlines |
| Success | `#16A34A` | `#4ADE80` | Income, savings, completed, positive trend |
| Warning | `#F59E0B` | `#FBBF24` | Bills, due soon, budget caution |
| Danger | `#DC2626` | `#F87171` | Errors, destructive actions, overspending |
| Analytics | `#0D9488` | `#2DD4BF` | Reports, portfolio, allocation, analysis |

Rules:

- Primary blue means current, continue, or main action.
- Overview and Transactions app-bar action icons use the primary action color so action treatment stays consistent across daily workflows.
- Purple is reserved for Aiko, AI, optimization, premium, or review.
- Green, orange, red, and teal keep their semantic finance meanings.
- Never rely on color alone. Pair color with text, icon, label, or number.
- Inactive states are neutral, not pale saturated variants.

#### Color Ramps

Use 10-stop ramps for charts, progress bars, and selected states:

| Ramp | Stops |
| --- | --- |
| Primary blue | `#071426`, `#0B356F`, `#0C4A9A`, `#0B5DBD`, `#1D74E8`, `#3B82F6`, `#75A4F5`, `#A5C4F6`, `#D8E5FF`, `#FFFFFF` |
| Secondary blue | `#071426`, `#0B2A7A`, `#073AA8`, `#1D4ED8`, `#4268EA`, `#6385F0`, `#8AA4F5`, `#AFC0F8`, `#DCE5FF`, `#FFFFFF` |
| Tertiary purple | `#071426`, `#240052`, `#3B0785`, `#5B0BC0`, `#6D28D9`, `#7C3AED`, `#9B67F2`, `#B894F5`, `#DCCBFF`, `#FFFFFF` |
| Neutral | `#071426`, `#0F172A`, `#293348`, `#414B60`, `#5B6578`, `#778196`, `#9BA4B8`, `#BAC3D6`, `#DCE4F8`, `#FFFFFF` |

Aiko character artwork should be tested on both dark and light backgrounds. Use a subtle glow or border if the artwork has transparent regions that blend into dark surfaces.

### Typography

| Role | Font | Use |
| --- | --- | --- |
| Headline | Hanken Grotesk | Screen titles, major balances, hero numbers |
| Body | Manrope | Body text, forms, lists, settings |
| Label | Manrope | Buttons, chips, tabs, metadata |

| Theme style | Size | Weight | Use |
| --- | ---: | ---: | --- |
| `displayLarge` | 48 | 700 | Rare onboarding or report moments |
| `headlineLarge` | 36 | 700 | Major balance or summary number |
| `headlineMedium` | 28 | 700 | Screen-level headline inside body |
| `titleLarge` | 20 | 700 | App bar title, card title |
| `titleMedium` | 16 | 700 | Section title, prominent row title |
| `titleSmall` | 14 | 700 | Dense list title |
| `bodyLarge` | 16 | 400 | Primary readable text |
| `bodyMedium` | 14 | 400 | Default body and metadata |
| `bodySmall` | 12 | 500 | Helper text |
| `labelLarge` | 14 | 700 | Buttons and tabs |
| `labelMedium` | 12 | 700 | Chips and badges |
| `labelSmall` | 11 | 700 | Dense status labels |

Letter spacing is `0`. Use tabular figures for aligned money columns. Do not use display-scale text inside compact cards, lists, settings rows, sidebars, or form controls.

### Spacing, Shape, and Surfaces

Spacing follows a 4/8px rhythm:

| Token | Value | Use |
| --- | ---: | --- |
| `space-1` | 4 | Icon/text gaps, dense metadata |
| `space-2` | 8 | Row and chip gaps |
| `space-3` | 12 | Compact card internals |
| `space-4` | 16 | Screen gutters, form gaps, default card padding |
| `space-5` | 20 | Prominent card padding |
| `space-6` | 24 | Section gaps |
| `space-8` | 32 | Major screen rhythm |

Shape and surface rules:

- Cards, rows, inputs, chips, segmented controls: 8px radius.
- Bottom sheets: 20px top radius.
- FABs may use 16px radius.
- Avoid 20px+ radii in product cards and decorative shadows.
- Use scaffold, surface, surface strong, input fill, outline subtle, and outline by job.
- Do not put cards inside cards. Use rows and dividers for related content inside one card.
- Repeated objects use list tiles or object cards, not section cards wrapping cards.

Density rules: daily lists are compact, detail screens breathe, dashboard uses fewer stronger metrics, settings use grouped rows, and forms use full-width controls with consistent 16px gaps.

### Screen Archetypes

| Archetype | Examples | Rules |
| --- | --- | --- |
| Dashboard | Home, Budget overview, Portfolio overview | Lead with one primary financial summary, then 2-4 supporting metrics. Put data before copy. Label charts with numbers and periods. |
| List and detail | Transactions, Accounts, Categories, Bills, Goals | Compact tappable rows with type mark, title, subtitle, trailing amount/status, and chevron. Details lead with primary number/title and grouped facts. |
| Form | Add transaction, Budget form, Profile, Add category | Required controls first, full-width fields, helper text under controls, primary save button, progressive disclosure. |
| Settings | Settings, Notifications, Profile | Grouped rows with icon, title, short description, and status/control. Separate security and destructive actions. |
| Assistant and AI | Aiko assistant, Optimize, Review | Cite financial context, give actions or dismiss reasons, avoid filler, keep finance states semantic even when AI uses purple. |
| Planning and education | Goals, Learning Hub, Calculators, Reports | Use progressive disclosure. Show progress or saved state. Calculators show input, result, conversion action. Reports pair chart visuals with summary text. |
| Supplemental tools | Filters, split transaction, receipt review, cash flow, loan calculator, profile security | Extend an owning feature, never duplicate top-level screens. First viewport shows the task object. Required completion actions use sticky bottom bars on mobile. |
| Placeholders | Expansion screens | State what the feature will do and provide one action. Do not show fake finished dashboards. Prefer `AikoScreenState` or `AikoFeatureOverviewScreen`. |

### Components

`FinanceCard` is for financial objects, metrics, and grouped task panels: 8px radius, 16px default padding, 20px prominent padding, outline-variant border, no default shadow, `titleMedium` title, `bodyMedium` body, 40px icon tile with 8px radius and 12 percent accent opacity, stable `InkWell` tap state. Never use it as a decorative wrapper around another card.

Cards carry a strict three-tier hierarchy:

1. Primary number or title.
2. Supporting metadata.
3. One clear action or status.

Avoid decorative cards that do not hold a real object, metric, or action.

Buttons: filled for primary, outlined for secondary, text for low-emphasis inline actions, icon buttons for familiar commands. Minimum height is 48px, radius is 8px, disabled state must be visible and non-interactive, and familiar commands should use icons.

Icon buttons: 40–48px touch target, 48px minimum tap target. Use circular tiles for primary and destructive actions, square or circular tiles for AI actions.

| Icon button | Style |
| --- | --- |
| Primary | Blue circle, white icon |
| AI / premium | Purple square or circle, white icon |
| Destructive | Red circle, white icon |

Inputs and pickers: visible labels, 54px minimum height, 8px radius, pale blue fill, thin blue-gray border, leading icon for search, primary focus border, danger error border. Placeholder text uses muted neutral. Do not place long helper text inside inputs — put validation or helper copy below the field. Custom pickers show selected value plus context such as category group or account balance. Bottom-sheet pickers use compact list rows with selected checkmarks.

Lists: compact `ListTile` rows, 48px tap target, single-line titles unless needed, trailing amounts/statuses aligned, dividers or card borders instead of nested containers.

Chips and badges: short labels for filters, tags, and small statuses. Status color must match semantic meaning and include text.

Navigation: authenticated shell tabs are Overview, Transactions, Aiko, Planning, Settings. Bottom nav stays visible, active state uses primary with white active icon, secondary feature routes live in Planning or Settings groups.

Overview layout editing is a scrollable in-page action labeled `Edit layout` / `Done` at the bottom of Overview content. Keep the Overview app bar reserved for utility navigation such as notifications.

Sheets and dialogs: use bottom sheets for mobile creation/editing and dialogs for destructive confirmation. Sheets need drag handle, safe area, scrollable content, and 20px top radius. Destructive dialogs name the object and effect.

Charts and progress: every chart needs a text summary. Every progress bar needs current, target, and period. Use semantic color plus label. Progress height is 8px compact and 10-12px on dashboards.

Interactive states:

| State | Treatment |
| --- | --- |
| Pressed / splash | Primary color at 12% opacity |
| Hover (web/desktop) | Surface tint at 8% opacity |
| Focused | 2px primary outline offset by 2px |
| Disabled | 40% opacity, no interaction |
| Dragging | Slight scale (1.02) with subtle shadow |

States: use `AikoScreenState` unless specialized. Loading uses skeleton/quiet progress with no fake data. Empty explains what is missing and gives one action. Error explains retry/recovery. Offline explains local mode. Locked explains authentication.

### Shared Widgets

Use `lib/shared/widgets/aiko_data_widgets.dart` for idea-backed supplemental screens and new finance detail screens.

| Widget | Use |
| --- | --- |
| `AikoDetailScaffold` | Detail/tool screens with app bar, scroll body, optional sticky bottom action |
| `AikoInlineNotice` | Aiko tips, warnings, review notes, contextual explanations |
| `AikoMetricCard` / `AikoMetricGrid` | Compact financial summaries |
| `AikoProgressBar` / `AikoProgressRow` | Budget, debt, goal, portfolio, tax progress |
| `AikoDataListCard` / `AikoDataRow` | Grouped facts and settings-style rows |
| `AikoMiniBarChart`, `AikoDonutChart`, `AikoGauge`, `AikoSankeyPreview` | Lightweight labeled preview charts |

Prefer shared widgets over local one-off cards or painters. Do not nest `AikoDataListCard`. Use sticky bottom actions through `AikoDetailScaffold.bottomBar` unless a feature already has a pattern.

### Iconography

Use Material Icons as the primary icon set. Custom SVG icons are acceptable for brand moments (Aiko logo, onboarding illustrations) but should not replace standard icons for common actions.

Sizes:

| Context | Size |
| --- | ---: |
| Inline with body text | 16 |
| List tile leading | 20 |
| Action bar / toolbar | 24 |
| Empty state / hero | 48 |

Icon color rules:

| Context | Color |
| --- | --- |
| Default | `onSurface` |
| Active / selected | `primary` |
| Destructive | `danger` |
| AI / premium | `tertiary` |
| Muted / disabled | `mutedText` |

### SVG Icons

Reusable SVG icons live in `assets/icons/`, use `aiko_<name>.svg`, `viewBox="0 0 24 24"`, and `currentColor` so they can be recolored consistently across Flutter UI, exports, and future web surfaces.

Required assets: `aiko_home.svg`, `aiko_transactions.svg`, `aiko_budget.svg`, `aiko_insights.svg`, `aiko_aiko.svg`, `aiko_account.svg`, `aiko_bank.svg`, `aiko_wallet.svg`, `aiko_credit_card.svg`, `aiko_category.svg`, `aiko_receipt.svg`, `aiko_search_filter.svg`, `aiko_goal.svg`, `aiko_cash_flow.svg`, `aiko_debt.svg`, `aiko_loan.svg`, `aiko_portfolio.svg`, `aiko_tax.svg`, `aiko_calculator.svg`, `aiko_travel.svg`, `aiko_security.svg`, `aiko_notification.svg`.

Keep icons stroke-based, single-color, 24x24, and friendly but not cartoonish. Do not mix filled, duotone, and outline styles in the same control group. Use Material icons for platform-standard commands and SVGs for brand-owned navigation, exports, and reusable assets. New required SVGs need tests in `test/shared/widgets/aiko_svg_assets_test.dart` before UI reliance.

### Aiko Character Usage

Six expression variants: `happy`, `thinking`, `encouraging`, `warning`, `celebrating`, `welcome`. Use Aiko purposefully — she adds warmth, reassurance, or guidance, never decoration.

Use Aiko for:

- Onboarding welcome and completion.
- Insight explanations.
- Goal encouragement.
- Budget warnings.
- Empty states that need reassurance.
- Aiko assistant chat.

Do not place Aiko on every screen. She must not cover tables, charts, balances, forms, or critical actions.

Tone:

- Use: "You are still on track. Groceries are running a little high, so I found two easy places to adjust."
- Avoid: "You spent too much again."

### Ownership

| Owner | Owns |
| --- | --- |
| Categories | Name, type, group, icon, color, active/archive state |
| Budgets | Category inclusion, limits, periods, rollover, alerts |
| Transactions | Account, category, amount, merchant, notes, tags, receipt, voice, split data |
| Accounts | Balances, currency, account type, active state, net-worth inclusion |
| Settings | App config, profile, privacy, security, sync, notification, route links |
| Aiko | AI explanation, suggestions, review, optimization, chat |
| Dashboard | In-page monthly overview, scrollable layout customization, notifications, cross-feature summaries |
| Reports | Generated summaries and monthly report presentation |
| Calculators | Inputs, results, saved scenarios, conversion actions |
| Portfolio | Holdings and allocation detail |
| Assets/net worth | Household asset summaries |
| Debt/credit | Payoff, utilization, loan, statement detail states |

### Motion and Accessibility

Motion:

| Motion | Duration | Curve |
| --- | ---: | --- |
| Tap feedback | 80-150 ms | Material state layer |
| Small reveal | 150-200 ms | `Curves.easeOut` |
| Sheet / modal entrance | 250-300 ms | `Curves.easeOut` |
| Page transition | 250-300 ms | `Curves.easeInOut` |
| Progress fill | 300-400 ms | `Curves.easeInOut` |
| Emphasis (celebrate, alert) | ~600 ms | `Curves.elasticOut` |

Animate opacity and transform, not layout size. Do not animate financial numbers while users read them — settle within 300 ms. Use `AnimatedSwitcher` for state transitions (loading to loaded, empty to populated). Avoid continuous looping animation except loading indicators. Respect reduced motion. No hover-only affordances.

Accessibility:

- Body text contrast: at least 4.5:1; secondary text: at least 3:1.
- Touch targets: at least 48x48.
- Focus indicators must be visible.
- Icon-only buttons need semantic labels or tooltips.
- Color never carries meaning alone.
- Text must not clip with dynamic type.
- Charts need labels, legends, or summaries.
- Form errors appear near the relevant field.
- Snackbars/toasts are not the only record of important changes.

### Flutter Implementation Rules

- Theme values live in `lib/theme/aiko_colors.dart`, `lib/theme/aiko_theme.dart`, and `lib/theme/aiko_typography.dart`.
- Shared UI primitives live in `lib/shared/widgets/`.
- Feature screens consume shared primitives instead of re-creating card, button, empty-state, or picker styles.
- Idea-backed detail/tool screens use `AikoDetailScaffold` and `lib/shared/widgets/aiko_data_widgets.dart`.
- Use `Money` for money values.
- Use Riverpod providers for state.
- Screens do not call persistence APIs directly.
- Prefer `AikoScreenState` for loading, empty, error, offline, locked, and permission states.
- Custom components cover default, pressed, focused, disabled, loading, error, and success where applicable.
- Required SVG assets are covered by `test/shared/widgets/aiko_svg_assets_test.dart`.
- Supplemental route coverage lives in `test/app/idea_route_coverage_test.dart`.

### Route and Idea Coverage

Apply the design system in batches:

1. Shared foundation: `FinanceCard`, `AikoScreenState`, action buttons, icon tiles, shell navigation.
2. Core daily screens: Home, Transactions, Add transaction, Budget, Settings.
3. Money object screens: Accounts, Categories, Goals, Bills, Credit Cards, Debt.
4. Wealth/planning screens: Portfolio, Assets, Tax Center, Reports, Export, Travel Mode.
5. Aiko/learning screens: Aiko Assistant, Optimize, Review, Learning Hub, Subscription Plan.
6. Placeholder screens: import/export, calculators, saved scenarios, future expansion.

The May 31, 2026 idea boards are references for density, hierarchy, and feature coverage, not separate themes. Existing feature screens absorb useful states through subroutes, menus, or inline tools.

| Idea group | Existing owner | Supplemental routes |
| --- | --- | --- |
| Core app screens | Auth, onboarding, dashboard, accounts | `/notifications`, in-page This Month Overview, in-page Edit layout |
| Transactions, categories, accounts | Transactions, categories, accounts | inline transaction search and filters, `/transactions/split`, `/transactions/receipt-review` |
| Budget, goals, cash flow, reports | Budget, goals, reports | `/budget/pace`, `/budget/safe-to-spend`, `/budget/cash-flow`, `/budget/cash-flow-sankey`, `/goals/detail`, `/goals/saving-plan`, `/goals/chance-of-success`, `/reports/monthly` |
| Credit, debt, portfolio, tax | Credit cards, debt, portfolio, assets, tax | `/credit-cards/detail`, `/debt-overview`, `/loans/detail`, `/net-worth`, `/portfolio/allocation`, `/portfolio/holding`, `/tax-analytics` |
| Aiko AI, calculators, settings, extras | Aiko, calculators, bills, learning, travel, settings | `/aiko-insights`, `/calculator-result`, `/profile-security` |

Route rules:

- Do not duplicate an existing feature screen to match an idea board.
- Use sticky bottom actions for filter, save, confirm, and calculator-result screens when required.
- Use a scrollable in-page action for Overview layout editing; do not put the dashboard edit layout control in the app bar or fixed bottom bar.
- Keep sample data realistic and scoped to preview/offline states.
- Real repositories remain the source of persisted user data.
- Aiko guidance appears after the primary number or decision, except onboarding and assistant chat.
- Every supplemental route must render without a Supabase session.

Entry points:

| Owner screen | Access pattern |
| --- | --- |
| Home dashboard | App bar action for notifications; in-page This Month Overview and scrollable Edit layout action for customization |
| Transactions | Search in app bar with inline filters for type, amount, and date; split and receipt review remain transaction tools |
| Budget | Tools menu exposes pace, safe-to-spend, cash flow, Sankey |
| Goals | Tools menu exposes saving plan, chance of success, detail |
| Reports | Monthly report opens from reports list |
| Calculators | Hub links to focused calculators and result states |
| Planning | Links to budget, goals, recurring transactions, credit, debt, net worth, assets, tax, portfolio, and travel. Do not expose Accounts, Categories, or Accounting as Planning cards. |
| Settings | Owns profile, security, privacy, sync, notification preferences |

### QA Checklist

Before a screen is design-complete:

- Main task is visible in the first viewport.
- Primary action is obvious and reachable while scrolling when required.
- Financial numbers appear before AI guidance and include context.
- Lists are compact and tappable.
- Form fields have labels and recovery-oriented validation.
- Empty, loading, error, and offline states exist or are intentionally inherited.
- No nested cards, decorative shadows, or oversized radii.
- Raw colors are limited to theme files or explicit data visualization needs.
- Text does not overlap or clip at small phone widths.
- Dark theme contrast is sufficient.
- Aiko appears only when useful.
- The screen does not duplicate an existing main feature route.
- Widget tests cover critical rendering and interactions.

---

## UX Acceptance Criteria

- **Offline-first usability:** Supplemental product routes must render useful local/demo states without requiring Supabase authentication.
- **Task completion:** Search/filter, save, confirm, split, and calculator result screens use clear primary actions, preferably sticky bottom actions on mobile.
- **Dashboard customization:** Daily spending, Safe this week, Daily summary, Net earnings, Category budgets, Spending calendar, Upcoming due dates, This Month Overview, Cash flow mapping, and Aiko Goal Simulator are separate Overview panels that can be managed in layout editing. Layout editing uses a scrollable in-page action; Overview and Transactions app-bar action icons use the same primary action color.
- **No duplicate destinations:** Main tabs own core workflows; extra idea-board states are exposed through existing navigation, action menus, or detail routes.
- **Financial clarity:** Primary balances, progress, and risk states appear before supporting Aiko guidance.
- **Accessibility:** Icons need semantic labels or adjacent text where meaning is not obvious.

---

## Testing

### Unit Tests

```bash
flutter test
```

Covers: money types, formatters, prediction engine, data models, providers, transaction rules, feature gating, import/export parsers, idea route coverage, and required SVG assets.

### Integration Tests

```bash
flutter test integration_test
```

Covers: onboarding flow, transaction CRUD, budget creation, goal creation, dashboard rendering, calculator navigation.

### Quality Gates

Run all of these before any release:

```bash
dart run build_runner build       # Required after Brick model changes
dart format --set-exit-if-changed .
flutter analyze
flutter test
flutter test integration_test
```

---

## Monetization & Security

### Plans

| Plan | Includes |
| --- | --- |
| **Free** | Manual tracking, basic categories & budgets, basic charts, limited calculators, CSV export, basic Aiko insights |
| **Premium** | Unlimited accounts, advanced reports, AI recommendations, forecasting, receipt OCR, credit card optimization, portfolio analytics, tax reports, PDF/Excel export, multi-device sync |
| **Pro** | Advanced accounting (double-entry, balance sheets, reconciliation), business reports, invoices, multi-user access, advanced tax tools, estate planning, full Monte Carlo simulations, API access |

### Security Architecture

PIN and Biometrics (Face ID/Touch ID) for local access, secure token storage, remote device logout, cloud sync conflict resolution, and granular data privacy options (opt-in AI parsing, local-only mode).

---

## Development Roadmap

### Phase 1 — Foundation ✅

Aiko brand system, blue design system, authentication, onboarding, account and transaction tracking.

### Phase 2 — Core Finance ✅

Budgets, goals, saving plans, categories, transaction rules, dashboard, spending charts, monthly reports, CSV export.

### Phase 3 — Intelligence ✅

Aiko insights, spending analysis, cash flow, pace/leftover, prediction engine, Ask Aiko chat, Aiko Review.

### Phase 4 — Advanced Finance ✅

Credit cards, debt/loan management, payoff plans, recurring transactions, calculators.

### Phase 5 — Wealth ✅

Assets, net worth, portfolio, allocation, tax center, import/export, accounting, reports.

### Phase 6 — Platform ✅

Multi-device sync, travel mode, learning hub, Aiko Optimize, monetization tiers, settings, devices.

### Future

- Full bank sync via Open Banking APIs
- Advanced retirement planning
- Estate planning module
- Fully automated AI advisor
- API access for Pro users

---

## Common Tasks

### Adding a New Feature Module

1. Create `lib/features/<name>/` with `application/`, `data/`, `domain/`, and `presentation/` folders.
2. Add routes in `lib/app/app_router.dart`.
3. If the feature needs a Supabase table, create a new migration in `supabase/migrations/`.
4. Add RLS policies to the migration. Always filter by `auth.uid()`.
5. If the feature must work offline, add a Brick model under `lib/brick/models/` and regenerate code with `dart run build_runner build`.
6. Register providers in `lib/app/providers.dart` only when they need app-wide access.
7. Add unit tests in `test/` for the model, repository fallback behavior, and provider.
8. Use `Money` for all monetary values. Never use `double` for amounts.
9. Follow the existing feature module pattern.

### Adding a New Calculator

1. Create the calculator file in `lib/features/calculators/`.
2. Register it in the calculator hub screen's category list.
3. Calculator results should be saveable as `SavedCalculatorScenario`.
4. Optionally allow converting results into goals, budgets, or plans.

### Adding a New Aiko Insight Type

1. Define the insight type in the `AikoInsight` model.
2. Generate insights in the relevant provider or a background process.
3. Store insights in the `aiko_insights` table.
4. Display on dashboard and insights screen.
5. Always include a `source_data` reference so users can inspect the underlying data.

### Adding a New Supabase Migration

```bash
supabase migration new <descriptive_name>
# Edit the generated SQL file
supabase db push
```

---

## Key Principles

1. Clarity first: financial data must be easy to understand.
2. Data first, Aiko enhanced: AI augments but never obscures financial data.
3. Decimal-safe money: never use `double` for amounts.
4. Privacy by design: RLS on everything, encrypted storage, user consent for AI.
5. Offline first: core money workflows must read/write locally first and sync later.
6. Actionable insights: every insight should lead to a useful next step.
7. Warm, non-judgmental tone: Aiko encourages, never shames.
8. Test before ship: run all quality gates before treating any change as releasable.

---

## Contributing

1. Follow the [architecture conventions](#architecture-conventions) in this README.
2. Use the `Money` type for all monetary values — never `double`.
3. Use repositories for persistence; screens should not call Supabase, Brick, or SQLite directly.
4. Add Brick models and regenerate adapters when a feature needs offline-first storage.
5. Add RLS policies to all new Supabase tables.
6. Write unit tests for new models and providers.
7. Follow the [Design System](#design-system) — consume shared primitives and tokens instead of one-off styles, and run the QA checklist before treating a screen as complete.
8. Run all quality gates before submitting changes.
9. Follow Aiko's brand voice: warm, supportive, non-judgmental.

---

## License

This project is private and not published to pub.dev. See `pubspec.yaml` for details.

---

<p align="center">
  <em>Built with 💙 — Grow wealth with Aiko.</em>
</p>
