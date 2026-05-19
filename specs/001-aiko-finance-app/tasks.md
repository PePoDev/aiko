# Tasks: Aiko Personal Finance App

**Input**: Design documents from `/specs/001-aiko-finance-app/`

**Prerequisites**: [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md), [data-model.md](data-model.md), [contracts/](contracts/), [quickstart.md](quickstart.md)

**Tests**: Test tasks are mandatory for this feature because the project constitution requires automated tests for observable behavior before implementation is considered complete.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2, US3, US4, US5, US6)
- Include exact file paths in descriptions

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Establish Flutter, Supabase, folder, asset, and test scaffolding used by all stories.

- [X] T001 Update Flutter dependencies for Supabase, routing, state, security, localization, charts, CSV, and integration tests in pubspec.yaml
- [X] T002 Create feature-first Flutter folder structure from plan.md in lib/app/, lib/core/, lib/features/, lib/shared/, lib/theme/, test/, and integration_test/
- [X] T003 [P] Create Aiko asset directories and placeholder README files in assets/images/aiko/README.md and assets/icons/README.md
- [X] T004 [P] Configure stricter lint and analyzer expectations for production code in analysis_options.yaml
- [X] T005 Initialize Supabase local project files in supabase/config.toml and supabase/seed.sql
- [X] T006 [P] Create app environment sample documenting SUPABASE_URL and SUPABASE_ANON_KEY in .env.example
- [X] T007 [P] Create shared test fixtures directory and fixture README in test/fixtures/README.md
- [X] T008 [P] Create integration test bootstrap placeholder in integration_test/app_test_bootstrap.dart
- [X] T009 Replace the starter counter entry point with Aiko bootstrap delegation in lib/main.dart
- [X] T010 Document setup assumptions and current target platforms in README.md

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that must be complete before any user story can be implemented.

**Critical**: No user story work can begin until this phase is complete.

- [X] T011 Create typed runtime configuration loader for Supabase URL, anon key, environment, and feature flags in lib/core/config/app_config.dart
- [X] T012 [P] Create reusable app failure and result types in lib/core/errors/app_failure.dart and lib/core/errors/result.dart
- [X] T013 [P] Create decimal-safe Money value object with currency validation and formatting hooks in lib/core/money/money.dart
- [X] T014 [P] Add unit tests for Money parsing, arithmetic, currency mismatch, and formatting in test/core/money/money_test.dart
- [X] T015 Create Supabase client provider and initialization wrapper with no service-role secret support in lib/core/supabase/supabase_client_provider.dart
- [X] T016 Create secure local storage abstraction for session and app-lock state in lib/core/storage/secure_storage_service.dart
- [X] T017 Create app-lock service interface and biometric adapter boundary in lib/core/security/app_lock_service.dart and lib/core/security/biometric_auth_adapter.dart
- [X] T018 [P] Create shared loading, empty, error, success, offline, permission-denied, locked, and disclaimer state widgets in lib/shared/widgets/screen_states.dart
- [X] T019 [P] Create shared finance card, primary button, icon tile, amount text, and form field widgets in lib/shared/widgets/
- [X] T020 [P] Create Aiko blue light/dark theme tokens, typography, and semantic colors in lib/theme/aiko_colors.dart, lib/theme/aiko_typography.dart, and lib/theme/aiko_theme.dart
- [X] T021 Create root Aiko app widget with theme, localization, routing shell, and ProviderScope in lib/app/aiko_app.dart
- [X] T022 Create app router with unauthenticated, onboarding, locked, and authenticated shell route groups in lib/app/app_router.dart
- [X] T023 Create app bootstrap coordinator for Supabase init, session restore, app lock state, and onboarding status in lib/app/app_bootstrap.dart
- [X] T024 [P] Add widget tests for shared screen states, theme contrast hooks, and dynamic text behavior in test/shared/widgets/screen_states_test.dart
- [X] T025 [P] Add widget tests for app router guards and locked/unauthenticated/onboarding routing in test/app/app_router_test.dart
- [X] T026 Create repository interface conventions and fake repository base helpers in lib/core/storage/repository.dart and test/helpers/fake_repositories.dart
- [X] T027 Create first Supabase migration for profiles, accounts, categories, transactions, splits, rules, budgets, goals, saving plans, dashboard preferences, insights, saved scenarios, reports, attachments, and notification preferences in supabase/migrations/001_initial_mvp_schema.sql
- [X] T028 Create Supabase RLS policies for all MVP user-owned tables in supabase/migrations/002_initial_mvp_rls.sql
- [X] T029 Create Supabase storage bucket and policy migration for receipts, documents, and exports in supabase/migrations/003_storage_buckets_and_policies.sql
- [X] T030 Add local seed data for one demo user profile, accounts, categories, budgets, goals, transactions, insights, and calculator scenarios in supabase/seed.sql
- [X] T031 [P] Add migration/RLS contract checks for user-owned tables and storage paths in test/core/supabase/supabase_contract_test.dart
- [X] T032 Create local development helper script for Supabase reset and Flutter test prerequisites in scripts/dev_local.sh

**Checkpoint**: Foundation ready; user story implementation can now begin.

---

## Phase 3: User Story 1 - Start Securely With Aiko (Priority: P1) MVP

**Goal**: A new user can sign up, meet Aiko, choose their financial focus, set currency/country, add a first account, configure security, and land on Home.

**Independent Test**: Complete onboarding from a fresh launch through first account creation and verify Home shows the first account, Aiko welcome, and protected-screen behavior.

### Tests for User Story 1

- [X] T033 [P] [US1] Add unit tests for auth session, onboarding state transitions, AI consent, and app-lock decisions in test/features/onboarding/onboarding_state_test.dart
- [X] T034 [P] [US1] Add unit tests for profile and first account validation in test/features/onboarding/onboarding_validation_test.dart
- [X] T035 [P] [US1] Add widget tests for splash, auth, Meet Aiko, focus, currency, first account, AI consent, and security setup screens in test/features/onboarding/onboarding_flow_widget_test.dart
- [X] T036 [P] [US1] Add widget tests for PIN/biometric lock, timeout, locked state, and recovery copy in test/features/auth/app_lock_widget_test.dart
- [X] T037 [US1] Add integration test for first launch to authenticated Home with local fake repositories in integration_test/onboarding_flow_test.dart

### Implementation for User Story 1

- [X] T038 [P] [US1] Create Profile domain model and DTO mapping in lib/features/settings/domain/profile.dart and lib/features/settings/data/profile_dto.dart
- [X] T039 [P] [US1] Create Account domain model for onboarding account creation in lib/features/accounts/domain/account.dart and lib/features/accounts/data/account_dto.dart
- [X] T040 [US1] Implement auth repository for sign up, sign in, sign out, reset password, and session restore in lib/features/auth/data/auth_repository.dart
- [X] T041 [US1] Implement profile repository for profile, onboarding status, theme, AI consent, and security preference in lib/features/settings/data/profile_repository.dart
- [X] T042 [US1] Implement account repository create/list/update/archive methods for onboarding in lib/features/accounts/data/account_repository.dart
- [X] T043 [US1] Implement onboarding controller for financial focus, currency/country, first account, AI consent, and security steps in lib/features/onboarding/application/onboarding_controller.dart
- [X] T044 [US1] Implement app-lock controller for PIN, biometric availability, timeout, and protected route decisions in lib/features/auth/application/app_lock_controller.dart
- [X] T045 [US1] Implement splash, login, sign-up, reset password, and locked screens in lib/features/auth/presentation/
- [X] T046 [US1] Implement Meet Aiko and onboarding step screens in lib/features/onboarding/presentation/
- [X] T047 [US1] Implement first account form and onboarding account summary components in lib/features/accounts/presentation/onboarding_account_form.dart
- [X] T048 [US1] Implement authenticated app shell with bottom navigation and initial Home placeholder in lib/app/authenticated_shell.dart and lib/features/dashboard/presentation/home_shell_placeholder.dart
- [X] T049 [US1] Add semantics labels, focus order, dynamic text handling, and accessible error copy to auth/onboarding screens in lib/features/auth/presentation/ and lib/features/onboarding/presentation/
- [ ] T050 [US1] Verify US1 performance budget and document results for first launch and onboarding completion in specs/001-aiko-finance-app/performance/us1-onboarding.md

**Checkpoint**: User Story 1 is functional and testable independently.

---

## Phase 4: User Story 2 - Track Everyday Money Movement (Priority: P1)

**Goal**: A user can create accounts/categories, add/edit/split/duplicate/search/filter/classify transactions, and apply basic transaction rules.

**Independent Test**: Create accounts and categories, add multiple transaction types, edit and split one transaction, filter the list, and verify account/category totals update.

### Tests for User Story 2

- [X] T051 [P] [US2] Add unit tests for transaction validation, signed amount rules, transfer rules, and split balancing in test/features/transactions/transaction_validation_test.dart
- [X] T052 [P] [US2] Add unit tests for category archive/merge/type restrictions in test/features/categories/category_rules_test.dart
- [X] T053 [P] [US2] Add unit tests for transaction rule condition matching, priority, preview, and bulk apply behavior in test/features/transactions/transaction_rule_engine_test.dart
- [X] T054 [P] [US2] Add widget tests for transaction list loading, empty, error, search, filter, and grouped states in test/features/transactions/transaction_list_widget_test.dart
- [X] T055 [P] [US2] Add widget tests for amount-first add/edit/split/duplicate transaction forms in test/features/transactions/transaction_form_widget_test.dart
- [X] T056 [US2] Add integration test for add expense, edit transaction, split transaction, and dashboard/account total update in integration_test/transaction_dashboard_flow_test.dart

### Implementation for User Story 2

- [X] T057 [P] [US2] Create Category domain model and DTO mapping in lib/features/categories/domain/category.dart and lib/features/categories/data/category_dto.dart
- [X] T058 [P] [US2] Create Transaction and TransactionSplit domain models and DTO mapping in lib/features/transactions/domain/transaction.dart and lib/features/transactions/data/transaction_dto.dart
- [X] T059 [P] [US2] Create TransactionRule domain model and DTO mapping in lib/features/transactions/domain/transaction_rule.dart and lib/features/transactions/data/transaction_rule_dto.dart
- [X] T060 [US2] Implement category repository and category service for default templates, custom categories, archive, merge, and type checks in lib/features/categories/data/category_repository.dart and lib/features/categories/application/category_service.dart
- [X] T061 [US2] Implement transaction repository with create, edit, archive, duplicate, search, filter, list, split, and balance-impact operations in lib/features/transactions/data/transaction_repository.dart
- [X] T062 [US2] Implement transaction rule engine and preview/apply service in lib/features/transactions/application/transaction_rule_engine.dart and lib/features/transactions/application/transaction_rule_service.dart
- [X] T063 [US2] Implement amount-first transaction add/edit flow with account/category/tag/merchant/note/date fields in lib/features/transactions/presentation/transaction_form_screen.dart
- [X] T064 [US2] Implement transaction split editor in lib/features/transactions/presentation/transaction_split_editor.dart
- [X] T065 [US2] Implement searchable/filterable transaction list with pagination and date/category/account grouping in lib/features/transactions/presentation/transaction_list_screen.dart
- [X] T066 [US2] Implement category management screen and category template picker in lib/features/categories/presentation/category_management_screen.dart
- [X] T067 [US2] Implement transaction rules list, editor, preview, conflict warning, and bulk-apply confirmation in lib/features/transactions/presentation/transaction_rules_screen.dart
- [X] T068 [US2] Wire Transactions navigation, quick add entry points, and account balance refresh into lib/app/app_router.dart and lib/features/transactions/presentation/
- [X] T069 [US2] Add semantics labels, dynamic text behavior, keyboard/focus handling, and accessible validation messages for transaction/category/rule screens in lib/features/transactions/presentation/ and lib/features/categories/presentation/
- [ ] T070 [US2] Verify transaction search/filter performance with 10,000 seeded transactions and document results in specs/001-aiko-finance-app/performance/us2-transactions.md

**Checkpoint**: User Story 2 is functional and testable independently.

---

## Phase 5: User Story 3 - Understand Today Through The Home Dashboard (Priority: P1)

**Goal**: A user can open Home and quickly understand net worth, cash, spending, income, budget status, pace, leftover, goals, Aiko suggestions, recent transactions, and next action.

**Independent Test**: Load a seeded user with accounts, transactions, budgets, goals, and bills, then verify each Home widget displays correct status and links to detail screens.

### Tests for User Story 3

- [X] T071 [P] [US3] Add unit tests for dashboard summary, net worth, total cash, spending, income, and recent transaction aggregation in test/features/dashboard/dashboard_summary_test.dart
- [X] T072 [P] [US3] Add unit tests for pace and leftover calculations with missing data, negative balance, and overspending cases in test/features/dashboard/pace_leftover_test.dart
- [X] T073 [P] [US3] Add unit tests for dashboard widget preference ordering, visibility, and sizing in test/features/dashboard/dashboard_preferences_test.dart
- [X] T074 [P] [US3] Add widget tests for Home loading, empty, populated, error, locked, and customized widget states in test/features/dashboard/home_dashboard_widget_test.dart
- [X] T075 [US3] Add integration test for seeded dashboard overview and widget deep links in integration_test/home_dashboard_flow_test.dart

### Implementation for User Story 3

- [X] T076 [P] [US3] Create DashboardSummary, PaceStatus, LeftoverSummary, and DashboardWidgetPreference models in lib/features/dashboard/domain/dashboard_summary.dart and lib/features/dashboard/domain/dashboard_widget_preference.dart
- [X] T077 [US3] Implement dashboard repository for summary reads, recent transactions, widget preferences, and cached aggregate loading in lib/features/dashboard/data/dashboard_repository.dart
- [X] T078 [US3] Implement dashboard summary service for net worth, cash, spending, income, pace, leftover, and next-action calculations in lib/features/dashboard/application/dashboard_summary_service.dart
- [X] T079 [US3] Implement Home dashboard screen and sections for Aiko welcome, cash, monthly spending, budget status, pace, leftover, goals, suggestions, recent transactions, and shortcuts in lib/features/dashboard/presentation/home_dashboard_screen.dart
- [X] T080 [US3] Implement dashboard customization sheet for hide/show/reorder/compact/expanded widgets in lib/features/dashboard/presentation/dashboard_customization_sheet.dart
- [X] T081 [US3] Implement dashboard widget components in lib/features/dashboard/presentation/widgets/
- [X] T082 [US3] Wire Home tab routing and deep links to Transactions, Budget, Goals, Insights, Aiko, and Calculators in lib/app/app_router.dart
- [X] T083 [US3] Add empty states and missing-data prompts for dashboard widgets in lib/features/dashboard/presentation/widgets/dashboard_empty_states.dart
- [X] T084 [US3] Add semantics labels, dynamic number wrapping, color-independent status indicators, and focus order for Home in lib/features/dashboard/presentation/home_dashboard_screen.dart
- [ ] T085 [US3] Verify Home startup, summary refresh, and scroll performance and document results in specs/001-aiko-finance-app/performance/us3-dashboard.md

**Checkpoint**: User Story 3 is functional and testable independently.

---

## Phase 6: User Story 4 - Plan Budgets, Goals, And Savings (Priority: P2)

**Goal**: A user can create monthly category budgets, financial goals, saving plans, and supportive alerts/recommendations.

**Independent Test**: Create category budgets and a savings goal, add spending and contributions, then verify progress, warnings, forecasts, and recommendations update.

### Tests for User Story 4

- [X] T086 [P] [US4] Add unit tests for budget period progress, thresholds, overspending, archived category behavior, and rollover placeholder behavior in test/features/budgets/budget_progress_test.dart
- [X] T087 [P] [US4] Add unit tests for goal contribution, forecast, completed, paused, impossible target, and passed-date states in test/features/goals/goal_forecast_test.dart
- [X] T088 [P] [US4] Add unit tests for saving plan milestone and contribution schedule calculations in test/features/goals/saving_plan_test.dart
- [X] T089 [P] [US4] Add widget tests for budget overview, budget form, goal overview, goal form, and saving plan states in test/features/budgets/budget_goal_widget_test.dart
- [X] T090 [US4] Add integration test for creating a monthly budget and savings goal from seeded categories/accounts in integration_test/budget_goal_flow_test.dart

### Implementation for User Story 4

- [X] T091 [P] [US4] Create Budget domain model and DTO mapping in lib/features/budgets/domain/budget.dart and lib/features/budgets/data/budget_dto.dart
- [X] T092 [P] [US4] Create Goal and SavingPlan domain models and DTO mapping in lib/features/goals/domain/goal.dart, lib/features/goals/domain/saving_plan.dart, and lib/features/goals/data/goal_dto.dart
- [X] T093 [US4] Implement budget repository and progress service for monthly category budgets, thresholds, status, and recommendations in lib/features/budgets/data/budget_repository.dart and lib/features/budgets/application/budget_progress_service.dart
- [X] T094 [US4] Implement goal repository and goal forecast service for target amount, target date, linked account, priority, current amount, and success placeholder in lib/features/goals/data/goal_repository.dart and lib/features/goals/application/goal_forecast_service.dart
- [X] T095 [US4] Implement saving plan service for weekly/monthly contribution targets, milestones, and forecasted completion in lib/features/goals/application/saving_plan_service.dart
- [X] T096 [US4] Implement Budget tab overview with category budget cards, threshold alerts, pace, leftover, and Aiko recommendation entry in lib/features/budgets/presentation/budget_overview_screen.dart
- [X] T097 [US4] Implement create/edit budget flow with category selection, amount, period, thresholds, and validation in lib/features/budgets/presentation/budget_form_screen.dart
- [X] T098 [US4] Implement Goals overview with progress, contribution, forecast, linked account, and status cards in lib/features/goals/presentation/goals_overview_screen.dart
- [X] T099 [US4] Implement create/edit goal and saving plan screens in lib/features/goals/presentation/goal_form_screen.dart and lib/features/goals/presentation/saving_plan_screen.dart
- [X] T100 [US4] Wire Budget and Goals routes plus Home dashboard refresh hooks in lib/app/app_router.dart and lib/features/dashboard/application/dashboard_summary_service.dart
- [X] T101 [US4] Add accessible progress indicators, threshold copy, dynamic text handling, and non-judgmental Aiko messages in lib/features/budgets/presentation/ and lib/features/goals/presentation/
- [ ] T102 [US4] Verify budget/goal calculation and screen performance and document results in specs/001-aiko-finance-app/performance/us4-budget-goals.md

**Checkpoint**: User Story 4 is functional and testable independently.

---

## Phase 7: User Story 5 - Review Insights, Reports, And Exports (Priority: P2)

**Goal**: A user can review spending insights, monthly reports, Aiko Review, and export selected financial data.

**Independent Test**: Add representative transactions and budgets, generate monthly review, view charts, expand insight source data, and export filtered transactions.

### Tests for User Story 5

- [X] T103 [P] [US5] Add unit tests for spending trend, income-vs-expense, category breakdown, and monthly report aggregation in test/features/reports/report_aggregation_test.dart
- [X] T104 [P] [US5] Add unit tests for Aiko insight source summaries, confidence, dismiss, feedback, and consent gating in test/features/insights/aiko_insight_test.dart
- [X] T105 [P] [US5] Add unit tests for CSV export scope, date filters, amount/currency columns, and sensitive-data confirmation in test/features/export/csv_export_test.dart
- [X] T106 [P] [US5] Add widget tests for Insights screen, Aiko Review, source explanation, report shortcuts, and export confirmation states in test/features/insights/insights_widget_test.dart
- [X] T107 [US5] Add integration test for monthly Aiko Review generation and CSV export with seeded finance data in integration_test/insights_export_flow_test.dart

### Implementation for User Story 5

- [X] T108 [P] [US5] Create AikoInsight and Report domain models and DTO mapping in lib/features/insights/domain/aiko_insight.dart, lib/features/reports/domain/report.dart, and lib/features/insights/data/aiko_insight_dto.dart
- [X] T109 [US5] Implement insight repository for list, view, dismiss, rate, apply, and consent-filtered reads in lib/features/insights/data/aiko_insight_repository.dart
- [X] T110 [US5] Implement deterministic insight generation service for spending increase, budget threshold, pace, leftover, goal contribution, and missing-data prompts in lib/features/insights/application/aiko_insight_service.dart
- [X] T111 [US5] Implement report aggregation service for monthly summary, category trends, income-vs-expense, cash flow summary, and Aiko Review action items in lib/features/reports/application/report_service.dart
- [X] T112 [US5] Implement export service for filtered transaction CSV and report metadata in lib/features/export/application/export_service.dart
- [X] T113 [US5] Implement Insights tab with spending analysis, category trends, income-vs-expense, Aiko insights, Aiko Review entry, and report shortcuts in lib/features/insights/presentation/insights_screen.dart
- [X] T114 [US5] Implement Aiko Review screen with budget performance, goal progress, cash flow summary, spending habit summary, and next-month actions in lib/features/reports/presentation/aiko_review_screen.dart
- [X] T115 [US5] Implement reports and export screens with scope/date/format selection and sensitive-data confirmation in lib/features/reports/presentation/reports_screen.dart and lib/features/export/presentation/export_screen.dart
- [X] T116 [US5] Implement chart components for spending category, income-vs-expense, budget progress, goal progress, and net worth trend placeholders in lib/features/reports/presentation/widgets/report_charts.dart
- [X] T117 [US5] Wire Insights, Reports, Aiko Review, and Export routes in lib/app/app_router.dart
- [X] T118 [US5] Add source-explanation semantics, disclaimer copy, color-independent chart labels, and export confirmation accessibility in lib/features/insights/presentation/ and lib/features/export/presentation/
- [ ] T119 [US5] Verify Aiko Review generation under 10 seconds and chart/export performance and document results in specs/001-aiko-finance-app/performance/us5-insights-reports.md

**Checkpoint**: User Story 5 is functional and testable independently.

---

## Phase 8: User Story 6 - Use Aiko And Calculators For Decisions (Priority: P3)

**Goal**: A user can ask Aiko finance questions, receive explainable safe responses, run six calculators, save scenarios, and convert results to draft plans.

**Independent Test**: Ask Aiko common questions, verify missing-data behavior, run all MVP calculators, save a result, and convert one result into a draft goal/budget/debt plan.

### Tests for User Story 6

- [X] T120 [P] [US6] Add unit tests for Aiko assistant consent, sufficient-data response, missing-data response, disclaimer, and source summary contracts in test/features/aiko_assistant/aiko_assistant_contract_test.dart
- [X] T121 [P] [US6] Add unit tests for compound interest and savings goal calculators with standard, boundary, invalid, and conversion cases in test/features/calculators/compound_savings_calculator_test.dart
- [X] T122 [P] [US6] Add unit tests for loan and credit card payoff calculators with standard, boundary, invalid, and conversion cases in test/features/calculators/loan_credit_card_calculator_test.dart
- [X] T123 [P] [US6] Add unit tests for ROI and currency converter calculators with standard, boundary, invalid, and disclaimer cases in test/features/calculators/roi_currency_calculator_test.dart
- [X] T124 [P] [US6] Add widget tests for Aiko assistant, suggested questions, missing-data prompts, calculator library, calculator detail, saved scenarios, and conversion draft states in test/features/aiko_assistant/aiko_calculator_widget_test.dart
- [X] T125 [US6] Add integration test for Ask Aiko safe-to-spend, calculator result save, and calculator-to-goal draft flow in integration_test/aiko_calculator_flow_test.dart

### Implementation for User Story 6

- [X] T126 [P] [US6] Create SavedCalculatorScenario domain model and DTO mapping in lib/features/calculators/domain/saved_calculator_scenario.dart and lib/features/calculators/data/saved_calculator_scenario_dto.dart
- [X] T127 [P] [US6] Create Aiko assistant response, source summary, missing-data, and disclaimer models in lib/features/aiko_assistant/domain/aiko_response.dart
- [X] T128 [US6] Implement pure calculator services for compound interest, savings goal, loan, credit card payoff, ROI, and currency conversion in lib/features/calculators/application/calculator_services.dart
- [X] T129 [US6] Implement saved scenario repository and conversion-to-draft service in lib/features/calculators/data/calculator_scenario_repository.dart and lib/features/calculators/application/calculator_conversion_service.dart
- [X] T130 [US6] Implement Aiko assistant service for safe-to-spend, spending increase, missing data, calculator explanation, source summaries, consent, and disclaimers in lib/features/aiko_assistant/application/aiko_assistant_service.dart
- [X] T131 [US6] Implement Aiko tab with chat-style prompt input, suggested questions, recommendations, monthly review entry, education suggestions, and disclaimers in lib/features/aiko_assistant/presentation/aiko_assistant_screen.dart
- [X] T132 [US6] Implement calculator library search, category list, recently used, saved scenarios, and recommended calculator cards in lib/features/calculators/presentation/calculator_library_screen.dart
- [X] T133 [US6] Implement calculator detail forms and result views for all six MVP calculators in lib/features/calculators/presentation/calculator_detail_screen.dart
- [X] T134 [US6] Implement saved scenario notes and compare/convert draft review screens in lib/features/calculators/presentation/saved_scenario_screen.dart and lib/features/calculators/presentation/calculator_conversion_review_screen.dart
- [X] T135 [US6] Wire Aiko and Calculator routes plus dashboard shortcuts in lib/app/app_router.dart and lib/features/dashboard/presentation/widgets/calculator_shortcuts_widget.dart
- [X] T136 [US6] Add assistant/calculator semantics, dynamic text handling for formulas/results, disclaimer visibility, and non-guarantee copy in lib/features/aiko_assistant/presentation/ and lib/features/calculators/presentation/
- [ ] T137 [US6] Verify calculator input responsiveness and assistant response performance and document results in specs/001-aiko-finance-app/performance/us6-aiko-calculators.md

**Checkpoint**: User Story 6 is functional and testable independently.

---

## Phase 9: Polish & Cross-Cutting Concerns

**Purpose**: Final verification and hardening across all selected user stories.

- [X] T138 [P] Update quickstart validation notes with actual local Supabase and Flutter commands in specs/001-aiko-finance-app/quickstart.md
- [X] T139 [P] Update README setup, platform, Supabase, test, and build guidance in README.md
- [X] T140 [P] Add release security checklist for self-hosted Supabase backups, HTTPS, secrets, RLS, storage, and restore drills in specs/001-aiko-finance-app/security-release-checklist.md
- [X] T141 Run `dart format --set-exit-if-changed .` and fix formatting issues across lib/, test/, integration_test/, and supabase/
- [X] T142 Run `flutter analyze` and fix all analyzer issues across lib/, test/, and integration_test/
- [X] T143 Run `flutter test` and fix all unit/widget failures across test/
- [ ] T144 Run `flutter test integration_test` with local Supabase seeded and fix all integration failures in integration_test/
- [X] T145 Validate RLS and storage ownership behavior against supabase/migrations/ and document evidence in specs/001-aiko-finance-app/security-rls-evidence.md
- [X] T146 Validate accessibility for onboarding, transactions, Home, budgets, insights, Aiko, and calculators and document evidence in specs/001-aiko-finance-app/accessibility-evidence.md
- [ ] T147 Validate profile-mode performance for onboarding, transaction search, Home dashboard, Aiko Review, and calculators and document evidence in specs/001-aiko-finance-app/performance/final-profile-results.md
- [ ] T148 Validate Android build with production dart-defines and document result in specs/001-aiko-finance-app/build/android-build-result.md
- [ ] T149 Validate iOS build with production dart-defines and document result in specs/001-aiko-finance-app/build/ios-build-result.md
- [X] T150 Review all finance, tax, investment, AI, export, and calculator disclaimer copy for consistency in lib/features/

### Deferred Environment-Dependent Validation

The remaining unchecked tasks require device/profile tooling or platform SDKs not available in this WSL/Linux workspace:

- T050, T070, T085, T102, T119, T137, and T147 need Android/iOS emulator or device profile runs; local fixture/test evidence has been documented in the linked files.
- T144 was attempted but blocked because Flutter selected Linux desktop and CMake is not installed.
- T148 was attempted but blocked because no Android SDK/`ANDROID_HOME` is available.
- T149 is blocked because iOS builds require macOS/Xcode and this Linux Flutter toolchain exposes no iOS build command.

---

## Phase 10: Requirements Remediation & Release Gates

**Purpose**: Close task coverage gaps identified by the requirements checklist and analysis before final release.

- [X] T151 [P] Clarify MVP, near-term, later, and planned-module scope boundaries for FR-028, FR-029, and FR-030 in specs/001-aiko-finance-app/spec.md
- [X] T152 [P] Clarify whether US6 Aiko/calculators are first-release MVP scope or post-MVP scope in specs/001-aiko-finance-app/spec.md and specs/001-aiko-finance-app/plan.md
- [X] T153 [P] Document release-gate exception policy for environment-dependent validation in specs/001-aiko-finance-app/release-gates.md
- [X] T154 Add unit tests for bill/subscription and credit-card due-date dashboard source mapping in test/features/dashboard/dashboard_due_items_test.dart
- [X] T155 Create BillSubscription and CreditCardDetail domain models and DTO mappings in lib/features/bills/domain/bill_subscription.dart, lib/features/bills/data/bill_subscription_dto.dart, lib/features/credit_cards/domain/credit_card_detail.dart, and lib/features/credit_cards/data/credit_card_detail_dto.dart
- [X] T156 Implement due-item repository and dashboard adapter for upcoming bills and credit-card due dates in lib/features/dashboard/data/dashboard_due_item_repository.dart and lib/features/dashboard/application/dashboard_due_item_service.dart
- [X] T157 Add Home dashboard due-item widgets, empty states, and deep-link placeholders in lib/features/dashboard/presentation/widgets/dashboard_due_items_widget.dart
- [X] T158 Add widget tests for Home upcoming bills and credit-card due-date states in test/features/dashboard/dashboard_due_items_widget_test.dart
- [X] T159 Add unit tests for transaction attachment metadata, validation, and export-scope behavior in test/features/transactions/transaction_attachment_test.dart
- [X] T160 Implement transaction attachment model, DTO mapping, and repository methods in lib/features/transactions/domain/transaction_attachment.dart, lib/features/transactions/data/transaction_attachment_dto.dart, and lib/features/transactions/data/transaction_attachment_repository.dart
- [X] T161 Add transaction attachment picker and attachment list components to transaction forms in lib/features/transactions/presentation/transaction_attachment_section.dart
- [X] T162 Add unit tests for manual exchange-rate and base-currency conversion behavior in test/core/money/exchange_rate_test.dart
- [X] T163 Implement manual exchange-rate value object and conversion service in lib/core/money/exchange_rate.dart and lib/core/money/currency_conversion_service.dart
- [X] T164 Wire base-currency conversion into dashboard/report summary calculations in lib/features/dashboard/application/dashboard_summary_service.dart and lib/features/reports/application/report_service.dart
- [X] T165 Add notification preference source-module mapping tests in test/features/settings/notification_preferences_test.dart
- [X] T166 Implement notification preference source-module model and repository mapping in lib/features/settings/domain/notification_preference.dart and lib/features/settings/data/notification_preference_repository.dart
- [X] T167 Update quickstart release validation instructions for integration tests, Android build, iOS build, and profile-mode performance evidence in specs/001-aiko-finance-app/quickstart.md
- [X] T168 Run requirements remediation checklist review and document resolved or deferred items in specs/001-aiko-finance-app/checklists/requirements.md

**Checkpoint**: Release-gate gaps are either implemented, verified, or explicitly deferred with documented rationale.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 Setup**: No dependencies; starts immediately.
- **Phase 2 Foundational**: Depends on Phase 1; blocks all user story implementation.
- **Phase 3 US1**: Depends on Phase 2; MVP increment.
- **Phase 4 US2**: Depends on Phase 2 and benefits from US1 auth/account shell.
- **Phase 5 US3**: Depends on Phase 2 and needs at least seeded or implemented account/transaction data.
- **Phase 6 US4**: Depends on Phase 2 and category/account foundations.
- **Phase 7 US5**: Depends on Phase 2 and needs transaction/budget/goal data for meaningful reports.
- **Phase 8 US6**: Depends on Phase 2 and integrates best after dashboard, insights, and calculators have source data.
- **Phase 9 Polish**: Depends on all selected user stories for the release scope.
- **Phase 10 Requirements Remediation & Release Gates**: Depends on Phase 9 evidence and the requirements checklist findings.

### User Story Dependencies

- **US1 Start Securely With Aiko**: Can start after Phase 2; no dependency on other user stories.
- **US2 Track Everyday Money Movement**: Can start after Phase 2; uses auth/account/category foundations and can use fake authenticated user data if US1 UI is incomplete.
- **US3 Home Dashboard**: Can start after Phase 2; independently testable with seeded/fake repositories, but product value improves after US2.
- **US4 Budgets, Goals, And Savings**: Can start after Phase 2; depends on categories/accounts and can be tested with seeded transactions.
- **US5 Insights, Reports, And Exports**: Can start after Phase 2; requires seeded finance data and integrates naturally after US2-US4.
- **US6 Aiko And Calculators**: Can start after Phase 2; calculators are independent, while Ask Aiko improves with US3-US5 source data.

### Within Each User Story

- Tests must be written first and fail before implementation.
- Domain models and DTOs before repositories.
- Repositories/services before presentation.
- Presentation before route wiring and integration tests passing.
- Accessibility and performance evidence before story checkpoint.

---

## Parallel Opportunities

- Setup tasks T003, T004, T006, T007, and T008 can run in parallel.
- Foundational tasks T012, T013, T018, T019, T020, T024, T025, and T031 can run in parallel after T001-T002.
- Each story's unit and widget tests marked [P] can be written in parallel before implementation.
- Domain/DTO tasks marked [P] can run in parallel within each user story.
- US2, US3, US4, US5, and US6 can be developed in parallel after Phase 2 if each uses fake repositories and seeded data until integration.
- Phase 10 documentation tasks T151, T152, T153, and T167 can run in parallel with implementation remediation tasks T154-T166.

## Parallel Example: User Story 1

```text
Task: T033 [US1] Add onboarding state tests in test/features/onboarding/onboarding_state_test.dart
Task: T034 [US1] Add profile/account validation tests in test/features/onboarding/onboarding_validation_test.dart
Task: T035 [US1] Add onboarding widget tests in test/features/onboarding/onboarding_flow_widget_test.dart
Task: T036 [US1] Add app-lock widget tests in test/features/auth/app_lock_widget_test.dart
Task: T038 [US1] Create Profile model files in lib/features/settings/
Task: T039 [US1] Create Account model files in lib/features/accounts/
```

## Parallel Example: User Story 2

```text
Task: T051 [US2] Add transaction validation tests in test/features/transactions/transaction_validation_test.dart
Task: T052 [US2] Add category rule tests in test/features/categories/category_rules_test.dart
Task: T053 [US2] Add transaction rule engine tests in test/features/transactions/transaction_rule_engine_test.dart
Task: T057 [US2] Create Category model files in lib/features/categories/
Task: T058 [US2] Create Transaction model files in lib/features/transactions/
Task: T059 [US2] Create TransactionRule model files in lib/features/transactions/
```

## Parallel Example: User Story 3

```text
Task: T071 [US3] Add dashboard summary tests in test/features/dashboard/dashboard_summary_test.dart
Task: T072 [US3] Add pace/leftover tests in test/features/dashboard/pace_leftover_test.dart
Task: T073 [US3] Add dashboard preference tests in test/features/dashboard/dashboard_preferences_test.dart
Task: T076 [US3] Create dashboard domain models in lib/features/dashboard/domain/
```

## Parallel Example: User Story 4

```text
Task: T086 [US4] Add budget progress tests in test/features/budgets/budget_progress_test.dart
Task: T087 [US4] Add goal forecast tests in test/features/goals/goal_forecast_test.dart
Task: T088 [US4] Add saving plan tests in test/features/goals/saving_plan_test.dart
Task: T091 [US4] Create Budget model files in lib/features/budgets/
Task: T092 [US4] Create Goal and SavingPlan model files in lib/features/goals/
```

## Parallel Example: User Story 5

```text
Task: T103 [US5] Add report aggregation tests in test/features/reports/report_aggregation_test.dart
Task: T104 [US5] Add Aiko insight tests in test/features/insights/aiko_insight_test.dart
Task: T105 [US5] Add CSV export tests in test/features/export/csv_export_test.dart
Task: T108 [US5] Create AikoInsight and Report model files in lib/features/insights/ and lib/features/reports/
```

## Parallel Example: User Story 6

```text
Task: T120 [US6] Add assistant contract tests in test/features/aiko_assistant/aiko_assistant_contract_test.dart
Task: T121 [US6] Add compound/savings calculator tests in test/features/calculators/compound_savings_calculator_test.dart
Task: T122 [US6] Add loan/credit card calculator tests in test/features/calculators/loan_credit_card_calculator_test.dart
Task: T123 [US6] Add ROI/currency calculator tests in test/features/calculators/roi_currency_calculator_test.dart
Task: T126 [US6] Create SavedCalculatorScenario model files in lib/features/calculators/
Task: T127 [US6] Create Aiko response model files in lib/features/aiko_assistant/
```

---

## Implementation Strategy

### MVP First

1. Complete Phase 1 Setup.
2. Complete Phase 2 Foundational.
3. Complete Phase 3 User Story 1.
4. Stop and validate onboarding, auth, first account, app lock, Home shell, tests, accessibility, and performance evidence.

### Practical First Release

1. Complete Phase 1 and Phase 2.
2. Deliver US1, US2, and US3 as the core daily app loop.
3. Add US4 and US5 for planning and reporting.
4. Add US6 for Aiko and calculators after reliable source data exists.
5. Run Phase 9 release hardening.

### Incremental Delivery

1. US1 proves first-run trust and secure entry.
2. US2 provides the transaction data foundation.
3. US3 turns that data into daily guidance.
4. US4 converts tracking into plans.
5. US5 creates review/export value.
6. US6 adds Aiko decision support and calculator workflows.
