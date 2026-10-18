# Testing

Aiko tests **logic, not widgets**. Test services, `Money`/`Decimal` math, prediction, parsers, rules, repositories, providers, stores and codecs. Don't add `testWidgets` / `pumpWidget` tests for screens; move the logic into a testable `*Service` or domain function and test that.

## Suites

| Suite | Command | Needs | Cases |
| --- | --- | --- | --- |
| Flutter unit tests | `flutter test` | Flutter | ~940 tests in `test/` |
| Web service worker | `npm run test:web` | Node 22 | `tool/test/*.test.mjs`: `web/aiko_sw.js` in a VM with fake caches (`sw_harness.mjs`), and `tool/web_precache.mjs` |
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

The web build (`.github/workflows/deploy-web.yml`, for previews and the live site) runs `npm run test:web` right before `npm run web:precache`; a failure stops that deploy. Previews deploy in parallel. `main` deploys only after the Flutter and Firebase jobs pass. Until the `FIREBASE_PROJECT_ID` variable is set, every deploy job is skipped and CI runs only these checks ([Deployment](deployment.md)). Run the same commands locally before pushing.

## What is covered

### Flutter (`test/`)

| Area | Files | Checks |
| --- | --- | --- |
| Money and formatting | `test/core/money/`, `test/core/formatting/` | Decimal arithmetic, currency mismatch errors, FX service parsing and failures, saved rates, cross rates and session reuse (`exchange_rate_repository_test.dart`), locale formatting |
| Records | `test/core/offline/records/` | Existing documents of every collection read back unchanged (`record_codecs_test.dart`); round-trips of account details, budgets on categories, `transfer_group_id`, negative adjustments and tags; legacy NULLs |
| Offline store and sync | `test/core/offline/`, `test/core/storage/local_record_store_test.dart` | `OfflineStore` routing, owner checks, all-or-none batches, the 500-write limit and chunking, the no-wait hand-off and its error reporting, `localOnly` (`offline_store_test.dart`, with `fake_cloud_firestore`); `RecordQuery` sorting (`record_query_test.dart`); `LocalRecordStore` transactions and schema version; the one-time import of old Brick databases, run once, re-run after an interruption, failures that stop startup (`legacy_store_import_test.dart`); anonymous IDs (a session ending elsewhere replaces the signed-in owner, an anonymous one is kept); claiming guest data in batches, rejected chunks put back, budget-only writes on default clones, same-name merges and their budgets, budgets waiting only for the account they were meant for, attachments (`offline_data_migrator_test.dart`, `offline_data_migrator_files_test.dart`); offline read routing: shared deadline, server waits, a downloading listener (`firestore_sync_state_test.dart`). Shared harness: `record_store_harness.dart` |
| Preferences, files and status | `test/core/storage/`, `test/core/connectivity/`, `test/core/network/`, `test/core/notifications/` | Synced and itemized preferences: offline reads, device copies, merges, deferred changes (`synced_preferences_test.dart`, fake `offline_firestore.dart`); the file cache, its upgrades and trim (`local_file_cache_test.dart`); the upload queue: order, retries, failed jobs, sign-out, suspend, reconnect, cross-tab lock (`file_sync_queue_test.dart`, harness `file_store_harness.dart`); sync banner states and files waiting (`sync_status_test.dart`); which errors count as offline (`network_errors_test.dart`); reminders following remote changes (`reminder_follow_up_test.dart`) |
| Prediction | `test/core/prediction/monte_carlo_test.dart` | Probability and percentile behavior |
| App wiring | `test/app/` | Providers (deleting an account deletes its transactions, linked transfer legs saved and deleted together, saves that never flash a loading state, archived categories kept for lookups, the monthly report's month, one-pass balance reconcile and group ungrouping in `providers_ledger_writes_test.dart`); multi-document writes as one batch, and nothing written when one fails (`providers_atomic_writes_test.dart`); saved categories and groups shown although the store lags (`providers_category_saves_test.dart`); saved, live and retried exchange rates (`fx_rates_provider_test.dart`); which preference changes reload which providers (`firebase_sync_test.dart`); startup timeouts, retries and stuck starts (`startup_guard_test.dart`); locale controller (device language when storage fails), theme mode; sign-out and guest routing and which auth events reload data (`auth_session_routing_test.dart`); navigation (`aiko_navigation_test.dart`): bottom bar and sidebar list the same destinations, every destination and tool is a registered route, selected-entry and reset rules |
| Localization | `test/l10n/`, `test/theme/thai_font_test.dart`, `test/features/categories/category_names_test.dart` | Static scan for hard-coded user-facing strings; English and Thai ARB files have the same keys and placeholders, Thai is really Thai, every key is used; every enum value has distinct labels; built-in categories have Thai names; Android/iOS list the same languages; the Thai font is bundled ([Localization → Tests](localization.md#tests)) |
| Layout | `test/shared/layout/` | Breakpoints, content widths and Overview column split (`aiko_layout_test.dart`); a static scan fails if code bypasses `showAikoSheet`/`openAikoPage` or builds navigation chrome outside `lib/app/` (`adaptive_presentation_guard_test.dart`) |
| Accounts | `test/features/accounts/` | Validator rules, details JSON, shared-limit resolution, ledger balances and the Accounts summary (`account_balances_test.dart`), amount input parsing, repository saves staged in a batch (`data/account_repository_test.dart`) |
| Transactions | `test/features/transactions/` | Validation, inflow types and signed adjustments (`transaction_inflow_test.dart`), list totals without transfers and adjustments, amount input with commas, legacy opening-balance conversion, recurring projection anchored to the first date, month ranges, rule matching and rule labels, itemized rule storage (`transaction_rule_store_test.dart`), conversion-rate fill and rounding (`conversion_rate_fill_test.dart`), attachments: queued uploads, deletes, purges, sign-out, retries, guest claims (`transaction_attachment_repository_test.dart`), the base64 OCR request, OCR offline, local-only and guest results (`receipt_ocr_offline_test.dart`), OCR and voice parsing in English and Thai (Thai totals, day-first and Buddhist-era dates, plausible-date range, voice merchant boundaries), repository |
| Categories | `test/features/categories/` | Defaults and clone IDs, repository (clones keep their stored `created_at`, duplicate-name rule), budget progress |
| Overview and dashboard | `test/features/overview/`, `test/features/dashboard/` | Safe-to-spend, cash flow, goal forecast (average monthly deposits, blockers), monthly report and its change colors, allocation, notifications and dismissals, daily spending reaction (including no income and nothing spent), credit-card amounts due and date-only due days, per-day activity buckets |
| Other features | `test/features/` (`aiko_assistant`, `aiko_character`, `investments`, `calculators`, `transaction_capture`, `travel_mode`, `settings`, `auth`, `onboarding`, `export`, `learning_hub`) | Financial context (built from loaded providers), SSE chat engine (timeouts, offline and cut-off answers), chat controller (retry only when it can help, no empty bubbles, guests send nothing), Rive runtime loading only when `aiko.riv` is bundled, allocation and tax rebalance, allocation in the base currency (holdings with no rate left out and named), price refresh (one call per symbol and currency, rate budget, only changed prices saved, stops at a connection failure), holdings shown at once after a save or delete (`investments_notifier_test.dart`), calculator math and Thai tax rules, every calculator form computing from its starting values in both languages, bank SMS parsing (OTPs, amounts next to currency or keywords, nearest-keyword direction), auto-capture: the on-device inbox and background SMS (`capture_inbox_test.dart`), one write per run and kept queues on failure (`capture_processor_booking_test.dart`), repeats across channels, crash recovery and SMS dates (`captured_message_processor_test.dart`), travel state, trip spending and starting rates, LINE error mapping and remembered status, profile repository, stand-in profiles and `copyWith`, avatar uploads (`profile_avatar_service_test.dart`), auth: defaults seeding (`defaults_seeder_test.dart`), guest mode and its restart and session handling (`guest_mode_test.dart`), the unused guest Cash and Bank (`guest_defaults_test.dart`), guest preferences moved in and cleared (`guest_preferences_test.dart`), offline auth errors (`connection_errors_test.dart`), file jobs at log-out and deletion (`account_file_jobs_test.dart`), the once-per-device defaults marker, default accounts seeded once per user, export CSV rows and statement, lesson progress and dismissals merged across devices |
| Platform and theme | `test/android/android_manifest_test.dart`, `test/theme/latin_font_test.dart`, `test/theme/dark_theme_guard_test.dart`, `test/theme/aiko_status_colors_test.dart` | The release manifest declares the internet permission, Aiko's own notification listener and the SMS receiver disabled until capture starts; theme fonts load from bundled assets and carry their licenses; a static scan fails if UI code hard-codes neutral `AikoColors` (`darkNavy`, `neutralInk`, `mutedText`, surfaces, borders, `appBackground`) instead of theme tokens; status text colors meet 4.5:1 on their panels |

Widget tests that pump localized screens pass `localizationsDelegates: AppLocalizations.localizationsDelegates` and `supportedLocales` to `MaterialApp`.

Five older files still use `testWidgets`: `aiko_character_test.dart`, `inline_glossary_text_test.dart`, `learning_hub_screen_test.dart`, `aiko_assistant_screen_test.dart` and `aiko_spending_reaction_strip_test.dart`. Keep them passing, but don't add new widget tests.

### Backend

| File | Cases |
| --- | --- |
| `firebase/functions/test/chat_prompt.test.cjs` | The chat prompt follows the app language (Thai or English reply and disclaimer) and mirrors the user without one (LINE) |
| `firebase/functions/test/chat_answer.test.cjs` | A message needing no tool costs one provider call; a round's tool calls all run; all-tool rounds fall back to a streamed answer; failures reach the client only as `PROVIDER_DOWN`/`STREAM_FAILED`; stalled bodies and streams are cut off; a client already gone costs no call; answer chunks rejoin exactly |
| `firebase/functions/test/http.test.cjs` | CORS preflights carry `Max-Age`; receipt images arrive as base64 and are size-checked after decoding; integer arrays from older apps are still accepted; the OCR provider request is unchanged |
| `firebase/functions/test/finance_tools.test.cjs` | Cash flow keeps decimal precision and separate currencies; tools reject unknown names and malformed date ranges |
| `firebase/functions/test/import_legacy.test.cjs` | Import preserves IDs, references and decimal strings; rejects lossy numbers; never imports global templates |
| `firebase/test/rules.test.cjs` | Owner-only access and decimal-string validation; default category identity immutable while its budget stays editable, including a clone seeded without `created_at`; two clients see edits and hard deletes; offline writes replay after reconnect; preferences hold a `value` or an `items` map, and items changed on two offline clients both survive; Storage owner and content-type rules |
| `firebase/test/functions.test.cjs` | Privileged functions reject unauthenticated callers; account deletion removes only the caller's data and files |
| `firebase/test/finance_reads.test.cjs` | Ask Aiko tools read only the requested date range, referenced categories and newest rows, never re-read within a message, and reject bad ranges before reading (asserts billed document counts) |

## Writing tests

- **Pure services first.** Inject time (`asOf`) and data; services must not read Riverpod or the clock themselves. See `test/features/overview/budget_insights_service_test.dart`.
- **Money.** Build values with `Money.parse('12.34', 'THB')`; compare `Money`, never doubles.
- **Repositories and stores.** Use `openMemoryRecordStore()`, `FixedUserContext` and `RecordingStore` from `test/core/offline/record_store_harness.dart` (an in-memory `LocalRecordStore` through `sqflite_common_ffi`), `fake_cloud_firestore` for signed-in paths, `test/core/storage/file_store_harness.dart` for files, and `MemorySecureStorageService` for secure storage.
- **Providers.** Use a `ProviderContainer` with overrides (for example `exchangeRateServiceProvider`) so tests never hit the network.
- **Record changes.** Add a codec round-trip test in `test/core/offline/records/` and keep `record_codecs_test.dart` green; a local-store layout change also needs an upgrade test ([Data model](data-model.md#local-record-store)).
- **Rules changes.** Add allow and deny cases to `firebase/test/rules.test.cjs` and run the emulator suite.
- **Manual browser check** for sync work: sign up, add a transaction, reload, confirm a second signed-in browser sees the edit, then check a narrow viewport.
- **Manual offline check** for web loading: `flutter build web`, `npm run web:precache`, serve `build/web` (the Hosting emulator does), load the app once online, then go offline in dev tools and reload; add a transaction offline and check the banner and the upload when back online. Service-worker logic changes also need `npm run test:web`.
- **Manual layout check** for UI work: look at the screen at 390px and 1440px wide (browser dev tools, or a resized desktop window), including any panel or page it opens ([Web and mobile](design-system.md#web-and-mobile)).
