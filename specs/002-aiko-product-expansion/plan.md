# Implementation Plan: Aiko Product Expansion Roadmap

**Branch**: `002-aiko-product-expansion` | **Date**: 2026-05-19 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/002-aiko-product-expansion/spec.md`

## Summary

This feature expands Aiko beyond the first-release finance MVP into a phased product platform: Aiko character governance, import/export/backup, bills/subscriptions/notifications, credit/debt/loans, portfolio/assets/net worth, tax/accounting/business mode, Aiko Course, travel/sync/devices, Aiko Optimize/predictions, and monetization packaging.

The implementation approach remains a single Flutter mobile app backed by Supabase Cloud, extending the existing feature-first architecture from `001-aiko-finance-app`. Expansion modules will be introduced as independently testable feature folders with shared foundations for import/export, notifications, prediction safety, advanced finance data, plan gating, and Aiko tone/character rules.

## Technical Context

**Language/Version**: Flutter stable 3.41.9 with Dart 3.11.5, matching the existing project and SDK constraint.

**Primary Dependencies**: Existing Flutter Material/Cupertino, `go_router`, `flutter_riverpod`, `supabase_flutter`, `flutter_secure_storage`, `local_auth`, `intl`, charting/export packages, and Flutter test tooling. New dependencies require explicit justification for import parsing, PDF/Excel export, OCR, notifications, sync, charts, simulations, or payments before addition.

**Storage**: Supabase Cloud Postgres for user-owned financial data, Supabase Storage for documents/receipts/exports/backups, RLS for every user-owned row, and protected device storage for sessions, security, sync state, and local drafts. Local-only mode and encrypted backup are future sub-slices with explicit contracts.

**Testing**: `flutter test` for unit/widget tests, `integration_test` for cross-screen journeys, deterministic fakes for import/export, prediction, notification, portfolio, tax/accounting, and monetization behavior, plus Supabase migration contract checks for schema/RLS/storage.

**Target Platform**: Android and iOS mobile apps. Web/desktop folders remain development convenience unless a later feature explicitly expands target support.

**Project Type**: Mobile app with Supabase Cloud backend data service.

**Performance Goals**: Import preview for 5,000 rows appears within 5 seconds; advanced dashboards and portfolio views respond within 2 seconds for standard datasets; prediction and optimization summaries appear within 10 seconds; export generation gives visible progress within 1 second; scrolling/charts target 60 fps on supported devices.

**Constraints**: No service-role secrets in the app; sensitive AI/tax/investment/accounting outputs require consent, source explanation, uncertainty, and disclaimers; premium gating must never block user-owned data export, account deletion, critical warnings, or required privacy controls; beginner users must be protected from feature overload through progressive disclosure.

**Scale/Scope**: Ten expansion user stories, each deliverable as a separate product slice. Data design should support at least 10,000 transactions, 1,000 imported rows per file initially and 5,000 target rows for preview testing, multiple plans/devices/trips/portfolios/tax years per user, and future integration providers without committing to a provider in this plan.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **Code Quality & Maintainability**: Pass. Expansion work keeps feature ownership under `lib/features/`, shared foundations under `lib/core/` and `lib/shared/`, and contracts in `specs/002-aiko-product-expansion/contracts/`. Complex areas such as import parsing, prediction, sync, monetization, and Aiko character rules are isolated by module.
- **Testing Standards & Regression Control**: Pass. Each user story requires unit tests for domain/state, widget tests for user-facing states, and integration or contract tests for critical journeys. External providers are modeled behind deterministic fakes until provider-specific features are planned.
- **User Experience Consistency**: Pass. New modules reuse the existing app shell, blue theme, card/list/form patterns, loading/empty/error/success states, Aiko tone, and accessibility rules. Aiko character system adds governance rather than ad hoc UI.
- **Performance Requirements**: Pass. Plan defines measurable budgets for import preview, advanced dashboards, portfolio views, predictions, export progress, and chart/scroll frame behavior.
- **Platform Reliability & Accessibility**: Pass. Android/iOS parity, permissions, notifications, file sharing, storage, biometrics/security, dynamic text, semantic labels, focus order, chart alternatives, and contrast are explicit design requirements.

## Project Structure

### Documentation (this feature)

```text
specs/002-aiko-product-expansion/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   ├── aiko-character-contract.md
│   ├── import-export-backup-contract.md
│   ├── advanced-finance-contract.md
│   ├── learning-sync-monetization-contract.md
│   └── optimize-prediction-contract.md
└── tasks.md
```

### Source Code (repository root)

```text
lib/
├── core/
│   ├── import_export/
│   ├── notifications/
│   ├── prediction/
│   ├── sync/
│   └── monetization/
├── features/
│   ├── aiko_character/
│   ├── import_export/
│   ├── bills/
│   ├── credit_cards/
│   ├── debt_loans/
│   ├── portfolio/
│   ├── assets/
│   ├── tax_center/
│   ├── accounting/
│   ├── learning_hub/
│   ├── travel_mode/
│   ├── devices/
│   ├── aiko_optimize/
│   └── monetization/
test/
├── core/
├── features/
└── helpers/
integration_test/
├── import_export_flow_test.dart
├── bills_notifications_flow_test.dart
├── credit_debt_flow_test.dart
├── portfolio_tax_flow_test.dart
└── learning_sync_monetization_flow_test.dart
supabase/
├── migrations/
├── seed.sql
└── storage/
```

**Structure Decision**: Use the existing single Flutter app with feature-first folders and Supabase backend configuration. No separate backend service is introduced by this plan; external integrations are represented by contracts and adapters until individual provider features justify more infrastructure.

## Quality Evidence

**Test Plan**:
- US1: unit tests for Aiko placement/tone rules; widget tests for hide/reduce controls and serious-warning copy; contract checks for character usage.
- US2: unit tests for import mapping, validation, duplicate detection, export scopes, backup states; widget tests for preview/error/confirmation; integration test for import-preview-export flow with fake files.
- US3: unit tests for recurring schedules, annualized costs, notification timing, cancellation/lower-bill suggestions; widget tests for bills list and notification settings; integration test for due reminder and subscription review.
- US4: unit tests for utilization, interest estimates, payoff strategies, loan schedules; widget tests for card/debt screens; integration test for payoff plan comparison.
- US5: unit tests for asset allocation, net worth, portfolio return, drift detection; widget tests for portfolio/allocation/net worth; integration test for holdings and drift alert.
- US6: unit tests for tax-year grouping, deductible tagging, accounting records, report scopes; widget tests for Tax Center/accounting mode; integration test for tax report preparation.
- US7: unit tests for lesson recommendation/progress/quiz scoring; widget tests for course, glossary, and lesson states; integration test for Aiko recommendation to lesson completion.
- US8: unit tests for device sessions, conflict resolution, trip currency conversion, backup recovery state; widget tests for devices/travel mode; integration test for trip budget and remote sign-out.
- US9: unit tests for optimization suggestion ranking, forecast uncertainty, consent gating, source explanation; widget tests for Aiko Optimize and prediction states; integration test for suggestion review/dismiss/tune.
- US10: unit tests for plan entitlements and safe gating; widget tests for plan matrix/upgrade copy; integration test for free-to-premium feature boundary without blocking data export.

**UX Consistency Review**: Reuse existing bottom navigation, More/Settings expansion, card/list/form components, blue theme, chart conventions, Aiko copy tone, and shared screen states. New advanced modules must use progressive disclosure and preserve a simple default experience.

**Accessibility Review**: All modules require semantic labels, focus order, dynamic text, readable contrast, chart alternatives, non-color-only status indicators, and accessible notification/permission copy.

**Performance Review**: Profile import preview, advanced dashboard/portfolio views, prediction generation, export generation, and sync conflict states on representative Android/iOS devices. Any provider-backed feature must include timeout, stale-data, and retry budgets.

## Complexity Tracking

No constitution violations identified. The feature is large, but it is intentionally an umbrella roadmap plan. Complexity is controlled by treating each user story as an independently planned and testable slice before implementation.

## Post-Design Constitution Check

- **Code Quality & Maintainability**: Pass. Research, data model, and contracts split advanced behavior into module boundaries with shared foundations.
- **Testing Standards & Regression Control**: Pass. Contracts and quickstart require unit, widget, integration, accessibility, performance, and Supabase contract checks before release.
- **User Experience Consistency**: Pass. UI contract expectations preserve current app shell/theme while defining new Aiko character and advanced module patterns.
- **Performance Requirements**: Pass. Performance targets are explicit and must be verified per expansion slice.
- **Platform Reliability & Accessibility**: Pass. Android/iOS permissions, notifications, files, sync, backups, accessibility, and dynamic text are part of the planned contracts.
