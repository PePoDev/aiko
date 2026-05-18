<!--
Sync Impact Report: Constitution v2.0.0

Version Change: 1.0.0 -> 2.0.0 (MAJOR - core principles redefined around
code quality, testing standards, UX consistency, and performance requirements)

Modified Principles:
- Mobile-First Development -> Code Quality & Maintainability
- Widget Composition & Reusability -> Testing Standards & Regression Control
- State Management Discipline -> User Experience Consistency
- Cross-Platform Consistency -> Performance Requirements
- Testing & Quality -> Platform Reliability & Accessibility

Added Sections:
- Quality Standards: concrete code, test, UX, accessibility, and performance gates

Removed Sections:
- Flutter Standards: folded into Quality Standards and Core Principles

Templates Requiring Updates:
- ✅ .specify/templates/plan-template.md: Constitution gates require quality/test/UX/performance review
- ✅ .specify/templates/spec-template.md: Requirements include UX, accessibility, and performance criteria
- ✅ .specify/templates/tasks-template.md: Test tasks are mandatory and quality/performance tasks are explicit
- ✅ .specify/templates/commands/*.md: Not present in this repository
- ✅ README.md: No constitution references required updating

Follow-up TODOs: None
-->

# Aiko Constitution

## Core Principles

### I. Code Quality & Maintainability

All production code MUST be simple, typed, lint-clean, formatted, and organized
around clear ownership boundaries. Flutter UI MUST be decomposed into reusable
widgets with single responsibilities; business logic MUST remain outside widget
build methods and MUST be independently testable. New abstractions MUST remove
real duplication or isolate real complexity, and files with growing scope MUST
be split before they become difficult to review.

**Rationale**: Aiko is a Flutter application whose long-term pace depends on
small, understandable changes. Consistent structure reduces regressions and
makes code review effective.

### II. Testing Standards & Regression Control (NON-NEGOTIABLE)

Every feature MUST include automated tests for its observable behavior before
implementation is considered complete. Unit tests MUST cover business logic and
state transitions. Widget tests MUST cover custom UI states, validation, and
interaction behavior. Integration tests MUST cover critical user journeys and
cross-screen flows. Tests MUST be deterministic, must not depend on external
services without controlled fakes, and failing tests MUST block merges.

**Rationale**: Untested behavior is not releasable behavior. Flutter provides
fast feedback at unit and widget levels, and the project relies on that feedback
to prevent regressions during iterative feature delivery.

### III. User Experience Consistency

User-facing changes MUST use existing navigation patterns, typography, spacing,
color roles, controls, empty states, loading states, error states, and copy tone
unless a specification explicitly approves a design-system change. Interactive
elements MUST have clear affordances, predictable touch targets, and accessible
labels. Features MUST support dynamic text sizing, screen readers, and both iOS
and Android expectations without fragmenting the product identity.

**Rationale**: Users experience Aiko as one coherent product. Consistent
interaction and presentation lower cognitive load and make accessibility a
standard part of feature work.

### IV. Performance Requirements

Features MUST define measurable performance goals before implementation and
MUST verify those goals before release. UI updates MUST avoid unnecessary
rebuilds, long synchronous work on the main isolate, unbounded list rendering,
and avoidable asset or dependency weight. Animations and scrolling MUST target
60 fps on supported devices, and any feature likely to affect startup time,
memory, network usage, or frame timing MUST include a measurement plan.

**Rationale**: Mobile performance problems are user-visible and expensive to
repair after release. Performance budgets make tradeoffs explicit while the
feature is still easy to shape.

### V. Platform Reliability & Accessibility

Features MUST work correctly on supported iOS and Android targets. Platform
specific behavior MUST be isolated, documented, and tested. Accessibility is a
release requirement: interactive widgets MUST expose semantics, focus order
MUST be logical, text contrast MUST meet accessible standards, and critical
flows MUST remain usable with assistive technologies.

**Rationale**: Flutter enables shared implementation, but reliable mobile
software still requires deliberate platform and accessibility validation.

## Quality Standards

**Framework**: Flutter stable channel with Dart SDK constraints defined in
`pubspec.yaml`.

**Formatting and Analysis**: `dart format --set-exit-if-changed .` and
`flutter analyze` MUST pass with zero errors before merge.

**Automated Tests**: `flutter test` MUST pass before merge. New behavior MUST
include tests at the lowest practical level and at least one user-journey or
widget-level verification for user-facing changes.

**Dependencies**: New packages MUST be justified by clear product or engineering
value and reviewed for maintenance, license, security, binary size, and
platform support.

**State Management**: State boundaries MUST be explicit. Global state MUST be
minimized and justified in the plan when introduced or expanded.

**Design Consistency**: Feature plans MUST identify existing UI patterns being
reused or document the approved reason for introducing a new pattern.

**Performance Budgets**: Feature plans MUST define measurable performance
expectations such as frame rate, response time, memory, startup, bundle size, or
network limits when the feature can affect them.

## Development Workflow

**Code Review**: All changes require review. Reviewers MUST verify constitution
compliance for code quality, tests, UX consistency, accessibility, and
performance impact.

**Quality Gates**:
- Formatting MUST pass with no pending changes.
- Static analysis MUST pass with zero errors.
- Automated tests MUST pass with no skipped tests unless each skip is justified.
- User-facing changes MUST include widget or integration coverage.
- Performance-sensitive changes MUST include measurement evidence or a documented
  rationale for why measurement is not applicable.

**Breaking Changes**: API, state, navigation, persistence, or design-system
changes affecting existing screens require a migration plan and documentation
update.

**Documentation**: Public widgets/classes MUST have dartdoc comments when their
purpose or usage is not obvious. Complex state flows and performance-sensitive
paths MUST include concise implementation notes.

## Governance

This constitution supersedes all other development practices. All feature
specifications, plans, and tasks MUST demonstrate compliance with these
principles. Complexity, deviations, or deferred compliance MUST be explicitly
justified in design documents and reviewed before implementation proceeds.

**Amendments**:
- Require documented rationale and project maintainer approval.
- MAJOR version bump for principle removals or material redefinitions.
- MINOR version bump for new principles, new required sections, or materially
  expanded governance.
- PATCH version bump for clarifications, wording fixes, and non-semantic
  refinements.

**Enforcement**: Pull requests failing constitution checks MUST be rejected until
the issue is fixed or an approved exception is documented. Regular feature
reviews MUST verify that templates, plans, and tasks continue to reflect the
active constitution.

**Version**: 2.0.0 | **Ratified**: 2026-05-18 | **Last Amended**: 2026-05-18
