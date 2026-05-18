# Android Build Result

Validation date: 2026-05-18

Command attempted:

```bash
flutter build apk --debug \
  --dart-define=SUPABASE_URL=http://127.0.0.1:54321 \
  --dart-define=SUPABASE_ANON_KEY=local-anon-key \
  --dart-define=APP_ENV=local
```

Result: blocked by environment.

Flutter output:

```text
[!] No Android SDK found. Try setting the ANDROID_HOME environment variable.
```

Next step: install Android SDK command-line tools or Android Studio, set `ANDROID_HOME`, accept licenses, then rerun the command.
