# Quickstart: Aiko Personal Finance App

## Prerequisites

- Flutter stable installed with Dart SDK.
- Android Studio or Android command-line tooling for Android builds.
- Xcode for iOS builds on macOS.
- A Supabase Cloud project for credentialed development and smoke testing.

## 1. Install App Dependencies

```bash
flutter pub get
```

## 2. Prepare Supabase Cloud

Create or choose a Supabase Cloud project. Keep the project URL and anon key private until you provide them through local environment files or Flutter dart defines.

Apply the repository migrations to a linked cloud project:

```bash
supabase login
SUPABASE_PROJECT_REF=<your-project-ref> ./scripts/supabase_cloud_prepare.sh
```

Seed data is available in `supabase/seed.sql`; apply it only to a demo/development cloud project. Never pass or commit a Supabase service-role key to the mobile app.

## 3. Run The App

Android:

```bash
flutter run -d android \
  --dart-define=SUPABASE_URL=https://your-project-ref.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<your-cloud-anon-key> \
  --dart-define=AIKO_ENV=development
```

iOS simulator:

```bash
flutter run -d ios \
  --dart-define=SUPABASE_URL=https://your-project-ref.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<your-cloud-anon-key> \
  --dart-define=AIKO_ENV=development
```

Without both Supabase dart defines, the app skips Supabase initialization so UI tests can run before credentials are available.

## 4. Quality Gates

Run formatting:

```bash
dart format --set-exit-if-changed .
```

Run static analysis:

```bash
flutter analyze
```

Run unit and widget tests:

```bash
flutter test
```

Run integration tests:

```bash
flutter test integration_test
```

Credentialed cloud smoke tests should run against a non-production Supabase Cloud project after migrations are pushed.

## 5. Manual Verification Checklist

- First launch shows Aiko branding and onboarding.
- User can sign up or sign in through Supabase Cloud Auth.
- User can complete onboarding with base currency, country, first account, AI consent, and security choice.
- User can add a transaction and see dashboard totals update.
- User can create a monthly budget and savings goal.
- User can view Aiko Insights and source explanations.
- User can run all six MVP calculators and save a scenario.
- User can export transactions to CSV.
- App lock behavior works after timeout or relaunch.
- Light and dark themes remain readable.
- Screen reader labels and dynamic text are usable on critical screens.

## 6. Supabase Cloud Production Notes

Before production release:

- Configure Supabase Auth redirect URLs, SMTP/email settings, storage buckets, and project API settings.
- Enable and verify Row Level Security on all user-owned tables.
- Confirm no service-role secret is present in mobile app bundles or logs.
- Configure project backups and perform restore drills appropriate to the chosen Supabase plan.
- Review database indexes for transaction search, dashboard summaries, and report generation.

## 7. Build Commands

Before release, compare the commands below against [release-gates.md](release-gates.md). Environment-blocked gates must keep their task IDs open and include the attempted command, blocker, and next required tooling in the linked evidence file.

Android release build:

```bash
flutter build apk --release \
  --dart-define=SUPABASE_URL=https://your-project-ref.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<your-cloud-anon-key>
```

iOS release build:

```bash
flutter build ios --release \
  --dart-define=SUPABASE_URL=https://your-project-ref.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<your-cloud-anon-key>
```

Signing, app identifiers, deep links, notification entitlements, and store metadata must be configured before store submission.
