# Aiko

Aiko is a Flutter personal finance mobile app for Android and iOS, backed by a self-hosted Supabase stack. The MVP includes secure onboarding, account and transaction tracking, budgets, goals, a Home dashboard, insights, reports, CSV export, Ask Aiko, and six finance calculators.

## Stack

- Flutter and Dart for the mobile app.
- Supabase self-hosted/PostgreSQL for auth, user-owned financial data, storage, and RLS.
- Riverpod, GoRouter, secure storage, local authentication, fl_chart, csv, and decimal-safe money logic.

## Setup

```bash
flutter pub get
```

Create a local environment from the sample values:

```bash
cp .env.example .env
```

Start the self-hosted Supabase Docker stack:

```bash
cp supabase/self-hosted.env.example supabase/self-hosted.env
docker compose --env-file supabase/self-hosted.env up -d
docker compose --env-file supabase/self-hosted.env ps
```

Supabase Studio is available at `http://localhost:8000` through Kong. The default local dashboard credentials are in `supabase/self-hosted.env`; change them before sharing the stack.

Run the app with dart defines. Android emulators usually need `10.0.2.2`; a wireless physical Android phone needs a LAN-reachable WSL/host IP instead.

```bash
flutter run -d android \
  --dart-define=SUPABASE_URL=http://<host-or-lan-ip>:8000 \
  --dart-define=SUPABASE_ANON_KEY=<anon-key-from-supabase/self-hosted.env> \
  --dart-define=APP_ENV=local
```

Never put a Supabase service-role key in the mobile app.

## Quality Gates

```bash
dart format --set-exit-if-changed .
flutter analyze
flutter test
flutter test integration_test
```

Current local validation:

- `dart format --set-exit-if-changed .`: passed.
- `flutter analyze`: passed.
- `flutter test`: passed, 34 tests.
- `flutter test integration_test`: blocked in this WSL environment because Flutter selected Linux desktop and CMake is not installed.
- `flutter build apk --debug ...`: blocked because no Android SDK/`ANDROID_HOME` is available.
- iOS build validation requires macOS/Xcode; this Linux Flutter toolchain does not expose an iOS build command.

See `specs/001-aiko-finance-app/` for the Spec Kit artifacts, evidence notes, and release checklists.
