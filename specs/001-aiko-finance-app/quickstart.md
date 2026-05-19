# Quickstart: Aiko Personal Finance App

## Prerequisites

- Flutter stable installed with Dart SDK.
- Android Studio or Android command-line tooling for Android builds.
- Xcode for iOS builds on macOS.
- Docker-compatible container runtime for self-hosted Supabase.

## 1. Install App Dependencies

```bash
flutter pub get
```

## 2. Start Self-Hosted Supabase

Create a local self-hosted environment file:

```bash
cp supabase/self-hosted.env.example supabase/self-hosted.env
```

Start the Docker Compose stack:

```bash
docker compose --env-file supabase/self-hosted.env up -d
```

Check service health:

```bash
docker compose --env-file supabase/self-hosted.env ps
```

The stack exposes Kong on `http://localhost:8000`, Postgres on local port `54322`, and Supabase Studio through `http://localhost:8000`.

Use the `ANON_KEY` from `supabase/self-hosted.env` for local app runs. Never put `SERVICE_ROLE_KEY` in the mobile app.

Android emulator usually needs the host machine URL mapped through `10.0.2.2`. iOS simulator can usually use localhost. Physical devices need a reachable local network address or HTTPS development tunnel.

## 3. Run The App

Android:

```bash
flutter run -d android \
  --dart-define=SUPABASE_URL=http://<host-or-lan-ip>:8000 \
  --dart-define=SUPABASE_ANON_KEY=<anon-key-from-supabase/self-hosted.env> \
  --dart-define=APP_ENV=local
```

iOS simulator:

```bash
flutter run -d ios \
  --dart-define=SUPABASE_URL=http://127.0.0.1:8000 \
  --dart-define=SUPABASE_ANON_KEY=<anon-key-from-supabase/self-hosted.env> \
  --dart-define=APP_ENV=local
```

Never pass or commit a Supabase service-role key to the mobile app.

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

Run integration tests after the local Supabase stack is available and seeded:

```bash
flutter test integration_test
```

Current local validation on 2026-05-18 in the WSL/Linux workspace:

- `dart format --set-exit-if-changed .` passed.
- `flutter analyze` passed with no issues.
- `flutter test` passed with 34 unit/widget tests.
- `flutter test integration_test` was attempted, but Flutter selected the Linux desktop target and failed before loading tests because CMake is not installed.
- `flutter build apk --debug --dart-define=SUPABASE_URL=http://127.0.0.1:54321 --dart-define=SUPABASE_ANON_KEY=local-anon-key --dart-define=APP_ENV=local` was attempted and failed because no Android SDK/`ANDROID_HOME` is available.
- iOS build validation must run on macOS with Xcode; this Linux toolchain exposes no iOS build subcommand.

## 5. Manual Verification Checklist

- First launch shows Aiko branding and onboarding.
- User can sign up or sign in through local Supabase Auth.
- User can complete onboarding with base currency, country, first account, AI consent, and security choice.
- User can add a transaction and see dashboard totals update.
- User can create a monthly budget and savings goal.
- User can view Aiko Insights and source explanations.
- User can run all six MVP calculators and save a scenario.
- User can export transactions to CSV.
- App lock behavior works after timeout or relaunch.
- Light and dark themes remain readable.
- Screen reader labels and dynamic text are usable on critical screens.

## 6. Production Self-Hosted Supabase Notes

Before production release:

- Use the official self-hosted Docker Compose deployment path, not the local CLI stack.
- Configure HTTPS, reverse proxy, secrets, SMTP, auth redirect URLs, and storage limits.
- Enable and verify Row Level Security on all user-owned tables.
- Confirm no service-role secret is present in mobile app bundles or logs.
- Configure backups and perform restore drills.
- Configure monitoring, logs, service restart policy, and update process.
- Review database indexes for transaction search, dashboard summaries, and report generation.

## 7. Build Commands

Before release, compare the commands below against [release-gates.md](release-gates.md). Environment-blocked gates must keep their task IDs open and include the attempted command, blocker, and next required tooling in the linked evidence file.

Android release build:

```bash
flutter build apk --release \
  --dart-define=SUPABASE_URL=<production-url> \
  --dart-define=SUPABASE_ANON_KEY=<production-anon-key>
```

iOS release build:

```bash
flutter build ios --release \
  --dart-define=SUPABASE_URL=<production-url> \
  --dart-define=SUPABASE_ANON_KEY=<production-anon-key>
```

Signing, app identifiers, deep links, notification entitlements, and store metadata must be configured before store submission.
