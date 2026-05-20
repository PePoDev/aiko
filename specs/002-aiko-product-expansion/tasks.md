# Tasks: Aiko Product Expansion Roadmap

**Input**: Design documents from `/specs/002-aiko-product-expansion/`

**Prerequisites**: [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md), [data-model.md](data-model.md), [contracts/](contracts/), [quickstart.md](quickstart.md)

**Tests**: Test tasks are mandatory because the project constitution requires automated tests for observable behavior before implementation is considered complete.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each expansion slice.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1-US10)
- Include exact file paths in descriptions

## Phase 1: Setup (Shared Expansion Infrastructure)

**Purpose**: Establish shared folders and docs for the expansion roadmap without disrupting the MVP feature.

- [X] T001 Create expansion feature directories in lib/core/import_export/, lib/core/notifications/, lib/core/prediction/, lib/core/sync/, lib/core/monetization/, lib/features/aiko_character/, lib/features/import_export/, lib/features/debt_loans/, lib/features/portfolio/, lib/features/assets/, lib/features/tax_center/, lib/features/accounting/, lib/features/learning_hub/, lib/features/travel_mode/, lib/features/devices/, lib/features/aiko_optimize/, and lib/features/monetization/
- [X] T002 [P] Create expansion test directories in test/core/import_export/, test/core/notifications/, test/core/prediction/, test/core/sync/, test/core/monetization/, and test/features/
- [X] T003 [P] Create integration test placeholders in integration_test/import_export_flow_test.dart, integration_test/bills_notifications_flow_test.dart, integration_test/credit_debt_flow_test.dart, integration_test/portfolio_tax_flow_test.dart, and integration_test/learning_sync_monetization_flow_test.dart
- [X] T004 [P] Document expansion feature flags and progressive-disclosure defaults in specs/002-aiko-product-expansion/feature-flags.md
- [X] T005 [P] Add expansion seed-data planning notes for Supabase demo data in specs/002-aiko-product-expansion/seed-data.md

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Shared contracts, state types, persistence boundaries, and safety rules required by all expansion slices.

**Critical**: No user story implementation should begin until this phase is complete.

- [X] T006 Create shared expansion lifecycle and freshness models in lib/core/import_export/expansion_state.dart and lib/core/prediction/source_freshness.dart
- [X] T007 [P] Create advice safety, disclaimer, confidence, and source-summary models in lib/core/prediction/advice_safety.dart
- [X] T008 [P] Create shared notification timing and permission models in lib/core/notifications/notification_schedule.dart
- [X] T009 [P] Create shared feature entitlement and premium-gate models in lib/core/monetization/feature_entitlement.dart
- [X] T010 [P] Create shared sync conflict and device status models in lib/core/sync/sync_state.dart
- [X] T011 Add Supabase expansion schema migration for roadmap tables in supabase/migrations/004_product_expansion_schema.sql
- [X] T012 Add Supabase expansion RLS migration for all new user-owned tables in supabase/migrations/005_product_expansion_rls.sql
- [X] T013 [P] Add schema/RLS contract tests for expansion tables in test/core/supabase/product_expansion_contract_test.dart
- [X] T014 [P] Add unit tests for shared advice safety, entitlements, notifications, and sync states in test/core/prediction/advice_safety_test.dart, test/core/monetization/feature_entitlement_test.dart, test/core/notifications/notification_schedule_test.dart, and test/core/sync/sync_state_test.dart
- [X] T015 Update app router More/Settings route placeholders for expansion modules in lib/app/app_router.dart

**Checkpoint**: Expansion foundation ready; user story implementation can now begin.

---

## Phase 3: User Story 1 - Establish Aiko Character System (Priority: P1) MVP

**Goal**: Define and enforce Aiko character placement, tone, visibility, and data-first usage across product surfaces.

**Independent Test**: Review character usage rules and verify placements specify purpose, prominence, hide/reduce behavior, accessibility, and warning tone.

### Tests for User Story 1

- [X] T016 [P] [US1] Add unit tests for Aiko placement and tone rules in test/features/aiko_character/aiko_character_rules_test.dart
- [X] T017 [P] [US1] Add widget tests for hide/reduce character controls and serious-warning copy in test/features/aiko_character/aiko_character_settings_widget_test.dart
- [X] T018 [US1] Add contract tests for Aiko character placement requirements in test/features/aiko_character/aiko_character_contract_test.dart

### Implementation for User Story 1

- [X] T019 [P] [US1] Create AikoCharacterProfile domain model in lib/features/aiko_character/domain/aiko_character_profile.dart
- [X] T020 [P] [US1] Create Aiko character usage contract service in lib/features/aiko_character/application/aiko_character_policy.dart
- [X] T021 [US1] Implement Aiko character preferences repository in lib/features/aiko_character/data/aiko_character_repository.dart
- [X] T022 [US1] Implement Aiko character settings screen in lib/features/aiko_character/presentation/aiko_character_settings_screen.dart
- [X] T023 [US1] Wire Aiko character settings route in lib/app/app_router.dart
- [X] T024 [US1] Document Aiko character design brief in specs/002-aiko-product-expansion/aiko-character-brief.md

**Checkpoint**: US1 is functional and independently testable.

---

## Phase 4: User Story 2 - Manage Import, Export, And Backup (Priority: P1)

**Goal**: Let users preview imports, export scoped data, and understand backup/restore states.

**Independent Test**: Import a fake file preview, review validation/duplicates, cancel safely, then export a scoped package with a sensitivity warning.

### Tests for User Story 2

- [X] T025 [P] [US2] Add unit tests for import mapping, validation issues, and duplicate detection in test/core/import_export/import_job_test.dart
- [X] T026 [P] [US2] Add unit tests for export scopes, formats, and sensitivity warnings in test/core/import_export/export_package_test.dart
- [X] T027 [P] [US2] Add unit tests for backup and restore lifecycle states in test/core/import_export/backup_snapshot_test.dart
- [X] T028 [P] [US2] Add widget tests for import preview, export confirmation, and backup status screens in test/features/import_export/import_export_widget_test.dart
- [X] T029 [US2] Add integration test for import preview to export package flow in integration_test/import_export_flow_test.dart

### Implementation for User Story 2

- [X] T030 [P] [US2] Create ImportJob, ExportPackage, and BackupSnapshot domain models in lib/core/import_export/import_job.dart, lib/core/import_export/export_package.dart, and lib/core/import_export/backup_snapshot.dart
- [X] T031 [P] [US2] Create import/export DTO mappings in lib/features/import_export/data/import_export_dto.dart
- [X] T032 [US2] Implement import preview and validation service in lib/features/import_export/application/import_preview_service.dart
- [X] T033 [US2] Implement export package service in lib/features/import_export/application/export_package_service.dart
- [X] T034 [US2] Implement backup snapshot service in lib/features/import_export/application/backup_snapshot_service.dart
- [X] T035 [US2] Implement import, export, and backup screens in lib/features/import_export/presentation/import_export_screen.dart
- [X] T036 [US2] Wire Import/Export route and Settings entry in lib/app/app_router.dart and lib/features/settings/presentation/settings_screen.dart

**Checkpoint**: US2 is functional and independently testable.

---

## Phase 5: User Story 3 - Track Bills, Subscriptions, And Notifications (Priority: P1)

**Goal**: Manage recurring bills/subscriptions, cancellation/lower-bill suggestions, and Aiko-style notifications.

**Independent Test**: Create a recurring bill, see annualized cost, receive due reminder requirements, and review cancellation/lower-bill suggestion behavior.

### Tests for User Story 3

- [X] T037 [P] [US3] Add unit tests for recurring schedules and annualized costs in test/features/bills/bill_subscription_schedule_test.dart
- [X] T038 [P] [US3] Add unit tests for cancellation and lower-bill suggestions in test/features/bills/subscription_suggestion_test.dart
- [X] T039 [P] [US3] Add unit tests for notification source timing and permission states in test/core/notifications/notification_timing_test.dart
- [X] T040 [P] [US3] Add widget tests for bills list and notification settings in test/features/bills/bills_notifications_widget_test.dart
- [X] T041 [US3] Add integration test for bill due reminder and subscription review in integration_test/bills_notifications_flow_test.dart

### Implementation for User Story 3

- [X] T042 [P] [US3] Extend BillSubscription domain model for annualized costs, renewal state, and cancellation status in lib/features/bills/domain/bill_subscription.dart
- [X] T043 [P] [US3] Create NotificationPreference and AikoAlert domain models in lib/core/notifications/notification_preference.dart and lib/core/notifications/aiko_alert.dart
- [X] T044 [US3] Implement bills and subscriptions repository in lib/features/bills/data/bill_subscription_repository.dart
- [X] T045 [US3] Implement bill/subscription suggestion service in lib/features/bills/application/subscription_suggestion_service.dart
- [X] T046 [US3] Implement notification scheduling policy service in lib/core/notifications/notification_policy_service.dart
- [X] T047 [US3] Implement Bills & Subscriptions screen in lib/features/bills/presentation/bills_screen.dart
- [X] T048 [US3] Implement notification settings UI in lib/features/settings/presentation/notification_settings_screen.dart

**Checkpoint**: US3 is functional and independently testable.

---

## Phase 6: User Story 4 - Manage Credit Cards, Debt, And Loans (Priority: P2)

**Goal**: Track card/debt metrics and compare debt payoff strategies.

**Independent Test**: Add card and debt data, compare snowball/avalanche/custom payoff plans, and review interest savings and payoff dates.

### Tests for User Story 4

- [X] T049 [P] [US4] Add unit tests for credit utilization, minimum payment, and interest estimates in test/features/credit_cards/credit_card_metrics_test.dart
- [X] T050 [P] [US4] Add unit tests for loan schedules and payoff strategies in test/features/debt_loans/debt_payoff_plan_test.dart
- [X] T051 [P] [US4] Add widget tests for credit card and debt payoff screens in test/features/debt_loans/credit_debt_widget_test.dart
- [X] T052 [US4] Add integration test for payoff plan comparison in integration_test/credit_debt_flow_test.dart

### Implementation for User Story 4

- [X] T053 [P] [US4] Extend CreditCardDetail domain model for utilization, APR, rewards, fees, and minimum payment in lib/features/credit_cards/domain/credit_card_detail.dart
- [X] T054 [P] [US4] Create DebtLoanPlan domain model in lib/features/debt_loans/domain/debt_loan_plan.dart
- [X] T055 [US4] Implement credit card metrics service in lib/features/credit_cards/application/credit_card_metrics_service.dart
- [X] T056 [US4] Implement debt payoff strategy service in lib/features/debt_loans/application/debt_payoff_service.dart
- [X] T057 [US4] Implement credit card overview screen in lib/features/credit_cards/presentation/credit_card_overview_screen.dart
- [X] T058 [US4] Implement debt payoff plan screen in lib/features/debt_loans/presentation/debt_payoff_plan_screen.dart
- [X] T059 [US4] Wire Credit Cards and Debt & Loans routes in lib/app/app_router.dart

**Checkpoint**: US4 is functional and independently testable.

---

## Phase 7: User Story 5 - Track Portfolio, Assets, Allocation, And Net Worth (Priority: P2)

**Goal**: Track assets, holdings, allocation, drift, and net worth trends.

**Independent Test**: Add assets/holdings, view allocation and net worth, then receive drift warning with investment disclaimer.

### Tests for User Story 5

- [X] T060 [P] [US5] Add unit tests for asset valuation and net worth aggregation in test/features/assets/net_worth_test.dart
- [X] T061 [P] [US5] Add unit tests for portfolio allocation, gain/loss, and drift detection in test/features/portfolio/portfolio_allocation_test.dart
- [X] T062 [P] [US5] Add widget tests for portfolio, allocation, and net worth screens in test/features/portfolio/portfolio_widget_test.dart
- [X] T063 [US5] Add integration test for holdings entry and allocation drift alert in integration_test/portfolio_tax_flow_test.dart

### Implementation for User Story 5

- [X] T064 [P] [US5] Create Asset domain model in lib/features/assets/domain/asset.dart
- [X] T065 [P] [US5] Create InvestmentHolding and AllocationTarget domain models in lib/features/portfolio/domain/investment_holding.dart and lib/features/portfolio/domain/allocation_target.dart
- [X] T066 [US5] Implement net worth service in lib/features/assets/application/net_worth_service.dart
- [X] T067 [US5] Implement portfolio allocation and drift service in lib/features/portfolio/application/portfolio_allocation_service.dart
- [X] T068 [US5] Implement Assets and Net Worth screen in lib/features/assets/presentation/assets_net_worth_screen.dart
- [X] T069 [US5] Implement Portfolio screen in lib/features/portfolio/presentation/portfolio_screen.dart
- [X] T070 [US5] Wire Portfolio and Assets routes in lib/app/app_router.dart

**Checkpoint**: US5 is functional and independently testable.

---

## Phase 8: User Story 6 - Support Tax, Accounting, And Business Mode (Priority: P2)

**Goal**: Support business separation, tax organization, tax reports, and accounting records.

**Independent Test**: Mark business/tax records, view Tax Center grouping, and produce estimate-labeled report scope.

### Tests for User Story 6

- [X] T071 [P] [US6] Add unit tests for tax-year grouping and deductible tagging in test/features/tax_center/tax_record_test.dart
- [X] T072 [P] [US6] Add unit tests for accounting record states and reconciliation status in test/features/accounting/accounting_record_test.dart
- [X] T073 [P] [US6] Add widget tests for Tax Center and accounting mode screens in test/features/tax_center/tax_accounting_widget_test.dart
- [X] T074 [US6] Add integration test for tax report preparation and disclaimer flow in integration_test/portfolio_tax_flow_test.dart

### Implementation for User Story 6

- [X] T075 [P] [US6] Create TaxRecord domain model in lib/features/tax_center/domain/tax_record.dart
- [X] T076 [P] [US6] Create AccountingRecord and BusinessProfile domain models in lib/features/accounting/domain/accounting_record.dart and lib/features/accounting/domain/business_profile.dart
- [X] T077 [US6] Implement tax center service in lib/features/tax_center/application/tax_center_service.dart
- [X] T078 [US6] Implement accounting mode service in lib/features/accounting/application/accounting_service.dart
- [X] T079 [US6] Implement Tax Center screen in lib/features/tax_center/presentation/tax_center_screen.dart
- [X] T080 [US6] Implement Accounting Mode screen in lib/features/accounting/presentation/accounting_screen.dart
- [X] T081 [US6] Wire Tax Center and Accounting routes in lib/app/app_router.dart

**Checkpoint**: US6 is functional and independently testable.

---

## Phase 9: User Story 7 - Learn With Aiko Course (Priority: P3)

**Goal**: Provide personal finance lessons, quizzes, glossary content, and Aiko recommendations.

**Independent Test**: Open a recommended lesson, complete a quiz, and see progress recorded.

### Tests for User Story 7

- [X] T082 [P] [US7] Add unit tests for lesson recommendation and progress state in test/features/learning_hub/course_lesson_test.dart
- [X] T083 [P] [US7] Add unit tests for quiz scoring and glossary links in test/features/learning_hub/course_quiz_test.dart
- [X] T084 [P] [US7] Add widget tests for course list, lesson, glossary, and quiz states in test/features/learning_hub/learning_hub_widget_test.dart
- [X] T085 [US7] Add integration test for Aiko recommendation to lesson completion in integration_test/learning_sync_monetization_flow_test.dart

### Implementation for User Story 7

- [X] T086 [P] [US7] Create CourseLesson, QuizResult, and GlossaryEntry domain models in lib/features/learning_hub/domain/course_lesson.dart, lib/features/learning_hub/domain/quiz_result.dart, and lib/features/learning_hub/domain/glossary_entry.dart
- [X] T087 [US7] Implement lesson recommendation service in lib/features/learning_hub/application/lesson_recommendation_service.dart
- [X] T088 [US7] Implement course progress repository in lib/features/learning_hub/data/course_progress_repository.dart
- [X] T089 [US7] Implement Learning Hub screen in lib/features/learning_hub/presentation/learning_hub_screen.dart
- [X] T090 [US7] Wire Aiko Course route and Aiko tab entry in lib/app/app_router.dart and lib/features/aiko_assistant/presentation/aiko_assistant_screen.dart

**Checkpoint**: US7 is functional and independently testable.

---

## Phase 10: User Story 8 - Use Travel Mode And Multi-Device Sync (Priority: P3)

**Goal**: Support device sessions, sync status, conflict handling, recovery, and trip-based multi-currency views.

**Independent Test**: Register a device, revoke a session, create a trip budget, and resolve a simulated sync conflict.

### Tests for User Story 8

- [X] T091 [P] [US8] Add unit tests for device session and conflict states in test/features/devices/device_session_test.dart
- [X] T092 [P] [US8] Add unit tests for trip budgets, exchange-rate source, and foreign fee totals in test/features/travel_mode/trip_test.dart
- [X] T093 [P] [US8] Add widget tests for devices and travel mode screens in test/features/devices/travel_sync_widget_test.dart
- [X] T094 [US8] Add integration test for trip budget and remote sign-out flow in integration_test/learning_sync_monetization_flow_test.dart

### Implementation for User Story 8

- [X] T095 [P] [US8] Create DeviceSession domain model in lib/features/devices/domain/device_session.dart
- [X] T096 [P] [US8] Create Trip domain model in lib/features/travel_mode/domain/trip.dart
- [X] T097 [US8] Implement device management and conflict service in lib/features/devices/application/device_session_service.dart
- [X] T098 [US8] Implement travel mode currency and trip budget service in lib/features/travel_mode/application/travel_mode_service.dart
- [X] T099 [US8] Implement Devices screen in lib/features/devices/presentation/devices_screen.dart
- [X] T100 [US8] Implement Travel Mode screen in lib/features/travel_mode/presentation/travel_mode_screen.dart
- [X] T101 [US8] Wire Devices and Travel Mode routes in lib/app/app_router.dart

**Checkpoint**: US8 is functional and independently testable.

---

## Phase 11: User Story 9 - Optimize Financial Plans With Aiko (Priority: P3)

**Goal**: Provide explainable, consent-based optimization suggestions and predictions.

**Independent Test**: Generate a deterministic suggestion, review source data/assumptions/confidence, tune or dismiss it, and see disclaimer behavior.

### Tests for User Story 9

- [X] T102 [P] [US9] Add unit tests for optimization suggestion ranking and status changes in test/features/aiko_optimize/optimization_suggestion_test.dart
- [X] T103 [P] [US9] Add unit tests for prediction scenarios, uncertainty, and stale-data handling in test/core/prediction/prediction_result_test.dart
- [X] T104 [P] [US9] Add widget tests for Aiko Optimize and prediction states in test/features/aiko_optimize/aiko_optimize_widget_test.dart
- [X] T105 [US9] Add integration test for suggestion review, dismiss, and tune flow in integration_test/learning_sync_monetization_flow_test.dart

### Implementation for User Story 9

- [X] T106 [P] [US9] Create OptimizationSuggestion and PredictionResult domain models in lib/features/aiko_optimize/domain/optimization_suggestion.dart and lib/core/prediction/prediction_result.dart
- [X] T107 [US9] Implement optimization suggestion service in lib/features/aiko_optimize/application/aiko_optimize_service.dart
- [X] T108 [US9] Implement prediction scenario service in lib/core/prediction/prediction_service.dart
- [X] T109 [US9] Implement Aiko Optimize screen in lib/features/aiko_optimize/presentation/aiko_optimize_screen.dart
- [X] T110 [US9] Wire Aiko Optimize route and Aiko tab entry in lib/app/app_router.dart and lib/features/aiko_assistant/presentation/aiko_assistant_screen.dart

**Checkpoint**: US9 is functional and independently testable.

---

## Phase 12: User Story 10 - Define Monetization And Plans (Priority: P4)

**Goal**: Define Free, Premium, and Pro plan packaging without blocking ownership, safety, or privacy.

**Independent Test**: Review feature matrix, safe gates, plan-change behavior, and data-portability guarantees.

### Tests for User Story 10

- [X] T111 [P] [US10] Add unit tests for plan entitlements and safe gating in test/core/monetization/feature_entitlement_test.dart
- [X] T112 [P] [US10] Add widget tests for plan matrix and upgrade copy in test/features/monetization/monetization_widget_test.dart
- [X] T113 [US10] Add integration test for premium feature boundary and data export access in integration_test/learning_sync_monetization_flow_test.dart

### Implementation for User Story 10

- [X] T114 [P] [US10] Create SubscriptionPlan and FeatureGate domain models in lib/features/monetization/domain/subscription_plan.dart and lib/core/monetization/feature_gate.dart
- [X] T115 [US10] Implement entitlement service in lib/core/monetization/entitlement_service.dart
- [X] T116 [US10] Implement plan matrix and upgrade prompt screens in lib/features/monetization/presentation/plan_matrix_screen.dart and lib/features/monetization/presentation/upgrade_prompt.dart
- [X] T117 [US10] Wire Subscription Plan route and Settings entry in lib/app/app_router.dart and lib/features/settings/presentation/settings_screen.dart
- [X] T118 [US10] Document Free, Premium, and Pro feature packaging in specs/002-aiko-product-expansion/monetization-matrix.md

**Checkpoint**: US10 is functional and independently testable.

---

## Phase 13: Polish & Cross-Cutting Concerns

**Purpose**: Final validation and hardening across selected expansion stories.

- [X] T119 [P] Update README roadmap notes for expansion modules in README.md
- [X] T120 [P] Update Supabase security release checklist for expansion tables, storage, backups, and provider integrations in specs/002-aiko-product-expansion/security-expansion-checklist.md
- [X] T121 Run `dart format --set-exit-if-changed .` across lib/, test/, integration_test/, and specs/002-aiko-product-expansion/
- [X] T122 Run `flutter analyze` across lib/, test/, and integration_test/
- [X] T123 Run `flutter test` across test/
- [X] T124 Run `flutter test integration_test` for selected expansion flows in integration_test/
- [X] T125 Validate accessibility for Aiko character, import/export, bills, credit/debt, portfolio, tax/accounting, learning, travel/sync, optimize, and monetization screens in specs/002-aiko-product-expansion/accessibility-evidence.md
- [X] T126 Validate performance budgets for import preview, portfolio, prediction, export, and sync flows in specs/002-aiko-product-expansion/performance-evidence.md
- [X] T127 Validate RLS and storage ownership behavior for expansion tables in specs/002-aiko-product-expansion/security-rls-evidence.md

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 Setup**: No dependencies; starts immediately.
- **Phase 2 Foundational**: Depends on Phase 1; blocks all user stories.
- **Phase 3 US1**: Depends on Phase 2; character governance should precede Aiko-heavy slices.
- **Phase 4 US2**: Depends on Phase 2; enables data portability and backup trust.
- **Phase 5 US3**: Depends on Phase 2 and benefits from US1 tone rules.
- **Phase 6 US4**: Depends on Phase 2 and uses existing account/transaction foundations.
- **Phase 7 US5**: Depends on Phase 2 and benefits from US4 liability/card models.
- **Phase 8 US6**: Depends on Phase 2 and benefits from import/export foundations.
- **Phase 9 US7**: Depends on Phase 2 and benefits from US1 Aiko guidance rules.
- **Phase 10 US8**: Depends on Phase 2 and benefits from import/export/backup foundations.
- **Phase 11 US9**: Depends on Phase 2 and should follow enough source-data modules to produce useful suggestions.
- **Phase 12 US10**: Depends on Phase 2 and should follow feature packaging decisions.
- **Phase 13 Polish**: Depends on all selected user stories for the release scope.

### User Story Dependencies

- **US1 Aiko Character System**: Can start after Phase 2; recommended first.
- **US2 Import, Export, Backup**: Can start after Phase 2; supports several later slices.
- **US3 Bills, Subscriptions, Notifications**: Can start after Phase 2; uses notification foundation.
- **US4 Credit Cards, Debt, Loans**: Can start after Phase 2; independent with seeded accounts.
- **US5 Portfolio, Assets, Net Worth**: Can start after Phase 2; independent with seeded holdings/assets.
- **US6 Tax, Accounting, Business Mode**: Can start after Phase 2; benefits from import/export and attachments.
- **US7 Aiko Course**: Can start after Phase 2; benefits from Aiko character/tone rules.
- **US8 Travel And Sync**: Can start after Phase 2; benefits from backup/sync foundation.
- **US9 Aiko Optimize**: Can start after Phase 2 but produces better value after US3-US6 source data.
- **US10 Monetization**: Can start after Phase 2; should be reviewed after feature packaging is stable.

### Within Each User Story

- Tests must be written first and fail before implementation.
- Domain models before repositories/services.
- Services before presentation.
- Presentation before route wiring.
- Accessibility and performance evidence before story checkpoint.

---

## Parallel Opportunities

- Setup tasks T002-T005 can run in parallel.
- Foundational tasks T007-T010 and T013-T014 can run in parallel after T006.
- Tests marked [P] within each story can run in parallel.
- Domain model tasks marked [P] within each story can run in parallel.
- US2, US3, US4, US5, US6, US7, US8, and US10 can proceed in parallel after Phase 2 if each uses fakes and seeded data.
- US9 can begin with deterministic fakes while waiting for richer source data from US3-US6.

## Parallel Example: User Story 2

```bash
Task: T025 [US2] Add import mapping tests in test/core/import_export/import_job_test.dart
Task: T026 [US2] Add export scope tests in test/core/import_export/export_package_test.dart
Task: T027 [US2] Add backup lifecycle tests in test/core/import_export/backup_snapshot_test.dart
Task: T028 [US2] Add import/export widget tests in test/features/import_export/import_export_widget_test.dart
```

## Parallel Example: User Story 5

```bash
Task: T060 [US5] Add net worth tests in test/features/assets/net_worth_test.dart
Task: T061 [US5] Add portfolio allocation tests in test/features/portfolio/portfolio_allocation_test.dart
Task: T064 [US5] Create Asset model in lib/features/assets/domain/asset.dart
Task: T065 [US5] Create InvestmentHolding and AllocationTarget models in lib/features/portfolio/domain/
```

---

## Implementation Strategy

### MVP First

1. Complete Phase 1 Setup.
2. Complete Phase 2 Foundational.
3. Complete Phase 3 US1 Aiko Character System.
4. Complete Phase 4 US2 Import/Export/Backup.
5. Stop and validate product trust foundations before larger expansion.

### Incremental Delivery

1. Add US3 Bills/Subscriptions/Notifications.
2. Add US4 Credit/Debt/Loans.
3. Add US5 Portfolio/Assets/Net Worth.
4. Add US6 Tax/Accounting.
5. Add US7 Learning Hub and US8 Travel/Sync.
6. Add US9 Aiko Optimize once enough source data exists.
7. Add US10 Monetization packaging after feature value is demonstrable.

### Parallel Team Strategy

With multiple developers:

1. Shared team completes Phase 1 and Phase 2.
2. Designer/content-focused developer handles US1 and US7.
3. Data/import-focused developer handles US2 and US8.
4. Finance-domain developer handles US3-US6.
5. AI/product developer handles US9 and US10.

---

## Notes

- [P] tasks = different files, no dependency on incomplete tasks.
- [Story] label maps tasks to user-story slices.
- Expansion modules should remain feature-flagged until each story checkpoint passes.
- Avoid provider-specific implementation until a provider-specific spec is created.
