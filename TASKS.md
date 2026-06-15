# Aiko — Task Plan

A prioritized, low-risk list of improvements for the Aiko Flutter codebase. Read this top to bottom; do it in order; stop after each phase and re-evaluate. Every task is small enough to be one PR. The goal is **simpler, cleaner, easier-to-read** code — not feature work.

> **Read first:** `README.md` (architecture, design system) and `AGENTS.md` (conventions, known gaps).
> **Living document:** when a task is done, tick it (`- [x]`) and move on. Don't add new tasks here casually — discuss in the PR.

---

## Quick stats

| Metric | Value |
|---|---|
| Source files (`lib/`, hand-written) | ~230 |
| Test files (`test/`) | 89 |
| Largest file | `lib/features/transactions/presentation/transaction_form_screen.dart` (147 KB, ~4500 lines) |
| Second largest | `lib/features/dashboard/presentation/home_dashboard_screen.dart` (85 KB, ~2700 lines) |
| CI / quality gates | **None** — gates are documented but never run automatically |
| Known correctness gap | Offline providers in `lib/app/providers.dart` (README §"Known gap") |
| Known data hazard | Hand-patch in `lib/brick/adapters/offline_account_adapter.g.dart` (README §"Brick hand-patch") |

## Legend

- **P0** — ship-blocker: data loss, security risk, dead code, build break. Do first.
- **P1** — high value: real bugs, big perf wins, important UX, major cleanup.
- **P2** — quality: code health, accessibility, consistency.
- **P3** — polish: nits, ergonomics, nice-to-haves.

Tasks are grouped into **phases** for ordered execution. Within a phase, P-level is the tiebreaker.

---

## Phase 0 — Stop the bleeding (P0, do this week)

Small, surgical, low-risk. Nothing here changes behavior. Goal: remove the things that will silently corrupt data or make the codebase look bigger than it is.

- [ ] **T-001 Remove `client.auth.admin.deleteUser` call** (P0, security)
  - `lib/features/auth/data/auth_repository.dart:243` calls `client.auth.admin.deleteUser()` with the **anon** client — this will always fail at runtime. The fallback at line 245 only deletes the profile row, not the auth user.
  - Fix: drop the call; mark the profile `deleted_at` and sign out, or call a server-side function.
  - Verify: `flutter test` still passes; manual sign-in / sign-out still works.

- [ ] **T-002 Delete 11 dead DTO files** (P0, dead code)
  - Files: `account_dto.dart`, `account_details_dto.dart`, `budget_dto.dart`, `saved_calculator_scenario_dto.dart`, `category_dto.dart`, `credit_card_detail_dto.dart`, `goal_dto.dart`, `aiko_insight_dto.dart`, `profile_dto.dart`, `transaction_attachment_dto.dart`, `transaction_dto.dart`, `transaction_rule_dto.dart` (all under `lib/features/<name>/data/`).
  - They duplicate what `lib/brick/offline_model_mappers.dart` already does.
  - Also delete `test/features/accounts/data/account_dto_test.dart` and `account_details_dto_test.dart`.
  - Verify: `flutter analyze` and `flutter test` clean.

- [ ] **T-003 Delete `core/sync/multi_device_sync_service.dart`** (P0, dead code)
  - Whole file is a stub: 1500 ms `Future.delayed`, fake devices upsert, no callers. `syncNow`, `subscribeToChanges`, `resolveConflictLWW` are referenced by nothing.
  - `lib/core/sync/sync_state.dart` is also unreferenced — delete with it.
  - Verify: `flutter analyze` and `flutter test` clean.

- [ ] **T-004 Remove `_debugDumpSyncState` from `transaction_repository`** (P0, hot path)
  - `lib/features/transactions/data/transaction_repository.dart:37-75`. Comment says *"TEMPORARY diagnostic … Remove once the sync issue is resolved."* The sync issue is resolved (offline path works). It runs an 8-row `debugPrint` and a Supabase query on every `list()` call.
  - Fix: delete the method and its call site.
  - Verify: dashboard / list / detail screens still render.

- [ ] **T-005 Fix Brick `details_json` hand-patch properly** (P0, data hazard)
  - `lib/brick/adapters/offline_account_adapter.g.dart` is hand-edited. The README explains why and what the proper fix is.
  - Add migration: `update accounts set details_json = '{}' where details_json is null; alter table accounts alter column details_json set not null;`
  - Then run `dart run build_runner build` and remove the `HAND-PATCH` comment.
  - Verify: a fresh install + a legacy install both load accounts.

- [ ] **T-006 Add offline `try/catch` in app-wide providers** (P0, README-known gap)
  - README §"Known gap (offline, no Supabase config)" lists six providers that throw on fresh install: `accountsProvider`, `transactionsProvider`, `budgetsProvider`, `goalsProvider`, `dashboardSummaryProvider`, `dashboardDueItemsProvider` in `lib/app/providers.dart` (around lines 86, 313, 477, 523 and the dashboard summary/due-items providers).
  - Fix: wrap each `build()` in `try { ... } catch (e, st) { return const AsyncValue.error(...); }` and let the screen's `AikoScreenState.error` render. **Do not** return an empty list — the user is offline + secure-storage-OK, so empty is correct; user is offline + secure-storage-broken, so the error widget with a "Try again" is correct.
  - Verify: fresh install, no env vars → user sees a recoverable empty state, not a crash.

---

## Phase 1 — Architecture & sync correctness (P0–P1)

Now that dead code is gone, the architecture is honest. Phase 1 makes the model match the README and removes the worst sync hazards.

- [ ] **T-101 Add missing sync fields to Brick models** (P0, README-vs-code drift)
  - The README says every syncable model has `id, user_id, created_at, updated_at, deleted_at, version`. The Brick models don't.
  - Files: `lib/brick/models/{account,transaction,budget,category,goal,profile,investment_holding}.model.dart`.
  - Add `updatedAt`, `deletedAt`, `version` to each. `OfflineStore.delete` (lib/brick/repository.dart:102) must set `deletedAt`, not hard-delete. Run `dart run build_runner build` and add a migration.
  - Update `lib/brick/offline_model_mappers.dart` to surface the fields on the domain models.
  - Verify: a Brick sync cycle (offline delete → online reopen) leaves the row in place with `deleted_at` set, not missing.

- [ ] **T-102 Move `supabaseConfigProvider` to `lib/app/providers.dart`** (P1, architecture)
  - `lib/features/aiko_assistant/application/aiko_chat_controller.dart:329-338` re-defines a top-level provider for `String.fromEnvironment('SUPABASE_URL')`. The single source of truth is `AikoSupabase` in `lib/core/supabase/`.
  - Fix: delete the local `_SupabaseConfig` and provider; add `supabaseConfigProvider` to `lib/app/providers.dart` and have the chat controller read it.
  - Verify: chat still functions with and without Supabase env vars.

- [ ] **T-103 Replace `String _type` with the `TransactionType` enum in `transaction_form_screen.dart`** (P1, type safety)
  - The form represents the transaction type as a `String` ('expense' / 'income' / 'transfer') and converts at the boundary. Easy to typo, hard to exhaustively switch.
  - Fix: introduce a local `_type` of type `TransactionType`; convert at the Supabase / Brick boundary only.
  - Verify: the form still saves a transaction and the list still filters by type.

- [ ] **T-104 Move `_supportedCurrencies` to a single home** (P1, consistency)
  - The list `['THB', 'USD', 'EUR', ...]` is duplicated in `transaction_form_screen.dart:26` and probably elsewhere.
  - Fix: move to `lib/core/money/supported_currencies.dart` as a `const` list. Use it everywhere.
  - Verify: the currency picker shows the same list in every entry point.

- [ ] **T-105 Wire `Result<T>` (or delete it)** (P1, README-vs-code drift)
  - `lib/core/errors/result.dart` and `lib/core/errors/app_failure.dart` define a sealed `Result<T>` / `AppFailureKind` taxonomy. **Nothing in `lib/` calls them.**
  - Decide: adopt or delete. Recommendation: delete — the existing `try / catch (_) → []` pattern is well-understood across the codebase, and adopting `Result` is a 200+-file refactor.
  - Verify: `flutter analyze` clean either way.

- [ ] **T-106 Stop mixing `double` and `Decimal` in the prediction engine** (P1, README rule)
  - The README says "never use `double` for amounts." `lib/core/prediction/monte_carlo_engine.dart`, `prediction_result.dart`, `prediction_service.dart` and `home_dashboard_screen.dart:1359-1361` all round-trip through `double` (`amount.toDouble()`, then back).
  - Pick one: (a) `Decimal` end-to-end (preferred), or (b) keep `double` and rename every `expectedValue` / `baseline` to make the units explicit. Either is fine; the current mix is the worst option.
  - Verify: existing Monte Carlo / forecast tests still pass.

- [ ] **T-107 Fix `InvestmentHolding.quantity: double` → `Decimal`** (P1, README rule)
  - `lib/features/investments/domain/investment_holding.dart:23,32,35` stores `quantity` as `double` and then `Decimal.parse('$quantity')` to do the math. The whole point of the `Money` wrapper is to skip this round-trip.
  - Fix: `Decimal quantity;`; fix the mappers in `lib/brick/offline_model_mappers.dart` and the storage column. Add a migration.
  - Verify: market value calculation matches the existing test output.

- [ ] **T-108 Extract auth post-signin orchestration out of `auth_repository`** (P1, layering)
  - `lib/features/auth/data/auth_repository.dart:132-208` (`_prepareOfflineDataForSync`) imports three brick-layer modules and orchestrates offline data migration. The auth repo should call a helper, not do it.
  - Fix: move `_prepareOfflineDataForSync` to `lib/core/sync/post_signin_data_preparer.dart` (or a method on `OfflineDataMigrator`); have the auth repo call it.
  - Verify: post-signin offline data still migrates; existing auth tests pass.

- [ ] **T-109 Stop hard-coding `'USD'` / `'THB'` in multiple places** (P1, bug magnet)
  - Onboarding says `'USD'` (`lib/features/onboarding/presentation/onboarding_screens.dart:31`), auth says `'THB'` (`lib/features/auth/data/auth_repository.dart:288-289`), profile repo says `'THB'`. The dashboard hard-codes USD three times (lines 1182, 1366, 1404).
  - Fix: one `defaultBaseCurrency` and one `defaultCountry` constant in `lib/core/config/app_config.dart`. Read from there. Use `profile.baseCurrency` everywhere a currency symbol is formatted.
  - Verify: a profile with `baseCurrency = EUR` shows EUR in the dashboard.

---

## Phase 2 — Break up the two monster files (P1)

The single biggest readability win. Both files mix real data, fake placeholders, helpers, and presentation in one place. After this phase, every "where does X come from?" question is answered in <100 lines.

- [ ] **T-201 Split `home_dashboard_screen.dart` into one widget per file** (P1, readability)
  - File is 2702 lines. Has **fake panels** (`_TotalDebtPanel`, `_DebtBreakdownPanel`, `_TaxLiabilityPanel`, `_TaxBreakdownPanel`, `_TopDeductionsPanel`, `_NetWorthTrendPanel`, `_CashFlowMappingPanel`, `_MockGoalSimulationCard`) with hard-coded `'$47,250.00'`-style numbers, and **real panels** mixed in.
  - Steps:
    1. Delete the fake debt / tax / mock-goal panels (or guard them behind `kDebugMode` + an explicit "EXAMPLE" badge).
    2. Move `_NetWorthTrendPanel` (and the hard-coded `[80, 82, …, 148]` data) to a real-data version or remove until data is available.
    3. Split remaining panels into `lib/features/dashboard/presentation/widgets/this_month_overview.dart`, `cash_flow_panel.dart`, `aiko_goal_simulator_panel.dart`, `net_worth_panel.dart`, `daily_spending_panel.dart`, `safe_this_week_panel.dart`, `daily_summary_panel.dart`, `net_earnings_panel.dart`, `category_budgets_panel.dart`, `spending_calendar_panel.dart`, `due_items_panel.dart`, `aiko_welcome_panel.dart`.
    4. Centralize `NumberFormat.simpleCurrency(...)` into a `currencyFormatter(profile)` helper in `lib/core/formatting/`.
  - Verify: dashboard renders identically; existing `home_dashboard_widget_test.dart` still passes.

- [ ] **T-202 Split `transaction_form_screen.dart` into one file per step** (P1, readability)
  - File is 4524 lines with hard-coded currencies, the `_type` string, the `tryClient` debug-print, and 16+ inlined sub-widgets.
  - Steps:
    1. Extract sub-widgets: `_AmountInput`, `_TypeSegmented`, `_CategoryPickerSheet`, `_AccountPickerSheet`, `_DateAndRecurrenceRow`, `_TagEditor`, `_SplitEditor`, `_CurrencyConversionPrompt`, `_ReceiptSection` (already exists as `transaction_attachment_section.dart`).
    2. Replace the `String _type` field with `TransactionType _type` (ties in with T-103).
    3. Move `_supportedCurrencies` to `lib/core/money/supported_currencies.dart` (ties in with T-104).
    4. Replace `debugPrint` at line 1300-1302 (offline attachment metadata bypass) with a real result, or surface the error.
  - Verify: form still saves, edits, and renders the same fields.

- [ ] **T-203 Split `category_editor_sheet.dart` (591 lines) and `category_group_editor_sheet.dart`** (P1, readability)
  - The icon grid, color palette, group picker, and type selector can each be a small file.
  - Verify: editor still saves.

- [ ] **T-204 Delete placeholder forms or implement them** (P0, dead code)
  - `lib/features/transactions/presentation/transaction_split_editor.dart:1-16` and `lib/features/goals/presentation/goal_form_screen.dart:1-16` are 16-line scaffolds with no submit and no validation.
  - Either implement them, or delete the routes that point at them and the README mentions.
  - Verify: no dead routes in `app_router.dart`.

---

## Phase 3 — Performance (P1)

The list is long but each item is small. Work through it feature by feature. Goal: when the user switches tabs, nothing recomputes; when they type in a search field, only the search field rebuilds.

- [ ] **T-301 Convert hot `setState(() {})` to focused state** (P1, jank)
  - The biggest offenders (per `grep setState(`):
    - `lib/features/aiko_assistant/presentation/aiko_assistant_screen.dart:228-230` — `onChanged: (_) => setState(() {})` on the chat input rebuilds the whole screen per keystroke. Replace with a `ValueListenableBuilder<TextEditingValue>` on the send button.
    - `lib/features/transactions/presentation/transaction_list_screen.dart:37-43, 69-73, 96-150` — every search keystroke triggers a full rebuild of all month pages. Move filter state into a `Notifier`, debounce 200 ms.
    - `lib/features/budgets/presentation/budget_form_screen.dart:739, 783-792` — `setState(() {})` in the allocator TextField. Use a `ValueNotifier` for the "remaining" total.
    - `lib/features/categories/presentation/category_group_editor_sheet.dart:76, 334, 414` — group-editor rebuilds for every color pick.
  - Verify: typing in the search field no longer re-runs the O(N) filter 30 times per second.

- [ ] **T-302 Replace `ListView(children: …)` with `ListView.builder` in the transaction list** (P1, frame cost)
  - `lib/features/transactions/presentation/transaction_list_screen.dart:571-595, 832-944`. Currently builds every `_CompactTransactionCard` eagerly, and each card is a `ConsumerWidget` that does an O(categories) `where` per render.
  - Fix: convert to `ListView.builder`; pre-resolve `Map<String, Category>` once in the parent; pass the resolved `Category?` to a plain `StatelessWidget` card.
  - Verify: 500+ transaction lists scroll smoothly; existing tests still pass.

- [ ] **T-303 Memoize the dashboard's per-day / per-category aggregations** (P1, frame cost)
  - `lib/features/dashboard/presentation/home_dashboard_screen.dart:2620-2660, 1792-1938, 1940-2070, 2072-2191, 2193-2304`. Each panel iterates the full transactions list and re-aggregates. After T-201, the four passes become a single derived `Map<DateTime, Money>` + `Map<String, Money>` per build.
  - Verify: `dashboardSummaryProvider` is the only place these are computed; panels consume pre-computed maps.

- [ ] **T-304 Cache `DateFormat` and `NumberFormat` as `static final`** (P1, allocations)
  - Hoist all `DateFormat('…')` and `NumberFormat.simpleCurrency(name: '…')` out of `build()` to file-level `static final` fields. Files with multiple offenders: `transaction_list_screen.dart`, `home_dashboard_screen.dart`, `transaction_form_screen.dart`, and the export feature.
  - Verify: no new `DateFormat` allocations per build.

- [ ] **T-305 Run Monte Carlo in a `FutureBuilder`, not in `build()`** (P1, frame cost)
  - `lib/features/dashboard/presentation/home_dashboard_screen.dart:1357-1365`. 1000 trials per build per goal on the UI thread.
  - Fix: move to an `AsyncValue` provider or a `FutureBuilder`; cache the result keyed by `(goalId, monthlyContribution, months)`.
  - Verify: the dashboard first paint is < 200 ms even with 5 active goals.

- [ ] **T-306 Parallelize the 3-await fanout in `DashboardRepository.loadSummary`** (P1, latency)
  - `lib/features/dashboard/data/dashboard_repository.dart:22-39`. Use `Future.wait` instead of three sequential `await`s.
  - Same fix in `lib/features/aiko_assistant/application/financial_context.dart:201-205` (5 awaits) and `lib/features/export/presentation/export_screen.dart:31-32`.
  - Verify: dashboard first paint is faster in the offline profiler.

- [ ] **T-307 Stop `setState(() asyncLoading())` on every save** (P1, skeleton flash)
  - `lib/app/providers.dart:491-499, 506-514` (BudgetsNotifier), and the same pattern in accounts/categories/goals/transactions. Every save forces consumers to re-render a full skeleton.
  - Fix: `state = AsyncValue<T>.loading().copyWithPrevious(state);` — keeps the previous data visible while the new value lands.
  - Verify: editing a budget doesn't flash a "no budgets" screen.

- [ ] **T-308 Hoist `GlobalKey`s out of `itemBuilder`** (P2, allocations)
  - `lib/features/transactions/presentation/transaction_form_screen.dart:2715-2724, 2322`. New `GlobalKey()` per section per build + post-frame registration. Move to state-level keys.

- [ ] **T-309 Hoist `Money.zero(currency)` and lookup maps out of loops** (P2, allocations)
  - `lib/features/dashboard/presentation/home_dashboard_screen.dart:984` and `lib/features/accounts/presentation/accounts_screen.dart:615` create `Money.zero(currency)` per account per build. Hoist into a `Map<String, Money> _zeroByCurrency` static.
  - Same for the O(categories) `where` in `_CompactTransactionCard` (already covered by T-302).

- [ ] **T-310 Wrap charts and animated backdrops in `RepaintBoundary`** (P2, paint invalidation)
  - `lib/shared/widgets/...` and the charts in `home_dashboard_screen.dart` (Sankey, bar chart, donut). The README design system says "use `RepaintBoundary`" — the codebase has zero today.

- [ ] **T-311 Cap `TabBarView` to a realistic month window** (P2, first build)
  - `lib/features/transactions/presentation/transaction_list_screen.dart:266-278` builds pages from `firstMonth.addMonths(-120)` to `lastMonth.addMonths(120)`. 241 month pages. Limit to last 12 + 1 forward.

---

## Phase 4 — UX, accessibility, and forms (P0–P1)

Many of these are quick wins that lift perceived quality a lot.

- [ ] **T-401 Wrap the transaction form in a `Form` with `TextFormField`s and inline `errorText`** (P0, README rule)
  - `lib/features/transactions/presentation/transaction_form_screen.dart:1049-1234` uses `TextField` + `ScaffoldMessenger.showSnackBar` for every error. The README mandates "form errors appear near the field."
  - Fix: convert to `Form` + `TextFormField` with `validator` and `errorText`; show a final submit-time summary at the bottom.
  - Verify: amount validation appears under the amount field, not as a snackbar.

- [ ] **T-402 Add `PopScope` to all form screens** (P0, data loss)
  - `transaction_form_screen.dart`, `budget_form_screen.dart`, `category_editor_sheet.dart`, `category_group_editor_sheet.dart`, `account_form_screen.dart`, `goal_form_screen.dart` (when implemented), `onboarding_screens.dart`. The user can swipe-back and lose work.
  - Fix: `PopScope(canPop: !isDirty, onPopInvoked: ...)` with a `showDialog<bool>` confirmation.

- [ ] **T-403 Add a loading spinner inside the save button during async submit** (P0, feedback)
  - `transaction_form_screen.dart:1643`, `budget_form_screen.dart`, `account_form_screen.dart`, `goal_form_screen.dart`. Button label only changes; no spinner. User can double-tap.
  - Fix: introduce a tiny `SubmitButton({label, busy, onPressed})` widget in `lib/shared/widgets/`. Use it everywhere.

- [ ] **T-404 Add `Semantics` + text summary to every chart** (P0, accessibility)
  - `home_dashboard_screen.dart:610-650` (bar chart), `_TaxBreakdownPanel` (donut), `_SankeyPainter`. The README says "every chart needs a text summary."
  - Fix: wrap each chart in `Semantics(label: 'Net worth trend, range 80 to 148, currently 148')`; render a one-line `Text` summary below the chart.
  - Verify: TalkBack reads the summary, not the raw values.

- [ ] **T-405 Add `excludeSemantics: true` to decorative Aiko artwork** (P1, accessibility)
  - `lib/features/aiko_character/presentation/aiko_avatar.dart:6-65`. Used decoratively in app bars and list rows. Add the flag where decorative.

- [ ] **T-406 Replace inline `CircularProgressIndicator` with `AikoScreenState.loading()`** (P1, consistency)
  - `transaction_form_screen.dart:1437, 1484`, `profile_screen.dart:179`, `investments_screen.dart:178`, `budget_form_screen.dart:858`. The shared widget is in `lib/shared/widgets/screen_states.dart`.

- [ ] **T-407 Use `TextFormField` + `validator` in every subform** (P1, form quality)
  - All `lib/features/accounts/presentation/account_form/subforms/*.dart` use raw `TextField` with no `errorText`, no `helperText`, no `keyboardType`. Add per-field validators and helper copy.

- [ ] **T-408 Confirm destructive actions on dashboard Edit mode** (P1, safety)
  - `home_dashboard_screen.dart:296-300` removes a widget without confirmation. Add a `showDialog<bool>`.

- [ ] **T-409 Add a "next action" button to every empty state** (P1, README rule)
  - `lib/features/dashboard/presentation/widgets/dashboard_empty_states.dart:10-14` has no action button. The README says "empty states teach the next action."
  - Fix: add "Add transaction" / "Connect account" / etc. depending on the empty state.

- [ ] **T-410 Add an empty-state action to category groups** (P2)
  - When a custom group has no categories, offer "Add a category."

- [ ] **T-411 Respect `MediaQuery.disableAnimations`** (P1, accessibility)
  - The codebase has no `disableAnimations` checks. Add a `kAikoAnimationsAllowed(BuildContext)` helper in `lib/shared/` and gate every `AnimatedContainer` / `TweenAnimationBuilder` on it. Files with motion: `aiko_assistant_screen.dart`, `onboarding_screens.dart`, `home_dashboard_screen.dart`, `category_management_screen.dart`.

- [ ] **T-412 Make `BudgetsNotifier` progress bar real** (P1, broken feature)
  - `lib/features/budgets/presentation/budget_overview_screen.dart:114-117` hard-codes `value: 0.0`. Compute `used / amount` from `transactionsProvider`; pair with text "X% used" (also fixes a color-only signal).

- [ ] **T-413 Add `Semantics` to color-coded status pills** (P2, accessibility)
  - `_probabilityColor` in `home_dashboard_screen.dart:1438-1441` is color-only. Pair with a "Likely" / "Possible" / "Unlikely" label.
  - Same pattern for `_FlowAmount` (1320-1336), `_CompactTransactionCard` income/expense accent, and `_AccountListItem` type tile.

- [ ] **T-414 Add a real `ColorScheme.tertiary` (AI/purple) token for dark mode** (P2, theme)
  - `aiko_semantic_colors.dart` defines tertiary, but several places hardcode `AikoColors.premiumPurple` in `build()` (e.g. `transaction_form_screen.dart:454, 460, 473, 705`). Use the theme token.

- [ ] **T-415 Wire the dashboard's hard-coded USD/THB panels to real data** (P0, README §"Placeholders" violation)
  - After T-201 splits the file, every panel should be data-driven. The README explicitly says: *"No fake finished dashboards. Prefer `AikoScreenState` or `AikoFeatureOverviewScreen`."*

- [ ] **T-416 Use locale-aware date and currency formatting** (P2, i18n)
  - `transaction_list_screen.dart:1037-1045` (hardcoded `'EEE, MMM d, yyyy'`), `transaction_form_screen.dart:1567` (hardcoded `'yyyy-MM-dd HH:mm'`), `accounts_screen.dart:535, 544, 696` (raw ISO date string), `home_dashboard_screen.dart:1182, 1366, 1404` (hardcoded `simpleCurrency(name: 'USD')`).
  - Fix: use `DateFormat.yMMMd(locale)` and `NumberFormat.simpleCurrency(locale: locale, name: profile.baseCurrency)`. Capture the locale once at the top of `build()` and pass it down.

---

## Phase 5 — Test infrastructure and coverage (P0–P2)

The README and AGENTS.md both list quality gates, but no CI runs them. This phase gets a real safety net in place.

- [ ] **T-501 Add GitHub Actions CI** (P0, governance)
  - Add `.github/workflows/ci.yml` running:
    - `dart format --set-exit-if-changed .`
    - `flutter analyze`
    - `flutter test`
    - `dart run build_runner build --delete-conflicting-outputs`
  - Optional second job (with secrets) for `flutter test integration_test`.
  - Verify: PRs without green CI cannot merge.

- [ ] **T-502 Replace `test/helpers/fake_repositories.dart` with a real fake** (P1, test infrastructure)
  - The current file is named `FakeRepositories` but instantiates the real repositories. Replace with a true in-memory fake (in-memory `OfflineStore`, deterministic `OfflineUserContext`).
  - Verify: widget tests can override `accountsProvider` / `transactionsProvider` / etc. with the fake.

- [ ] **T-503 Add a shared in-memory `OfflineStore` and a clock helper** (P1, test infrastructure)
  - Files: `test/helpers/in_memory_offline_store.dart`, `test/helpers/fixed_clock.dart`.
  - Every widget test today redefines `_FakeTransactionRepository`. After this, they all share the same in-memory store.

- [ ] **T-504 Add domain factories** (P2, test infrastructure)
  - `test/helpers/factories.dart` with `makeAccount({...})`, `makeTransaction({...})`, `makeCategory({...})`, `makeBudget({...})`, `makeGoal({...})`. Use in every new test.

- [ ] **T-505 Cover the modules that currently have zero tests** (P0, README mandate)
  - P0: `lib/core/offline/{offline_store,offline_user_context,offline_data_migrator}.dart`, `lib/features/insights/application/aiko_insight_service.dart`, `lib/features/debt_loans/application/debt_payoff_service.dart::simulatePayoff`, `lib/features/export/application/export_service.dart`, `lib/features/accounting/application/accounting_service.dart`, `lib/core/formatting/formatters.dart`.
  - P1: `lib/features/calculators/application/calculator_services.dart` (ruleOf72, NPV, tax-equivalent-yield, inflation-adjusted), `lib/features/budgets/application/budget_progress_service.dart` (50/75/90/100% thresholds), `lib/features/goals/application/goal_forecast_service.dart::successProbability`.
  - P2: `lib/core/money/money.dart` (times, dividedByInt, isNegative/Positive, format, JSON round-trip), `lib/core/prediction/monte_carlo_engine.dart` (10k-iter ordering, deterministic seed), `lib/core/security/app_lock_service.dart`.
  - Verify: `flutter test --coverage` shows the new lines are hit.

- [ ] **T-506 Replace weak bounds with exact assertions** (P2, regression detection)
  - `test/features/calculators/compound_savings_calculator_test.dart` uses `greaterThan(2200)` (actual is 2305.86). Use `closeTo(2305.86, 0.5)`.
  - `test/features/calculators/loan_credit_card_calculator_test.dart` uses `greaterThan(100)`. Use `closeTo(101.5, 0.5)` for principal 10000 / 12 mo / 1% APR.

- [ ] **T-507 Move real unit tests out of `integration_test/`** (P2, organization)
  - `integration_test/credit_debt_flow_test.dart` and `learning_sync_monetization_flow_test.dart` are unit tests in disguise. Move to `test/features/debt_loans/` and `test/features/learning_hub/`.
  - `integration_test/insights_export_flow_test.dart` is a placeholder (`find.byType(MaterialApp)`). Replace with a real offline integration test, or delete.

- [ ] **T-508 Replace `tester.pump(const Duration(seconds: 1))` with deterministic `pumpAndSettle`** (P2, flakiness)
  - `test/features/transactions/transaction_list_widget_test.dart:228-230` advances time by 1 s after every tap. Use a real `pumpAndSettle` with the actual animation duration.

- [ ] **T-509 Make `aiko_chat_controller` testable as a pure session object** (P2, decoupling)
  - Currently 264-line `Notifier` with stream + regex + supabase config + uuid + disclaimer logic. Split `AikoChatSession` (data) from `AikoChatController` (state + stream). Move `splitTrailingDisclaimer` to `lib/features/aiko_assistant/application/chat_disclaimer.dart`.

- [ ] **T-510 Write one regression test for the Brick hand-patch** (P2, defense-in-depth)
  - `test/brick/account_details_json_test.dart`: insert a row with `details_json = NULL`, read it back, assert no throw. Stops T-005 from being silently re-broken.

- [ ] **T-511 Document the test override patterns in `test/README.md`** (P3, ergonomics)

---

## Phase 6 — Code style and consistency (P2–P3)

After the big moves, polish. Goal: a new contributor can read any file and find the same patterns.

- [ ] **T-601 Document the Notifier / Service / Controller convention** (P2, consistency)
  - AGENTS.md should say: "Notifier = reactive state, Service = pure function, Controller = orchestrates state + UI side effects." Right now it's ad-hoc.

- [ ] **T-602 Use `Money.compareTo` instead of `==`** (P2, README rule)
  - `lib/features/dashboard/presentation/home_dashboard_screen.dart:495, 1005` and the two `==` on raw `Decimal`. Add `Money.isZero` getter; use it.

- [ ] **T-603 Add missing fields to `Transaction.copyWith` and `Budget.copyWith`** (P2, foot-gun)
  - `lib/features/transactions/domain/transaction.dart:130-158` and `lib/features/budgets/domain/budget.dart:53-79`. `accountId`, `date`, `note`, `alertThresholds` are not in the copyWith. Either add them or assert the constructor is exhaustive.

- [ ] **T-604 Promote `_localUserIdPrefix` to public** (P2, leaky private)
  - `lib/core/offline/offline_user_context.dart:11` is private; `lib/core/offline/offline_data_migrator.dart:28` re-declares its own copy. Promote to `OfflineUserContext.localUserIdPrefix`.

- [ ] **T-605 Derive `Locale` fallback from `AppLocalizations.supportedLocales`** (P3, consistency)
  - `lib/app/locale_controller.dart:40` hard-codes `Locale('th')`.

- [ ] **T-606 Stop hardcoding `'#3B82F6'` as a string** (P2, theme drift)
  - `lib/features/categories/domain/category_defaults.dart:435, 1119` and `lib/features/budgets/presentation/budget_form_screen.dart:100`. Either introduce a `ColorHex` value object, or add `kAikoPrimaryColorHex` to `lib/theme/aiko_colors.dart` and reference it.

- [ ] **T-607 Move `intl` import out of `Money`** (P2, layering)
  - `lib/core/money/money.dart:2` imports `package:intl/intl.dart` for `Money.format`. Move `format()` to a `MoneyFormatter` extension in `lib/core/formatting/`. The domain model should expose `amount.toString()` and `currency` only.

- [ ] **T-608 Add a `safeSetState` extension on `BuildContext`** (P3, ergonomics)
  - The pattern `if (mounted) setState(() { ... });` is duplicated 25+ times. Add a `context.safeSetState(VoidCallback)` in `lib/shared/extensions/build_context_x.dart`.

- [ ] **T-609 Promote `Money.dividedByInt` → use a new `Money.ratio` for ratios** (P3, type safety)
  - `lib/core/money/money.dart:31-41`. Callers in `home_dashboard_screen.dart:495-499` use it to compute a *ratio*, not split a value. Add a separate `Money.ratio(Money other) → double` and reserve `dividedByInt` for split-amount math.

- [ ] **T-610 Add `l10n/` to the project structure in the README** (P3, docs)
  - `lib/l10n/` is in the codebase but missing from README §"Project Structure".

- [ ] **T-611 Replace `magic 0.7` confidence with a named constant** (P3, naming)
  - `lib/features/insights/data/aiko_insight_repository.dart:76` uses `(row['confidence_score'] as num?)?.toDouble() ?? 0.7`. Move to `lib/core/prediction/advice_safety.dart` as `kDefaultConfidenceScore`.

- [ ] **T-612 Replace `String.fromEnvironment` twice with a single source** (P3, drift)
  - `lib/core/config/app_config.dart:9` and `lib/features/aiko_assistant/application/aiko_chat_controller.dart:336` both call `String.fromEnvironment('SUPABASE_URL')`. Add a derived `isSupabaseConfiguredProvider` in `lib/app/providers.dart`.

- [ ] **T-613 Scope the Brick sync logger listener to debug only** (P3, leak)
  - `lib/app/app_bootstrap.dart:30-35`. Listener is added on a global `Logger.root` and never removed.

- [ ] **T-614 Replace raw `int?` for recurring `dayOfWeek` / `dayOfMonth` / `monthOfYear` with value objects** (P3, type safety)
  - `lib/features/transactions/domain/transaction.dart:33-66`. A `RecurringSettings(dayOfWeek: 99)` compiles. Add a tiny sealed class or assert in the constructor.

- [ ] **T-615 Generate `category_defaults.dart` from JSON** (P3, maintainability)
  - `lib/features/categories/domain/category_defaults.dart` is 1209 lines of data. Either generate from `categories.json` via `build_runner`, or split into one file per `CategoryGroup` (13 files).

- [ ] **T-616 Add `lib/l10n/` to AGENTS.md "Code Conventions"** (P3, docs)

- [ ] **T-617 Centralize default `baseCurrency` and `country`** (P3, drift)
  - Onboarding says `'USD'`, auth says `'THB'`, profile repo says `'THB'`. Add `defaultBaseCurrency = 'USD'` and `defaultCountry = 'US'` to `lib/core/config/app_config.dart`.

---

## Phase 7 — Polish (P3)

For the days when the bigger items are done.

- [ ] **T-701 Add a `dashboardDefaultLayoutProvider`** so the static default doesn't silently replace user customizations.
- [ ] **T-702 Add a `ref.resetForTesting()` to the Brick singleton** (so widget tests don't keep stale config).
- [ ] **T-703 Add `firstOrNull` / `singleOrNull` lint** and refactor existing `try { ... } catch (StateError)` patterns.
- [ ] **T-704 Add `package:clock` (or a `Clock` interface) for `DateTime.now()` injection** in tests.
- [ ] **T-705 Document the `super.key` convention in AGENTS.md** — one pattern, enforced.
- [ ] **T-706 Add `prefer_const_constructors` lint pass** and replace remaining `const`-able widgets.
- [ ] **T-707 Replace `Material(color: ...)` plain backgrounds with `DecoratedBox`** where there's no `InkWell`.
- [ ] **T-708 Add `package:leak_tracker` to debug builds** to catch the disposed-but-still-listening patterns.
- [ ] **T-709 Document the icon set in `assets/icons/`** with one line per file (already required by tests; missing from README).

---

## How to read this file

- **Do phases in order.** Phase 0 is small and prevents data loss; do it today.
- **One task = one PR.** Keep diffs small. A reviewer should be able to read a single task in 5 minutes.
- **If a task grows past ~200 lines of diff**, it's a sign the task needs to be split further.
- **If you disagree with a task**, push back in the PR — don't silently skip it. This file is a plan, not a contract.
- **When the README or AGENTS.md contradicts the code**, fix the code (or surface the conflict). Don't amend the rules quietly.

See `README.md` for the high-level architecture and `AGENTS.md` for the day-to-day conventions.
