# Implementation Plan: Aiko Personal Finance App

**Branch**: `001-aiko-finance-app` | **Date**: 2026-05-18 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/001-aiko-finance-app/spec.md`

**User Implementation Constraint**: Build the application as a Flutter mobile app for Android and iOS with Supabase Cloud as the backend platform.

## Summary

Aiko is an Android and iOS personal finance mobile app centered on onboarding, secure access, manual accounts, transaction tracking, categories, transaction rules, monthly budgets, goals, saving plans, dashboard widgets, spending insights, Aiko AI guidance, reports, CSV export, and six first-release calculators. The implementation will use a Flutter app organized by feature modules, backed by Supabase Cloud for authentication, Postgres-backed financial data, storage for attachments, realtime updates where useful, and row-level access controls for user-owned records.

The first implementation slice should replace the starter counter app with the Aiko shell, theme, navigation, onboarding, authentication/session handling, and local test scaffolding before adding finance modules incrementally by user story priority.

## Technical Context

**Language/Version**: Flutter stable 3.41.9 with Dart 3.11.5, matching the local toolchain and `pubspec.yaml` SDK constraint.

**Primary Dependencies**: Flutter Material/Cupertino, `supabase_flutter` for Auth/PostgREST/Storage/Realtime access, `flutter_secure_storage` for protected local secrets, `local_auth` for biometric unlock, `go_router` for route structure, `flutter_riverpod` for explicit state boundaries, `intl` for currency/date formatting, charting package for finance visualizations, CSV/export package, and test dependencies already provided by Flutter.

**Storage**: Self-hosted Supabase with Postgres as source of truth, Supabase Auth for identity, Supabase Storage for receipts/documents, RLS policies for user-owned data, and protected device storage for session/security state. Local cache is limited to session, settings, draft forms, and read-only display cache in the MVP; full offline sync is deferred.

**Testing**: `flutter test` for unit and widget tests, `integration_test` for critical onboarding/transaction/dashboard flows, deterministic repository fakes for business logic, and Supabase migration contract checks for schema/RLS/storage verification.

**Target Platform**: Android and iOS mobile apps. Existing web, desktop, Linux, macOS, and Windows project folders are out of scope unless needed for development convenience.

**Project Type**: Mobile app plus Supabase Cloud backend data service.

**Performance Goals**: Primary navigation, quick add, dashboard updates, and calculator input complete in under 1 second for 95% of standard test actions; transaction search/filter results appear in under 2 seconds for up to 10,000 transactions; Aiko Review appears in under 10 seconds; scrolling and chart interactions target 60 fps on supported devices.

**Constraints**: No service-role secrets in the mobile app; all user-owned records require ownership enforcement; sensitive AI, finance, tax, and investment features require disclaimers and consent; protected screens require app lock after timeout; first release remains manual-entry-first; no production dependency on managed Supabase platform features.

**Scale/Scope**: First release covers the 25-screen recommended MVP list with priority on P1 and P2 user stories, plus the US6 MVP decision-support slice for Aiko and the six calculators. Data design targets at least 10,000 transactions per user, multiple accounts/categories/budgets/goals per user, first-release due-item support for bills and credit cards, and future expansion for full credit card management, debt, portfolio, tax, accounting, travel, and sync.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **Code Quality & Maintainability**: Pass. The app will use feature-owned modules under `lib/features/`, shared foundations under `lib/core/` and `lib/shared/`, and generated or hand-written typed models with business logic kept out of widget build methods. Dependencies are limited to product needs: Supabase integration, secure local storage, biometric unlock, navigation, state management, formatting, charting, and export.
- **Testing Standards & Regression Control**: Pass. Unit tests cover value objects, calculators, pace/leftover formulas, rule matching, and repositories with fakes. Widget tests cover onboarding, transaction forms, dashboard states, budget cards, goal cards, Aiko insight cards, calculator forms, and accessibility expectations. Integration tests cover first-run onboarding, add transaction, dashboard review, budget/goal creation, export, and lock/unlock.
- **User Experience Consistency**: Pass. The first design system will define the blue palette, light/dark themes, typography, card patterns, loading/empty/error/success states, bottom navigation, Aiko tone, and accessibility behavior before feature screens are built.
- **Performance Requirements**: Pass. The plan includes user-facing timing budgets, 60 fps scrolling/chart targets, bounded list rendering, repository-level pagination, cached summary reads, and measurement through integration or profile runs on representative Android and iOS devices.
- **Platform Reliability & Accessibility**: Pass. The plan isolates platform-specific behavior for biometrics, secure storage, notifications, file sharing, camera/attachments, and deep links. Screens must expose semantics, logical focus order, adequate contrast, dynamic text support, and platform-appropriate permission flows.

## Project Structure

### Documentation (this feature)

```text
specs/001-aiko-finance-app/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   ├── aiko-assistant-contract.md
│   ├── calculator-contract.md
│   ├── mobile-ui-contract.md
│   └── supabase-data-contract.md
└── tasks.md
```

### Source Code (repository root)

```text
lib/
├── main.dart
├── app/
│   ├── aiko_app.dart
│   ├── app_router.dart
│   └── app_bootstrap.dart
├── core/
│   ├── config/
│   ├── errors/
│   ├── formatting/
│   ├── money/
│   ├── security/
│   ├── storage/
│   └── supabase/
├── features/
│   ├── aiko_assistant/
│   ├── accounts/
│   ├── auth/
│   ├── budgets/
│   ├── calculators/
│   ├── categories/
│   ├── dashboard/
│   ├── export/
│   ├── goals/
│   ├── insights/
│   ├── onboarding/
│   ├── reports/
│   ├── settings/
│   └── transactions/
├── shared/
│   ├── widgets/
│   ├── state/
│   └── test_data/
└── theme/
    ├── aiko_colors.dart
    ├── aiko_theme.dart
    └── aiko_typography.dart

assets/
├── images/aiko/
└── icons/

supabase/
├── config.toml
├── migrations/
├── seed.sql
└── storage/

test/
├── core/
├── features/
├── fixtures/
└── helpers/

integration_test/
├── onboarding_flow_test.dart
├── transaction_dashboard_flow_test.dart
└── budget_goal_flow_test.dart

android/
└── app/

ios/
└── Runner/
```

**Structure Decision**: Use a single Flutter app with feature-first folders and a `supabase/` backend configuration directory. Android and iOS stay as platform host projects. Supabase migrations, seed data, storage policies, and RLS policies live with the app repository so data contracts and client code evolve together.

## Quality Evidence

**Test Plan**:
- User Story 1: unit tests for onboarding state, widget tests for each onboarding step and security setup, integration test from fresh launch to Home.
- User Story 2: unit tests for money values, transaction validation, split balancing, and rule matching; widget tests for add/edit/search/filter states; integration test for add expense and dashboard total update.
- User Story 3: unit tests for dashboard summary, pace, leftover, and net worth calculations; widget tests for loaded, empty, loading, error, and customized widget states; integration test for Home with seeded data.
- User Story 4: unit tests for budget thresholds, goal contribution math, saving plan forecast, and impossible-goal handling; widget tests for budget and goal forms/cards; integration test for budget plus goal setup.
- User Story 5: unit tests for report aggregation and export formatting; widget tests for insights, Aiko Review, source explanation, and export confirmation; integration test for monthly review and CSV export.
- User Story 6: unit tests for six calculator formulas and Aiko response safety rules; widget tests for calculator forms, saved scenarios, and assistant missing-data states; integration test for calculator-to-goal draft.

**UX Consistency Review**: Reuse one app shell with bottom navigation, shared card/list/form components, consistent blue theme tokens, Aiko tone guidance, shared empty/loading/error/success components, and responsive spacing for small Android and iOS devices.

**Accessibility Review**: Every interactive element must have a semantic label, minimum touch target, logical focus order, dynamic text support, and contrast that remains readable in light and dark themes. Widget tests should include accessibility guideline checks for critical screens.

**Performance Review**: Use paginated transaction lists, summary tables or cached aggregates for dashboard/report reads, debounced search/filter, lazy chart rendering, and profile-mode checks for frame timing. Track startup impact when adding charting, Supabase, image, notification, or AI-related packages.

## Complexity Tracking

No constitution violations identified. Supabase Cloud reduces app-owned infrastructure operations while preserving migration, RLS, storage, and no-service-role constraints.

## Post-Design Constitution Check

- **Code Quality & Maintainability**: Pass. Data model and contracts separate UI, domain logic, repositories, Supabase tables, storage, and assistant/calculator boundaries.
- **Testing Standards & Regression Control**: Pass. Quickstart and plan require `dart format`, `flutter analyze`, `flutter test`, and integration tests for critical flows before release.
- **User Experience Consistency**: Pass. Mobile UI contract defines navigation, states, theme, Aiko tone, accessibility, and screen-level expectations.
- **Performance Requirements**: Pass. Contracts and quickstart include measurable timing targets, representative dataset testing, and profile-mode validation.
- **Platform Reliability & Accessibility**: Pass. Platform concerns are isolated to Android/iOS host behavior and Flutter adapters for biometrics, secure storage, permissions, notifications, attachments, and deep links.
