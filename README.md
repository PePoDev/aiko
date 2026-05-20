# Aiko — Personal Finance Management App

<p align="center">
  <strong>AI-powered personal finance, guided by Aiko.</strong><br/>
  Track money · Budget · Save · Invest · Plan — with a friendly AI companion.
</p>

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
|---|---|
| Mobile App | Flutter & Dart (SDK ^3.11.5) |
| State Management | Riverpod |
| Navigation | GoRouter |
| Backend | Supabase Cloud (Auth, Postgres, Storage, RLS) |
| Money Arithmetic | `decimal` (no floating-point errors) |
| Charts | `fl_chart` |
| Security | `flutter_secure_storage`, `local_auth` (PIN + biometric) |
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

### 2. Configure Environment

Copy the example env file and fill in your Supabase credentials:

```bash
cp .env.example .env
```

Edit `.env`:

```
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

> Without `SUPABASE_URL` and `SUPABASE_ANON_KEY`, the app skips Supabase initialization, allowing tests and UI work to run without backend credentials.

---

## Project Structure

```
lib/
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

## Database Schema

The Supabase backend uses 17 core tables, all protected by Row Level Security:

| Table | Purpose |
|---|---|
| `users_profile` | User profile, preferences, base currency |
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

## Design System

### Color Palette

| Role | Color | Usage |
|---|---|---|
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
dart format --set-exit-if-changed .
flutter analyze
flutter test
flutter test integration_test
```

---

## Monetization

| Plan | Includes |
|---|---|
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
- Receipt OCR with camera capture
- Advanced retirement planning
- Estate planning module
- Fully automated AI advisor
- API access for Pro users

---

## Contributing

1. Follow the architecture conventions documented in [`AGENTS.md`](AGENTS.md).
2. Use the `Money` type for all monetary values — never `double`.
3. Add RLS policies to all new Supabase tables.
4. Write unit tests for new models and providers.
5. Run all quality gates before submitting changes.
6. Follow Aiko's brand voice: warm, supportive, non-judgmental.

---

## License

This project is private and not published to pub.dev. See `pubspec.yaml` for details.

---

<p align="center">
  <em>Built with 💙 — Grow wealth with Aiko.</em>
</p>
