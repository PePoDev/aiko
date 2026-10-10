# Testing

Aiko tests **logic, not widgets**. Test services, `Money`/`Decimal` math, prediction, parsers, rules, repositories, providers, codecs and migrations. Don't add `testWidgets` / `pumpWidget` tests for screens; move the logic into a testable `*Service` or domain function and test that.

## Suites

| Suite | Command | Needs | Cases |
| --- | --- | --- | --- |
| Flutter unit tests | `flutter test` | Flutter | ~200 tests in `test/` |
| Functions unit tests | `npm --prefix firebase/functions test` | Node 22 | Builds the Functions, then runs `firebase/functions/test/*.cjs` |
| Rules and Functions emulator tests | `npx firebase emulators:exec --project demo-aiko --only auth,firestore,storage,functions "npm run test:rules"` | Node 22, Java 21, built Functions, `firebase/functions/.secret.local` | `firebase/test/*.cjs` |
| Format | `dart format --output=none --set-exit-if-changed lib test` | Flutter | |
| Static analysis | `flutter analyze lib test` | Flutter | Lints in `analysis_options.yaml` |
| Web build | `flutter build web` | Flutter | Compiles the release bundle |
| Docs links | `npm run docs:check` | Node 22 | Links, `#anchors` and file paths in `docs/` resolve (`tool/check_docs.mjs`) |

`npm run test:rules` alone expects emulators already running (for example via `npm run firebase:start`). The rules tests use the `demo-aiko-tests` project, so they don't touch your local data. The functions tests use `demo-aiko`.

## Continuous integration

`.github/workflows/ci.yml` runs on every push to any branch:

| Job | Runs |
| --- | --- |
| Flutter checks | format, analyze, `flutter test` |
| Firebase rules and functions | Functions unit tests, then the emulator suite through `emulators:exec` |
| Docs links | `npm run docs:check`; reported on every push but does not block deploys |

Previews deploy in parallel. `main` deploys only after the Flutter and Firebase jobs pass ([Deployment](deployment.md)). Run the same commands locally before pushing.

## What is covered

### Flutter (`test/`)

| Area | Files | Checks |
| --- | --- | --- |
| Money and formatting | `test/core/money/`, `test/core/formatting/` | Decimal arithmetic, currency mismatch errors, FX service parsing and failures, locale formatting |
| Offline core | `test/core/offline/`, `test/core/storage/` | Anonymous IDs, claiming local data on sign-in, cache-first read routing (`firestore_sync_state_test.dart`), file cache |
| Prediction | `test/core/prediction/monte_carlo_test.dart` | Probability and percentile behavior |
| Local schema | `test/brick/` | Codec round-trips, migration chain integrity, fresh database, budget→category and goal→account migrations, template-ID repair, default clone serialization |
| App wiring | `test/app/` | Providers, navigation items, locale controller, theme mode |
| Accounts | `test/features/accounts/` | Validator rules, details JSON, shared-limit resolution |
| Transactions | `test/features/transactions/` | Validation, transfer balance math, recurring projection, month ranges, rule matching, attachments, OCR and voice parsing, repository |
| Categories | `test/features/categories/` | Defaults and clone IDs, repository, budget progress |
| Overview and dashboard | `test/features/overview/`, `test/features/dashboard/` | Safe-to-spend, cash flow, goal forecast, monthly report, allocation, notifications, daily spending reaction |
| Other features | `test/features/` (`aiko_assistant`, `investments`, `calculators`, `transaction_capture`, `travel_mode`, `settings`, `auth`) | Financial context, SSE chat engine, allocation and tax rebalance, calculator math, bank SMS parsing, travel state, profile repository, auth repository and the once-per-device defaults marker |
| Platform and theme | `test/android/android_manifest_test.dart`, `test/theme/dark_theme_guard_test.dart` | The release manifest declares the internet permission; a static scan fails if UI code hard-codes neutral `AikoColors` (`darkNavy`, `neutralInk`, `mutedText`, surfaces, borders, `appBackground`) instead of theme tokens |

Five older files still use `testWidgets`: `aiko_character_test.dart`, `inline_glossary_text_test.dart`, `learning_hub_screen_test.dart`, `aiko_assistant_screen_test.dart` and `aiko_spending_reaction_strip_test.dart`. Keep them passing, but don't add new widget tests.

### Backend

| File | Cases |
| --- | --- |
| `firebase/functions/test/finance_tools.test.cjs` | Cash flow keeps decimal precision and separate currencies; tools reject unknown names and malformed date ranges |
| `firebase/functions/test/import_legacy.test.cjs` | Import preserves IDs, references and decimal strings; rejects lossy numbers; never imports global templates |
| `firebase/test/rules.test.cjs` | Owner-only access and decimal-string validation; default category identity immutable while its budget stays editable; two clients see edits and hard deletes; offline writes replay after reconnect; Storage owner and content-type rules |
| `firebase/test/functions.test.cjs` | Privileged functions reject unauthenticated callers; account deletion removes only the caller's data and files |
| `firebase/test/finance_reads.test.cjs` | Ask Aiko tools read only the requested date range, referenced categories and newest rows, never re-read within a message, and reject bad ranges before reading (asserts billed document counts) |

## Writing tests

- **Pure services first.** Inject time (`asOf`) and data; services must not read Riverpod or the clock themselves. See `test/features/overview/budget_insights_service_test.dart`.
- **Money.** Build values with `Money.parse('12.34', 'THB')`; compare `Money`, never doubles.
- **Repositories.** Pass a fake `OfflineStore` and `OfflineUserContext`, and use `MemorySecureStorageService` for secure storage.
- **Providers.** Use a `ProviderContainer` with overrides (for example `exchangeRateServiceProvider`) so tests never hit the network.
- **Schema changes.** Add a codec round-trip test and keep `brick_migration_integrity_test.dart` green ([Data model](data-model.md#local-sqlite-schema)).
- **Rules changes.** Add allow and deny cases to `firebase/test/rules.test.cjs` and run the emulator suite.
- **Manual browser check** for sync work: sign up, add a transaction, reload, confirm a second signed-in browser sees the edit, then check a narrow viewport.
