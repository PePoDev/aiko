# iOS Build Result

Validation date: 2026-05-18

Result: blocked by environment.

This workspace is Linux/WSL. The local Flutter toolchain lists Android, Linux, and web build subcommands, but no iOS build subcommand. iOS validation requires macOS with Xcode and iOS signing configuration.

Expected command on macOS:

```bash
flutter build ios \
  --dart-define=SUPABASE_URL=<production-url> \
  --dart-define=SUPABASE_ANON_KEY=<production-anon-key> \
  --dart-define=APP_ENV=production
```
