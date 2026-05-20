# Research: Aiko Personal Finance App

## Decision: Flutter Mobile First For Android And iOS

**Decision**: Use the existing Flutter app as the only first-release client, targeting Android and iOS. Keep web and desktop folders out of MVP scope.

**Rationale**: The user explicitly requested Flutter for Android and iOS. The repository already contains a Flutter starter project with Android and iOS host projects, `pubspec.yaml`, `analysis_options.yaml`, and `test/`. Flutter supports shared UI, business logic, unit tests, widget tests, and integration tests across both target platforms.

**Alternatives considered**:
- React Native: rejected because the project and constitution are Flutter-oriented.
- Separate native iOS and Android apps: rejected because it would double implementation and test surface for the MVP.
- Web-first app: rejected because the specified platform is mobile.

## Decision: Self-Hosted Supabase As Backend Platform

**Decision**: Use Supabase Cloud for Auth, Postgres, Storage, Realtime, migrations, and local development. Use Supabase CLI for local development and managed Supabase Cloud operations for production-like deployments.

**Rationale**: The user specified Supabase Cloud. Official Supabase guidance distinguishes Supabase CLI project linking from production Supabase Cloud operations and identifies Supabase Cloud operations as appropriate when the product needs control over data or isolated infrastructure. It also makes clear that Supabase Cloud operations shifts responsibility for server provisioning, hardening, backups, maintenance, monitoring, uptime, and scaling to the application owner.

**Alternatives considered**:
- Managed Supabase: rejected because the user specified Supabase Cloud.
- Firebase: rejected because it does not satisfy the Supabase Cloud requirement.
- Custom backend from scratch: rejected for MVP because Supabase provides Auth, Postgres, Storage, Realtime, and access-control building blocks.

## Decision: Supabase Auth With User-Owned Row Level Security

**Decision**: Use Supabase Auth identities as the owner boundary for every user-owned finance table. Apply Row Level Security to financial records and never ship service-role credentials in the mobile app.

**Rationale**: Aiko handles sensitive financial records. Ownership must be enforced on the backend, not only in UI state. RLS policies keep user data separated even when records are queried directly through Supabase client access.

**Alternatives considered**:
- Client-side filtering only: rejected because it does not protect data.
- Custom auth service for MVP: rejected because Supabase Auth is already part of the chosen backend platform.
- Shared household/business access in MVP: deferred because it requires role-based policies and sharing workflows beyond the first release.

## Decision: Feature-First Flutter Architecture

**Decision**: Organize production code by features under `lib/features/`, with shared foundations in `lib/core/`, design system in `lib/theme/`, and reusable widgets in `lib/shared/`.

**Rationale**: The spec is broad and modular. Feature-first ownership keeps onboarding, accounts, transactions, budgets, goals, insights, assistant, calculators, settings, and export independently understandable while still sharing money formatting, security, Supabase access, error handling, and theme tokens.

**Alternatives considered**:
- Layer-only folders such as `models/`, `screens/`, `services/`: rejected because the app has many domains and layer-only grouping becomes hard to navigate.
- One file per screen: rejected because it mixes UI, validation, state, and business logic.
- Early package split: rejected for MVP because one app package is simpler until ownership pressure justifies packages.

## Decision: Riverpod For Explicit State Boundaries

**Decision**: Use Riverpod-style providers for feature state, repositories, and derived summaries.

**Rationale**: The constitution requires explicit state boundaries and testable business logic outside widget build methods. Provider-based dependency injection makes repositories and calculators easy to fake in tests without committing to heavyweight global state.

**Alternatives considered**:
- Plain `setState`: rejected for domain flows that cross screens and require testable state transitions.
- BLoC: viable, but heavier for the MVP's form-heavy dashboard and finance flows.
- Ad hoc singletons: rejected because they hide dependencies and complicate tests.

## Decision: Money Values Use Decimal Semantics

**Decision**: Represent money as currency plus decimal amount, store amounts in Supabase with fixed precision numeric values, and serialize calculator/API-style values as strings when precision matters.

**Rationale**: Personal finance data must avoid floating point rounding surprises. Currency is required for every amount, and future multi-currency support depends on explicit exchange-rate and base-currency handling.

**Alternatives considered**:
- Floating point amounts: rejected due to rounding risk.
- Minor-unit integers only: useful for many currencies, but less flexible for exchange rates, investments, and tax estimates requiring fractional precision.
- Free-form strings only: rejected because comparisons, totals, and reports require validated numeric behavior.

## Decision: Online-First MVP With Limited Local Persistence

**Decision**: Build MVP as online-first against Supabase Cloud while keeping protected local storage for session/security state, display settings, draft forms, and optional read-only cached summaries. Full offline write sync is deferred.

**Rationale**: Offline sync for transactions, budgets, goals, attachments, conflicts, and reports is a significant product and data-consistency feature. The MVP can still provide clear offline/error states without blocking core manual tracking.

**Alternatives considered**:
- Full offline-first sync in MVP: rejected because it adds conflict resolution, local database migrations, and sync testing.
- No local state at all: rejected because app lock, session persistence, and draft recovery need protected local storage.

## Decision: Supabase Storage For Receipts And Documents

**Decision**: Store receipt images and documents in Supabase Storage buckets with user-scoped paths and metadata records linked from transactions or tax records.

**Rationale**: The feature spec includes attachments, receipts, tax documents, and future OCR. Object storage separates files from relational finance data while keeping access policies tied to the authenticated user.

**Alternatives considered**:
- Store files in Postgres rows: rejected because large binary records would bloat relational tables.
- Device-only attachments: rejected because users need backup/export and future multi-device support.
- Third-party storage service: rejected for MVP because Supabase Storage is available in the chosen backend.

## Decision: Aiko Assistant Starts As Explainable Decision Support

**Decision**: Implement Aiko assistant contracts around explainable summaries, missing-data responses, disclaimers, source data summaries, and consent checks. The MVP can use deterministic insight rules first and add LLM-backed chat behind the same contract later.

**Rationale**: The feature spec requires trust, consent, and non-certified advice disclaimers. A deterministic contract makes recommendations testable and avoids depending on a live AI provider before the core finance data is reliable.

**Alternatives considered**:
- Full automated AI advisor in MVP: rejected because the spec marks fully automated advisor behavior as out of MVP.
- Chat UI without source explanations: rejected because AI trust features are required.
- No assistant until later: rejected because Aiko branding and basic insights are first-release differentiators.

## Decision: Calculators Are Pure Domain Services

**Decision**: Implement the six MVP calculators as pure, deterministic domain services with saved scenarios persisted separately from the calculators themselves.

**Rationale**: Calculator formulas need deterministic tests and should not depend on UI, network, or database state. Saved scenarios and conversion to draft goals/budgets/debt plans can wrap the pure results.

**Alternatives considered**:
- Calculator logic inside widgets: rejected because it is hard to test.
- Server-only calculator execution: rejected for MVP because calculations are simple and should feel instant.
- External calculator library for all formulas: rejected unless a specific formula proves too risky to maintain internally.

## Decision: UI Contracts Cover Screen States Before Implementation

**Decision**: Define UI state contracts for all first-release flows before task generation: loading, empty, success, validation error, permission denied, offline, locked, and sensitive-data disclaimer states.

**Rationale**: The constitution requires consistent UX, accessibility, and platform behavior. A state contract prevents each feature from inventing its own empty/error/loading language.

**Alternatives considered**:
- Let each feature define states independently: rejected because the app must feel coherent.
- Visual design only, without behavioral states: rejected because accessibility and tests require concrete behavior.

## Decision: Production Self-Hosting Needs Explicit Operations Scope

**Decision**: Treat Supabase Cloud operations as part of the plan: HTTPS, secrets, backups, restore drills, logs, monitoring, database maintenance, service upgrades, and RLS migration review are release responsibilities.

**Rationale**: Self-hosting is not only a development dependency. It changes reliability and security responsibilities for a finance app. The MVP should document local development separately from production deployment to avoid accidentally treating the CLI stack as production.

**Alternatives considered**:
- Ignore operations until launch: rejected because backup/security choices affect schema, secrets, and release readiness.
- Use only Supabase Cloud development project CLI for all environments: rejected because Supabase CLI project linking is not the same as production Supabase Cloud operations.
