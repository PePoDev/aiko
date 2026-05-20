# AGENTS.md — Aiko Project Guide for AI Coding Agents

## Project Overview

Aiko is an AI-powered personal finance management mobile app built with Flutter and Dart, backed by Supabase Cloud. The app is branded around "Aiko," a cute anime-style AI girl with blue hair who serves as the user's financial companion. Aiko helps users track money, budget, set goals, manage debt, investments, taxes, and more — with friendly AI guidance.

**Platforms:** iOS and Android
**Primary Color:** Blue (#3B82F6)
**Brand Character:** Aiko — supportive, smart, calm, non-judgmental

---

## Tech Stack

| Layer | Technology |
|---|---|
| Framework | Flutter (Dart), SDK ^3.11.5 |
| State Management | Riverpod (`flutter_riverpod`) |
| Routing | GoRouter (`go_router`) |
| Backend | Supabase Cloud (Auth, Postgres, Storage, RLS) |
| Money Logic | `decimal` package for safe arithmetic, custom `Money` value type |
| Charts | `fl_chart` |
| Export | `csv`, `share_plus`, `path_provider` |
| Security | `flutter_secure_storage`, `local_auth` (PIN + biometric) |
| IDs | `uuid` |
| Formatting | `intl` (locale-aware dates, numbers, currencies) |

---

## Project Structure

```
lib/
├── main.dart                  # Entry point
├── app/                       # App-level wiring
│   ├── aiko_app.dart          # MaterialApp.router with Aiko theme
│   ├── app_bootstrap.dart     # Init: Supabase, secure storage, env config
│   ├── app_router.dart        # GoRouter — ALL routes defined here
│   ├── authenticated_shell.dart # Bottom nav scaffold (5 tabs)
│   └── providers.dart         # Top-level Riverpod providers
├── core/                      # Framework-level utilities (no UI)
│   ├── config/                # Env vars, app constants
│   ├── errors/                # Custom exceptions, error handler
│   ├── formatting/            # Currency, date, number formatters
│   ├── import_export/         # CSV/OFX/QIF parsers, export generators
│   ├── monetization/          # Feature gating (Free/Premium/Pro)
│   ├── money/                 # Money value type, currency definitions
│   ├── notifications/         # Local notification scheduling
│   ├── prediction/            # Forecasting, moving avg, Monte Carlo
│   ├── security/              # Biometric, PIN, encryption services
│   ├── storage/               # Local + secure key-value storage
│   ├── supabase/              # Supabase client init, provider
│   └── sync/                  # Multi-device sync, conflict resolution
├── features/                  # Feature modules (screen + logic + data)
│   ├── accounting/            # Chart of accounts, statements, journal
│   ├── accounts/              # Bank/cash/wallet/credit account CRUD
│   ├── aiko_assistant/        # Ask Aiko chat UI
│   ├── aiko_character/        # Aiko avatar widget, expressions
│   ├── aiko_optimize/         # AI-driven optimization suggestions
│   ├── assets/                # Asset CRUD, allocation, net worth
│   ├── auth/                  # Sign-up, sign-in, session management
│   ├── bills/                 # Bills, subscriptions, cancellation
│   ├── budgets/               # Budget CRUD, envelope/zero-based/50-30-20
│   ├── calculators/           # 60+ financial calculators
│   ├── categories/            # Category CRUD, subcategories, grouping
│   ├── credit_cards/          # Credit card management
│   ├── dashboard/             # Customizable home, drag-drop widgets
│   ├── debt_loans/            # Debt/loan tracking, payoff plans
│   ├── devices/               # Multi-device management
│   ├── export/                # Export service (CSV/PDF/Excel/JSON/Image)
│   ├── goals/                 # SMART goals, saving plans
│   ├── import_export/         # Import from CSV/Excel/OFX/QIF/statements
│   ├── insights/              # Spending analysis, cash flow, pace, leftover, Aiko Review
│   ├── learning_hub/          # PFM courses, lessons, quizzes
│   ├── monetization/          # Subscription plan UI, paywall
│   ├── onboarding/            # 10-step onboarding flow
│   ├── portfolio/             # Investment holdings, performance, watchlist
│   ├── reports/               # Report builder, 13+ report templates
│   ├── settings/              # All settings screens
│   ├── tax_center/            # Tax profile, deductions, analytics, docs
│   ├── transactions/          # Transaction CRUD, rules, search, split
│   └── travel_mode/           # Multi-currency, exchange rates, trip budgets
├── shared/                    # Cross-feature shared code
│   ├── state/                 # Global Riverpod state providers
│   ├── test_data/             # Deterministic fakes for tests/demo
│   └── widgets/               # Reusable UI components
└── theme/                     # Design system
    ├── aiko_colors.dart       # Blue palette + semantic colors
    ├── aiko_theme.dart        # ThemeData (light + dark)
    └── aiko_typography.dart   # Typography scale

supabase/
├── config.toml                # Supabase CLI project config
├── migrations/                # 18 Postgres migration files
│                              # Tables: users_profile, accounts, transactions,
│                              # categories, transaction_rules, budgets, goals,
│                              # credit_cards, assets, liabilities,
│                              # investment_holdings, tax_records, subscriptions,
│                              # saved_calculator_scenarios, aiko_insights,
│                              # bills, devices
│                              # + RLS policies, functions, triggers
├── seed.sql                   # Demo seed data (dev only)
└── storage/                   # Supabase Storage bucket configs

assets/
├── icons/                     # App icon assets
│   ├── app_icon.png
│   └── app_icon_foreground.png
└── images/aiko/               # Aiko character expressions
    ├── aiko_happy.png
    ├── aiko_thinking.png
    ├── aiko_encouraging.png
    ├── aiko_warning.png
    ├── aiko_celebrating.png
    └── aiko_welcome.png

test/                          # Unit tests (money, models, providers, rules, etc.)
integration_test/              # Integration tests (onboarding, CRUD flows, dashboard, calculators)
```

---

## Architecture Conventions

### Feature Module Pattern

Each feature under `lib/features/<name>/` follows a consistent structure:

```
<feature>/
├── <feature>_screen.dart       # Main screen widget
├── <feature>_model.dart        # Data model / entity
├── <feature>_provider.dart     # Riverpod providers (state + logic)
├── <feature>_repository.dart   # Supabase data access layer
├── widgets/                    # Feature-specific widgets (optional)
└── <sub_screen>.dart           # Additional screens (optional)
```

- **Screens** are Flutter widgets that compose UI. They consume providers via `ref.watch` / `ref.read`.
- **Providers** hold business logic. Use `StateNotifierProvider`, `FutureProvider`, or `NotifierProvider`.
- **Repositories** handle Supabase CRUD. They are injected via providers. All DB calls go through repositories — screens never call Supabase directly.
- **Models** are immutable Dart classes with `fromJson` / `toJson` for Supabase serialization.

### State Management Rules

- Use Riverpod for all state. No `setState` outside trivial local widget state (e.g., text field focus).
- Top-level providers live in `lib/app/providers.dart`.
- Feature-specific providers live in `lib/features/<name>/<name>_provider.dart`.
- Shared cross-feature state lives in `lib/shared/state/`.

### Routing Rules

- All routes are defined in `lib/app/app_router.dart` using GoRouter.
- Bottom navigation uses a `ShellRoute` with 5 tabs: Home, Transactions, Budget, Insights, Aiko.
- The "More" menu items route to feature screens as sub-routes.
- Route paths use kebab-case (e.g., `/credit-cards`, `/debt-loans`, `/tax-center`).

### Money and Currency Rules

- **Never use `double` for money.** Always use the `Money` type from `lib/core/money/money.dart`, which wraps `Decimal`.
- Currency formatting uses `lib/core/formatting/currency_formatter.dart` with locale-aware `intl`.
- The user's base currency is stored in their profile. Multi-currency is supported for travel mode and portfolio.

### Naming Conventions

- Files: `snake_case.dart`
- Classes: `PascalCase`
- Variables / functions: `camelCase`
- Route paths: `/kebab-case`
- Database tables: `snake_case`
- Database columns: `snake_case`
- Feature directories: `snake_case`

### Theme and Design System

- Primary color: Blue (#3B82F6). Full palette defined in `lib/theme/aiko_colors.dart`.
- Light and dark themes in `lib/theme/aiko_theme.dart`.
- Semantic colors: green (success/savings), orange (warning/bills), red (danger/overspending), purple (premium/AI), teal (analytics/portfolio).
- Card-based UI with rounded corners, soft backgrounds, clear hierarchy.
- Aiko character follows "Data first, Aiko enhanced" — never cover numbers/charts.

### Aiko Character Rules

- Aiko expressions are in `lib/features/aiko_character/`.
- Available expressions: `happy`, `thinking`, `encouraging`, `warning`, `celebrating`.
- Placement rules in `character_placement_rules.dart` — use Aiko purposefully (welcome, insights, goals, warnings, reviews), never on every screen.
- Aiko's voice is warm, supportive, non-judgmental. Never shame-based.

---

## Data Model Summary

Key Supabase tables (all protected by RLS — users only access their own data):

| Table | Purpose |
|---|---|
| `users_profile` | User profile, base currency, country, timezone, theme, Aiko settings |
| `accounts` | Financial accounts (cash, bank, e-wallet, credit card, loan, investment, asset) |
| `transactions` | All money movement (13 types: income, expense, transfer, refund, etc.) |
| `categories` | Hierarchical categories with icons, colors, budget links |
| `transaction_rules` | Auto-categorization rules (merchant, keyword, amount, account) |
| `budgets` | Category/account budgets with period, rollover, alert thresholds |
| `goals` | SMART financial goals with target, progress, probability |
| `credit_cards` | Credit card details, limits, APR, due dates, rewards |
| `assets` | Asset records by class, value, currency, liquidity, risk |
| `liabilities` | Debt records with balance, interest rate, payments |
| `investment_holdings` | Portfolio holdings with cost basis, current price, market value |
| `tax_records` | Tax-year income, deductions, documents |
| `subscriptions` | Recurring subscriptions with billing cycle, cancellation status |
| `bills` | Recurring bills with due dates, amounts |
| `saved_calculator_scenarios` | Saved calculator inputs/results |
| `aiko_insights` | AI-generated insights with type, confidence, recommendation |
| `devices` | Registered devices for multi-device sync |

---

## Prediction and AI System

- **Rule-based forecasting** for MVP predictions (end-of-month balance, budget overrun, goal completion).
- **Moving average** for recurring expense trends.
- **Seasonality detection** for monthly spending patterns.
- **Monte Carlo simulations** for advanced goal/retirement probability.
- **Scenario modeling**: optimistic, normal, conservative.
- All prediction logic lives in `lib/core/prediction/`.
- AI suggestions are generated as `AikoInsight` records stored in Supabase.
- AI features must include disclaimers — Aiko provides estimates, not certified financial advice.

---

## Monetization Tiers

| Tier | Access Level |
|---|---|
| **Free** | Manual tracking, basic categories, basic budgets, basic charts, limited calculators, CSV export, basic Aiko insights |
| **Premium** | Unlimited accounts, advanced reports, Aiko recommendations, forecasting, receipt OCR, credit card optimization, portfolio analytics, tax reports, PDF/Excel export, multi-device sync |
| **Pro** | Advanced accounting, business reports, invoices, multi-user, advanced tax tools, estate planning, Monte Carlo, API access |

Feature gating logic is in `lib/core/monetization/feature_gate.dart`.

---

## Testing Strategy

### Unit Tests (`test/`)

- Test money types, formatters, prediction engine.
- Test all data models (`fromJson` / `toJson` round-trip).
- Test providers with deterministic fake data from `lib/shared/test_data/`.
- Test transaction rules matching logic.
- Test feature gate tier logic.
- Test import parsers and export generators.

### Integration Tests (`integration_test/`)

- Onboarding flow completion.
- Transaction CRUD (create, edit, delete, filter).
- Budget creation and alert threshold behavior.
- Goal creation and progress tracking.
- Dashboard widget rendering and layout.
- Calculator hub navigation and scenario flow.

### Running Tests

```bash
flutter test                   # Unit tests
flutter test integration_test  # Integration tests
```

### Quality Gates (run before any PR or release)

```bash
dart format --set-exit-if-changed .
flutter analyze
flutter test
flutter test integration_test
```

---

## Supabase Backend Rules

- Migrations live in `supabase/migrations/`. Never edit existing migrations — create new ones.
- All tables use Row Level Security (RLS). Users can only access rows where `user_id = auth.uid()`.
- Never put the Supabase service-role key in the mobile app, `.env`, dart-defines, or any client-visible config.
- Seed data (`supabase/seed.sql`) is for development/demo only.
- Push migrations to cloud: `supabase link --project-ref <ref> && supabase db push`.

---

## Environment Configuration

The app reads environment variables from `.env` (local dev) and `--dart-define` flags (CI/build):

```
SUPABASE_URL=https://your-project-ref.supabase.co
SUPABASE_ANON_KEY=your-cloud-anon-key
AIKO_ENV=development
```

Without `SUPABASE_URL` and `SUPABASE_ANON_KEY`, the app skips Supabase initialization — useful for tests and UI-only work.

---

## Common Tasks

### Adding a New Feature Module

1. Create `lib/features/<name>/` with model, provider, repository, and screen files.
2. Add routes in `lib/app/app_router.dart`.
3. If the feature needs a Supabase table, create a new migration in `supabase/migrations/`.
4. Add RLS policies to the migration. Always filter by `auth.uid()`.
5. Register providers in `lib/app/providers.dart` if they need app-wide access.
6. Add unit tests in `test/` for the model and provider.
7. Use `Money` type for all monetary values — never `double`.
8. Follow the existing feature module pattern.

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

1. **Clarity first** — Financial data must be easy to understand.
2. **Data first, Aiko enhanced** — AI augments but never obscures financial data.
3. **Decimal-safe money** — Never use `double` for amounts.
4. **Privacy by design** — RLS on everything, encrypted storage, user consent for AI.
5. **Actionable insights** — Every insight should lead to a useful next step.
6. **Warm, non-judgmental tone** — Aiko encourages, never shames.
7. **Test before ship** — Run all quality gates before treating any change as releasable.
