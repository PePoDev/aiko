# Aiko

Aiko is a Flutter personal finance mobile app for Android and iOS, backed by Supabase Cloud. The MVP includes secure onboarding, account and transaction tracking, budgets, goals, a Home dashboard, insights, reports, CSV export, Ask Aiko, and finance calculators.

## Stack

- Flutter and Dart for the mobile app.
- Supabase Cloud for auth, Postgres-backed user-owned financial data, storage, and RLS.
- Riverpod, GoRouter, secure storage, local authentication, fl_chart, csv, and decimal-safe money logic.

## Setup

```bash
flutter pub get
```

Create a local environment file from the sample values:

```bash
cp .env.example .env
```

Fill in your Supabase Cloud project values later:

```text
SUPABASE_URL=https://your-project-ref.supabase.co
SUPABASE_ANON_KEY=your-cloud-anon-key
AIKO_ENV=development
```

Never put a Supabase service-role key in the mobile app, `.env`, Flutter dart-defines, or any client-visible config.

## Supabase Cloud Schema

The repository keeps portable Supabase migrations under `supabase/migrations/`. After you create the Supabase Cloud project and install/login to the Supabase CLI, link the repo and push migrations:

```bash
supabase login
SUPABASE_PROJECT_REF=<your-project-ref> ./scripts/supabase_cloud_prepare.sh
```

You can also run the commands manually:

```bash
supabase link --project-ref <your-project-ref>
supabase db push
```

Seed data is in `supabase/seed.sql`; apply it only to a demo/development cloud project.

## Run The App

Pass Supabase Cloud credentials with dart defines:

```bash
flutter run -d android \
  --dart-define=SUPABASE_URL=https://your-project-ref.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<your-cloud-anon-key> \
  --dart-define=AIKO_ENV=development
```

Without both `SUPABASE_URL` and `SUPABASE_ANON_KEY`, the app skips Supabase initialization so tests and UI work can run before credentials are available.

## Quality Gates

```bash
dart format --set-exit-if-changed .
flutter analyze
flutter test
flutter test integration_test
```

Current local validation should use deterministic fakes and contract checks. Supabase Cloud credentialed smoke tests should be run after migrations are pushed to a non-production project.

See `specs/001-aiko-finance-app/` and `specs/002-aiko-product-expansion/` for Spec Kit artifacts, evidence notes, and release checklists.

## Product Expansion Roadmap

The `specs/002-aiko-product-expansion/` roadmap expands the MVP into the fuller Aiko product vision while keeping advanced modules progressively disclosed. Implemented roadmap slices include:

- Aiko character controls and data-first placement rules.
- Import, export, backup, and sensitivity warnings.
- Bills, subscriptions, notification scheduling, and lower-bill review surfaces.
- Credit cards, debt payoff planning, assets, net worth, portfolio allocation, tax, accounting, learning, travel, devices, Aiko Optimize, and subscription-plan surfaces.
- Supabase Cloud schema and RLS migrations for user-owned roadmap tables.

Run the quality gates above before treating an expansion slice as releasable.
