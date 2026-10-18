# Firebase development and migration

The web, Android and iOS apps use the same Firebase repositories, document codecs and domain logic. Local Emulator Suite replaces the previous Supabase/Docker backend. The hosted project is configured through CI; see [Deployment](deployment.md).

## Start locally

Use Flutter stable (≥ 3.44, Dart ≥ 3.12), Node 22+, Java 21+, then follow [Getting started](getting-started.md). Build the app before starting Hosting. `npm run firebase:start` imports `.firebase-data/` when present and exports it on graceful shutdown (Ctrl-C). Back up that directory if the local data matters. Do not commit it.

| Service | Local address |
| --- | --- |
| Web app / Hosting | http://localhost:8080 |
| Emulator UI | http://127.0.0.1:4000 |
| Auth | 127.0.0.1:9099 |
| Firestore | 127.0.0.1:8081 |
| Storage | 127.0.0.1:9199 |
| Functions | 127.0.0.1:5001 |

The project is `demo-aiko`. Email/password signup works without credentials or email delivery. Password reset links appear in the Auth emulator output. Use the same email/password on another browser or mobile build to share records. Real Google accounts require Firebase/Google provider configuration. Never point an emulator build at a production project.

Android emulators use `--dart-define=FIREBASE_EMULATOR_HOST=10.0.2.2`; iOS simulators on the host use `127.0.0.1`. Physical devices need the host LAN address in that define and the services' `host` values changed in `firebase.json` to that interface. These unauthenticated emulators are for trusted local development. Browser clients need localhost or HTTPS for secure storage; use localhost on the development machine. Mobile Firebase app IDs and public options are passed through the same `FIREBASE_*` defines documented in `.env.example`.

This workspace runs Alpine Linux inside Android/proot. Its JVM cannot allocate anonymous executable memory. The opt-in `AIKO_ANDROID_PROOT_JAVA=1 npm run firebase:start` compiles a process-scoped compatibility shim with `cc` (Alpine packages `gcc musl-dev`). Normal Linux/macOS/Windows setups do not need it. A low-memory JVM can use `JAVA_TOOL_OPTIONS='-Xmx512m -XX:+UseSerialGC'`.

## Shared state and platform features

Auth restores a persistent session. Finance documents use Firestore persistence and multi-tab browser support; collection listeners refresh providers for accounts, categories/budgets, transactions, holdings, profile/theme and preferences. Locale, Travel Mode trips/budgets/fees, transaction rules, lesson progress and notification dismissals also use Firestore; the lists change item by item, so edits made offline on two devices merge. Decimal amounts remain strings. Default taxonomy uses deterministic per-user IDs and creates missing records without resetting existing data. Same-document concurrent edits use the SDK's last-write-wins behavior.

SQLite holds guest and local-only records (`aiko_local.sqlite`) and durable file bytes with the upload queue (`aiko_files.sqlite`) on every platform. Signed-in finance reads use Firestore's cache, avoiding stale SQLite rows reappearing after remote deletion. Guest records are claimed at sign-in. Files saved offline stay on the device and upload through the app's own queue (`FileSyncQueue`) when the device is back online; Storage uploads are not part of the Firestore offline queue ([Architecture → Files](architecture.md#files)).

Browser export/download, file/image/PDF previews and file selection use bytes. Camera, microphone and share behavior depend on browser/device support. Android SMS/notification capture is native-only. Reminder dates sync, but OS notification delivery/scheduling and capture permissions belong to each device; the web does not schedule OS reminders. AI, LINE, OCR and price feeds require provider configuration below. Firebase requires iOS 15 or later; the Xcode deployment target is updated accordingly. Native binaries still require the Android/iOS toolchains for device verification.

## Server providers

`tool/run_emulators.sh` creates a gitignored `firebase/functions/.secret.local` from the example containing `local-unconfigured` placeholders. Configure only the providers you need and restart Functions:

- `AI_API_KEY`, `AI_MODEL`, `AI_BASE_URL`: OpenAI-compatible chat endpoint (base URL, not `/chat/completions`).
- `LINE_CHANNEL_SECRET`, `LINE_CHANNEL_ACCESS_TOKEN`: signed webhook and replies; the webhook must be reachable by LINE. Pairing stores a server-only LINE mapping, never Firebase refresh tokens.
- `OCR_API_URL`, `OCR_API_KEY`: authenticated HTTP OCR adapter.
- `MARKET_API_URL`, `MARKET_API_KEY`: authenticated HTTP price adapter.

The precise adapter request/response contracts are in `firebase/functions/src/index.ts`. Missing providers return an explicit unavailable error; local emulators do not supply AI or external APIs. No credentials are embedded in the web build. Production Secret Manager values and Functions deployment are set up in [Deployment](deployment.md#storage-and-functions).

## Import an existing export

`firebase/tools/import_legacy.cjs` is a dry-run-first import utility. No live Supabase database was supplied or migrated. Preserve a source backup and verify export counts before any production cutover. The input is a JSON file with `users`, `tables`, and `files`:

```json
{
  "users": [{"id":"original-auth-uid", "email":"person@example.com", "email_confirmed_at":"2026-01-01T00:00:00Z", "encrypted_password":"<bcrypt hash>"}],
  "tables": {
    "accounts": [{"id":"original-account-id", "user_id":"original-auth-uid", "name":"Cash", "type":"cash", "currency":"USD", "current_balance":"12.34"}]
  },
  "files": [{"path":"files/receipt.pdf", "destination":"users/original-auth-uid/receipts/receipt-id/receipt.pdf", "contentType":"application/pdf"}]
}
```

Include all original row fields in a real export. Supported tables are profiles, accounts, categories, category_groups, transactions, transaction_splits, investment_holdings and attachments. Export all decimal columns as strings and dates as ISO strings. IDs and references remain stable. Global category templates are omitted because the app supplies them. User-owned template clones are retained. Auth imports preserve BCRYPT passwords; existing login sessions are not transferable and users must sign in again. OAuth providers must be configured and linked again. Existing LINE links must be paired again; source refresh tokens are deliberately not imported.

Attachment metadata is rewritten to `users/{uid}/receipts/{id}/{file_name}`; export the corresponding bytes with a matching `files.destination`. Avatar files can include `profileId` to populate the imported profile's Firebase download URL. Old device paths and obsolete remote avatar URLs are cleared. Client-only rules/language can be set in the app after signing in; they were not source SQL tables.

```sh
node firebase/tools/import_legacy.cjs /path/to/export/export.json
# Apply first to emulators, using explicit targets:
GCLOUD_PROJECT=demo-aiko \
FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 \
FIRESTORE_EMULATOR_HOST=127.0.0.1:8081 \
FIREBASE_STORAGE_EMULATOR_HOST=127.0.0.1:9199 \
node firebase/tools/import_legacy.cjs /path/to/export/export.json --apply
```

Firestore writes are create-only so a retry cannot overwrite edited records. Review rejected Auth imports before retrying. Validate record/file counts, sign-in, per-user ownership, balances, attachments and category references against the source before configuring production clients. Keep the old source read-only during a coordinated cutover; this utility is not an ongoing bridge between backends.

## Verification

```sh
flutter analyze lib test
flutter test
npm --prefix firebase/functions test
npm run test:rules  # emulators must be running; separate demo-aiko-tests namespace
flutter build web --dart-define=FIREBASE_PROJECT_ID=demo-aiko \
  --dart-define=FIREBASE_EMULATOR_HOST=127.0.0.1
```

Tests cover owner isolation, immutable default taxonomy, decimal field validation, two-client updates/deletes, offline write replay, preference items merged from two offline clients, Storage ownership/content types, server financial tools and export conversion. Browser verification should include signup, creating a transaction, reload persistence, another signed-in client observing edits, an offline reload after `npm run web:precache`, and a narrow viewport.

On Alpine, SQLite FFI tests may need the system library (`sqlite-dev`) rather than the downloaded glibc binary. Temporarily configure `hooks.user_defines.sqlite3.source: system` in `pubspec.yaml` for that host. Do not change application dependencies for this test-machine limitation. Existing widget tests can require native Rive assets/platform support; the repository convention is to add logic tests only.
