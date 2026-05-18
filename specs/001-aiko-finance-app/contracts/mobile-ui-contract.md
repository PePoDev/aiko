# Contract: Mobile UI And Navigation

## Purpose

Define the first-release Flutter UI contract for Android and iOS.

## App Shell

Bottom navigation contains:

1. Home
2. Transactions
3. Budget
4. Insights
5. Aiko

More and Settings provide secondary modules:

- Accounts
- Categories
- Transaction Rules
- Goals
- Reports
- Calculators
- Export
- Security
- AI Consent
- Theme
- Help and Support

## Required Screen States

Every primary screen must define:

- Loading state.
- Empty state.
- Success state.
- Validation error state.
- Permission denied state.
- Offline or server unavailable state.
- Sensitive-data disclaimer state when applicable.
- Locked state for protected financial content.

## First-Release Screens

### Splash

Shows Aiko brand, blue visual identity, and transition to authenticated, unauthenticated, locked, or onboarding route.

### Login / Sign Up

Supports account creation, sign in, reset password entry point, and secure error copy.

### Onboarding

Collects:

- Financial focus.
- Base currency and country.
- First account.
- Category template.
- First budget or goal.
- AI consent.
- PIN or biometric preference.

### Home

Shows:

- Aiko welcome card.
- Net worth when data exists.
- Total cash.
- Monthly spending and income.
- Budget status.
- Pace.
- Leftover / safe-to-spend.
- Upcoming bills when available.
- Credit card due dates when available.
- Goal progress.
- Aiko suggestions.
- Recent transactions.
- Quick add.
- Calculator shortcuts.

### Transactions

Supports transaction list, search, filters, calendar/date grouping, quick add, edit, split, duplicate, receipt attachment when enabled, and rule creation entry point.

### Budget

Supports monthly budget overview, category budget cards, threshold alerts, pace, leftover, Aiko recommendation, create/edit budget, and goal creation entry point.

### Goals

Supports goal list, saving plan, progress, required contribution, target date forecast, chance-of-success placeholder, and Aiko coaching entry point.

### Insights

Supports spending analysis, income versus expense, category trends, Aiko insights, Aiko Review, reports, export, and period comparison entry points.

### Aiko

Supports Ask Aiko, suggested questions, recommendations, monthly review entry point, plan optimization placeholder, education suggestions, source explanations, and disclaimers.

### Calculators

Supports search, categories, recently used calculators, saved scenarios, and six MVP calculators:

- Compound interest.
- Loan.
- Credit card payoff.
- Savings goal.
- ROI.
- Currency converter.

### Settings

Supports profile, security, currency, categories, notifications, import/export, data backup, AI consent, connected devices placeholder, travel mode placeholder, subscription plan placeholder, help, and support.

## Theme Contract

- Primary blue: `#3B82F6`.
- Deep blue: `#1D4ED8`.
- Soft blue: `#93C5FD`.
- Pale blue: `#EFF6FF`.
- Dark navy: `#0F172A`.
- Success, warning, danger, purple, and teal are semantic support colors only.
- Light and dark themes must keep financial numbers readable.
- Aiko character visuals must be purposeful and hideable.

## Accessibility Contract

- All controls have semantic labels.
- Icon-only controls include tooltips or accessible names.
- Minimum touch targets match mobile accessibility expectations.
- Focus order follows visual order.
- Dynamic text does not clip critical numbers or controls.
- Color is never the only status indicator.
- Contrast remains readable in light and dark themes.

## Copy Contract

Aiko tone is:

- Warm.
- Clear.
- Supportive.
- Non-judgmental.
- Practical.

Avoid shame-based language. Warnings should explain the issue and provide a next step.

## Performance Contract

- First visible screen should appear without avoidable blocking work.
- Dashboard summary should avoid per-transaction recomputation in widget build methods.
- Transaction list uses pagination or incremental loading.
- Search/filter input is debounced.
- Charts render only the visible scope and avoid blocking interactions.
