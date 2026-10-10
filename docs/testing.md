# Testing

Aiko tests **logic, not widgets**. Test services, `Money`/`Decimal` math, prediction, parsers, rules, repositories, providers, codecs and migrations. Don't add `testWidgets` / `pumpWidget` tests for screens; move the logic into a testable `*Service` or domain function and test that.

## Suites

| Suite | Command | Needs | Cases |
| --- | --- | --- | --- |
| Flutter unit tests | `flutter test` | Flutter | ~480 tests in `test/` |
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

Previews deploy in parallel. `main` deploys only after the Flutter and Firebase jobs pass. Until the `FIREBASE_PROJECT_ID` variable is set, every deploy job is skipped and CI runs only these checks ([Deployment](deployment.md)). Run the same commands locally before pushing.

## What is covered

### Flutter (`test/`)

| Area | Files | Checks |
| --- | --- | --- |
| Money and formatting | `test/core/money/`, `test/core/formatting/` | Decimal arithmetic, currency mismatch errors, FX service parsing and failures, locale formatting |
| Offline core | `test/core/offline/`, `test/core/storage/` | Anonymous IDs (a session ending elsewhere replaces the signed-in owner, an anonymous one is kept), claiming local data on sign-in in batches, cache-first read routing (`firestore_sync_state_test.dart`), file cache |
| Prediction | `test/core/prediction/monte_carlo_test.dart` | Probability and percentile behavior |
| Local schema | `test/brick/` | Codec round-trips (including `transfer_group_id` and negative adjustment amounts), migration chain integrity, fresh database, budget→category and goal→account migrations, template-ID repair, default clone serialization |
| App wiring | `test/app/` | Providers (deleting an account deletes its transactions, linked transfer legs saved and deleted together, saves that never flash a loading state, archived categories kept for lookups, the monthly report's month, one-pass balance reconcile and group ungrouping in `providers_ledger_writes_test.dart`), locale controller, theme mode; sign-out routing and which auth events reload data (`auth_session_routing_test.dart`); navigation (`aiko_navigation_test.dart`): bottom bar and sidebar list the same destinations, every destination and tool is a registered route, selected-entry and reset rules |
| Localization | `test/l10n/`, `test/theme/thai_font_test.dart`, `test/features/categories/category_names_test.dart` | Static scan for hard-coded user-facing strings; English and Thai ARB files have the same keys and placeholders, Thai is really Thai, every key is used; every enum value has distinct labels; built-in categories have Thai names; Android/iOS list the same languages; the Thai font is bundled ([Localization → Tests](localization.md#tests)) |
| Layout | `test/shared/layout/` | Breakpoints, content widths and Overview column split (`aiko_layout_test.dart`); a static scan fails if code bypasses `showAikoSheet`/`openAikoPage` or builds navigation chrome outside `lib/app/` (`adaptive_presentation_guard_test.dart`) |
| Accounts | `test/features/accounts/` | Validator rules, details JSON, shared-limit resolution, ledger balances and the Accounts summary (`account_balances_test.dart`), amount input parsing |
| Transactions | `test/features/transactions/` | Validation, inflow types and signed adjustments (`transaction_inflow_test.dart`), list totals without transfers and adjustments, amount input with commas, legacy opening-balance conversion, recurring projection anchored to the first date, month ranges, rule matching and rule labels, attachments, the base64 OCR request, OCR and voice parsing in English and Thai (Thai totals, day-first and Buddhist-era dates, plausible-date range, voice merchant boundaries), repository |
| Categories | `test/features/categories/` | Defaults and clone IDs, repository (clones keep their stored `created_at`), budget progress |
| Overview and dashboard | `test/features/overview/`, `test/features/dashboard/` | Safe-to-spend, cash flow, goal forecast (average monthly deposits, blockers), monthly report and its change colors, allocation, notifications and dismissals, daily spending reaction (including no income and nothing spent), credit-card amounts due and date-only due days, per-day activity buckets |
| Other features | `test/features/` (`aiko_assistant`, `aiko_character`, `investments`, `calculators`, `transaction_capture`, `travel_mode`, `settings`, `auth`, `onboarding`, `export`, `learning_hub`) | Financial context (built from loaded providers), SSE chat engine, chat controller (retry only when it can help, no empty bubbles), Rive runtime loading only when `aiko.riv` is bundled, allocation and tax rebalance, allocation in the base currency (holdings with no rate left out), price refresh (one call per symbol and currency, rate budget, only changed prices saved), calculator math and Thai tax rules, every calculator form computing from its starting values in both languages, bank SMS parsing (OTPs, amounts next to currency or keywords, nearest-keyword direction), the capture queue (bad messages dropped, a failed removal doesn't stop it, concurrent runs share one pass), travel state and trip spending, LINE error mapping, profile repository and `copyWith`, staged avatar changes, auth repository and the once-per-device defaults marker, default accounts seeded once per user, export CSV rows and statement, lesson progress |
| Platform and theme | `test/android/android_manifest_test.dart`, `test/theme/dark_theme_guard_test.dart`, `test/theme/aiko_status_colors_test.dart` | The release manifest declares the internet permission; a static scan fails if UI code hard-codes neutral `AikoColors` (`darkNavy`, `neutralInk`, `mutedText`, surfaces, borders, `appBackground`) instead of theme tokens; status text colors meet 4.5:1 on their panels |

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
| `firebase/test/rules.test.cjs` | Owner-only access and decimal-string validation; default category identity immutable while its budget stays editable, including a clone seeded without `created_at`; two clients see edits and hard deletes; offline writes replay after reconnect; Storage owner and content-type rules |
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
- **Manual layout check** for UI work: look at the screen at 390px and 1440px wide (browser dev tools, or a resized desktop window), including any panel or page it opens ([Web and mobile](design-system.md#web-and-mobile)).
