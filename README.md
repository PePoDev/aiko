# Aiko — Personal Finance Management App

<p align="center">
  <strong>AI-powered personal finance, guided by Aiko.</strong><br/>
  Track money · Budget · Save · Invest · Plan — with a friendly AI companion.
</p>

> This README is the canonical source of truth for both human contributors and coding agents.

---

## What Is Aiko?

Aiko is a cross-platform personal finance app for iOS and Android, built with Flutter and powered by Supabase Cloud. At its core is **Aiko** — a cute, anime-style AI assistant with blue hair who helps users understand their money, build wealth, and reach financial goals through friendly, non-judgmental guidance.

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

## Screenshots

> *Coming soon — app screenshots will be added after the first release build.*

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
AIKO_ENV=development
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
  --dart-define=SUPABASE_ANON_KEY=<your-cloud-anon-key> \
  --dart-define=AIKO_ENV=development

# iOS
flutter run -d ios \
  --dart-define=SUPABASE_URL=https://your-project-ref.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<your-cloud-anon-key> \
  --dart-define=AIKO_ENV=development
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
│   ├── import_export/           # File parsers & generators
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
│   ├── bills/                   # Bills, subscriptions, cancellation
│   ├── budgets/                 # Budgets (envelope, zero-based, 50/30/20)
│   ├── calculators/             # 60+ financial calculators
│   ├── categories/              # Category management
│   ├── credit_cards/            # Credit card management
│   ├── dashboard/               # Customizable home dashboard
│   ├── debt_loans/              # Debt/loan tracking, payoff plans
│   ├── devices/                 # Multi-device management
│   ├── export/                  # Data export (CSV/PDF/Excel/JSON/Image)
│   ├── goals/                   # SMART goals, saving plans
│   ├── import_export/           # Data import (CSV/Excel/OFX/QIF)
│   ├── insights/                # Spending insights, cash flow, pace, review
│   ├── learning_hub/            # PFM courses & lessons
│   ├── monetization/            # Subscription plans & paywall
│   ├── onboarding/              # 10-step onboarding flow
│   ├── portfolio/               # Investment portfolio tracking
│   ├── reports/                 # Report builder (13+ report types)
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
├── icons/                       # App icons
└── images/aiko/                 # Aiko character expressions (6 variants)

test/                            # Unit tests
integration_test/                # Integration tests
```

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

### State Management Rules

- Use Riverpod for all state. Avoid `setState` outside trivial local widget state such as focus, animation, or ephemeral text field UI.
- Top-level providers live in `lib/app/providers.dart`.
- Feature-specific providers and services live inside the relevant feature module.
- Shared cross-feature state lives in `lib/shared/state/`.

### Routing Rules

- All routes are defined in `lib/app/app_router.dart` using GoRouter.
- Bottom navigation uses the authenticated shell with 5 tabs: Home, Transactions, Budget, Insights, Aiko.
- The "More" menu items route to feature screens as sub-routes.
- Route paths use kebab-case, for example `/credit-cards`, `/debt-loans`, and `/tax-center`.

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

### Design and Aiko Rules

- Primary color: Blue (`#3B82F6`). The full palette lives in `lib/theme/aiko_colors.dart`.
- Light and dark themes live in `lib/theme/aiko_theme.dart`.
- Semantic colors: green for success/savings, orange for warnings/bills, red for danger/overspending, purple for premium/AI, and teal for analytics/portfolio.
- Aiko follows "Data first, Aiko enhanced": use the character purposefully for welcome, insights, goals, warnings, and reviews, never over numbers or charts.
- Aiko's voice is warm, supportive, and non-judgmental. Never shame users about their finances.

---

## Feature Highlights

### 🏠 Customizable Dashboard

Drag-and-drop widget dashboard with Aiko welcome card, net worth, cash flow, budget status, pace indicator, safe-to-spend, upcoming bills, goal progress, portfolio snapshot, and quick-add transaction.

### 💰 Money Tracking

13 transaction types (income, expense, transfer, refund, investment buy/sell, dividend, interest, loan payment, credit card payment, tax payment, fee, adjustment). Split transactions, receipt attachments, recurring entries, and duplicate detection.

### 📊 Smart Budgeting

Monthly, weekly, yearly, and custom-period budgets. Category-level and account-level budgets. Envelope, zero-based, and 50/30/20 templates. Rollover support. Aiko alerts at 50%, 75%, 90%, and 100% usage.

### 🎯 Financial Goals

SMART goals with target amount and date. Auto-calculated monthly contributions. Goal progress forecast and success probability via Monte Carlo simulations. Saving plans with milestone alerts.

### 📈 Insights & Predictions

Spending trends, cash flow analysis with Sankey diagrams, pace monitoring, leftover/safe-to-spend calculation. End-of-month forecasts, budget overrun prediction, net worth projection, and retirement readiness estimates.

### 🤖 Aiko AI Assistant

Natural-language chat for financial questions. Personalized spending insights, budget recommendations, debt payoff strategies, subscription cancellation suggestions, and monthly financial reviews.

### 💳 Credit Card & Debt Management

Credit card tracking with utilization, rewards, and due dates. Debt payoff plans using snowball or avalanche methods. Extra payment simulation with interest savings estimates.

### 📱 Portfolio & Assets

Investment holdings with performance charts, allocation analysis, dividends, and realized/unrealized gains. Asset allocation by class, currency, geography, and risk level. Net worth tracking with trend charts.

### 🧮 60+ Financial Calculators

Covering finance & investment, loans & mortgages, retirement, stocks & portfolio, credit cards, auto loans, tax & salary, business & accounting, and everyday tools. Save scenarios, compare side-by-side, and convert results into goals or plans.

### 🌍 Travel Mode

Multi-currency accounts, automatic exchange rate updates, travel budgets, foreign transaction fee tracking, and trip-based expense reports.

---

## Prediction and AI System

- Rule-based forecasting powers MVP predictions such as end-of-month balance, budget overrun risk, and goal completion.
- Moving averages track recurring expense trends.
- Seasonality detection identifies monthly spending patterns.
- Monte Carlo simulations support advanced goal and retirement probability.
- Scenario modeling supports optimistic, normal, and conservative outcomes.
- Prediction logic lives in `lib/core/prediction/`.
- AI suggestions are stored as `AikoInsight` records in Supabase.
- AI features must include disclaimers: Aiko provides estimates, not certified financial advice.

---

## Database Schema

The Supabase backend uses 17 core tables, all protected by Row Level Security:

| Table | Purpose |
| --- | --- |
| `profiles` | User profile, preferences, base currency |
| `accounts` | Financial accounts (cash, bank, e-wallet, credit card, loan, investment, asset) |
| `transactions` | All financial transactions (13 types) |
| `categories` | Hierarchical spending categories |
| `transaction_rules` | Auto-categorization rules |
| `budgets` | Budget definitions and alert thresholds |
| `goals` | Financial goals and progress tracking |
| `credit_cards` | Credit card details and metrics |
| `assets` | Asset records by class and risk level |
| `liabilities` | Debt and loan records |
| `investment_holdings` | Portfolio holdings and market values |
| `tax_records` | Tax-year income, deductions, documents |
| `subscriptions` | Recurring subscription tracking |
| `bills` | Recurring bill tracking |
| `saved_calculator_scenarios` | Saved calculator inputs and results |
| `aiko_insights` | AI-generated financial insights |
| `devices` | Registered devices for sync |

All tables enforce `user_id = auth.uid()` via RLS policies — users can only access their own data.

---

## Supabase Backend Rules

- Migrations live in `supabase/migrations/`. Never edit existing migrations; create new ones.
- All tables use Row Level Security. Users can only access rows where `user_id = auth.uid()`.
- Never put the Supabase service-role key in the mobile app, `.env`, dart-defines, or any client-visible config.
- Seed data in `supabase/seed.sql` is for development/demo only.
- Push migrations to cloud with `supabase link --project-ref <ref>` followed by `supabase db push`.

---

## Design System

### Color Palette

| Role | Color | Usage |
| --- | --- | --- |
| Primary Blue | `#3B82F6` | Main buttons, active tabs, highlights |
| Deep Blue | `#1D4ED8` | Header accents, important actions |
| Soft Blue | `#93C5FD` | Secondary highlights, empty states |
| Pale Blue | `#EFF6FF` | Light backgrounds, info cards |
| Dark Navy | `#0F172A` | Dark mode base, premium sections |
| Success Green | — | Savings, positive cash flow, completed goals |
| Warning Orange | — | Upcoming bills, budget caution |
| Danger Red | — | Overspending, overdue, high debt risk |
| Purple | — | Premium AI insights, optimization |
| Teal | — | Analytics, portfolio, cash flow |

### Themes

- **Light Mode:** White/soft-gray backgrounds, blue primary, pastel cards
- **Dark Mode:** Dark navy backgrounds, white text, blue highlights, soft glow on AI elements

### Aiko Character

Six expression variants: `happy`, `thinking`, `encouraging`, `warning`, `celebrating`, `welcome`.

**Placement principle:** *"Data first, Aiko enhanced."* — Aiko appears purposefully (welcome, insights, goals, reviews), never covering data or cluttering screens.

---

## Testing

### Unit Tests

```bash
flutter test
```

Covers: money types, formatters, prediction engine, data models, providers, transaction rules, feature gating, import/export parsers.

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

## Monetization

| Plan | Includes |
| --- | --- |
| **Free** | Manual tracking, basic categories & budgets, basic charts, limited calculators, CSV export, basic Aiko insights |
| **Premium** | Unlimited accounts, advanced reports, AI recommendations, forecasting, receipt OCR, credit card optimization, portfolio analytics, tax reports, PDF/Excel export, multi-device sync |
| **Pro** | Advanced accounting, business reports, invoices, multi-user access, advanced tax tools, estate planning, Monte Carlo simulations, API access |

---

## Development Roadmap

### Phase 1 — Foundation ✅

Aiko brand system, blue design system, authentication, onboarding, account and transaction tracking.

### Phase 2 — Core Finance ✅

Budgets, goals, saving plans, categories, transaction rules, dashboard, spending charts, monthly reports, CSV export.

### Phase 3 — Intelligence ✅

Aiko insights, spending analysis, cash flow, pace/leftover, prediction engine, Ask Aiko chat, Aiko Review.

### Phase 4 — Advanced Finance ✅

Credit cards, debt/loan management, payoff plans, bills/subscriptions, cancellation/bill-lowering, calculators.

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
7. Run all quality gates before submitting changes.
8. Follow Aiko's brand voice: warm, supportive, non-judgmental.

---

## License

This project is private and not published to pub.dev. See `pubspec.yaml` for details.

---

<p align="center">
  <em>Built with 💙 — Grow wealth with Aiko.</em>
</p>
