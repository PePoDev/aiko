# Contributing

How to make a change that fits the codebase, passes CI and keeps the docs true. The README's [Rules](../README.md#rules) and [Code Conventions](../README.md#code-conventions) are binding; this page turns them into steps.

## Workflow

1. Work on a branch. Every push runs CI and deploys a **preview channel** for that branch ([Deployment](deployment.md)). AI agents follow the README Rules for Git instead.
2. Run the quality gates locally (below) before pushing.
3. Update the docs in the same change ([Keeping docs current](README.md#keeping-docs-current)).
4. Merge to `main`. CI deploys Firebase rules and the live site after the gates pass.

## Quality gates

```sh
dart format --output=none --set-exit-if-changed lib test
flutter analyze lib test
flutter test
npm --prefix firebase/functions test
npx firebase emulators:exec --project demo-aiko --only auth,firestore,storage,functions "npm run test:rules"
flutter build web
npm run docs:check
```

## Conventions at a glance

| Topic | Rule |
| --- | --- |
| Money | `Money` / `Decimal` only; format with `MoneyFormatter`; store decimal strings |
| Layers | Screens → providers → services/repositories → `OfflineStore`. Screens never call Firebase, Brick or SQLite. |
| Naming | Files `snake_case.dart`, classes `PascalCase`, members `camelCase`, routes `/kebab-case`, DB fields `snake_case` |
| Roles | `*Service`: pure, `const`, no Riverpod. `*Notifier`: reactive state with `ref.keepAlive()` after a successful load. `*Controller`: orchestrates notifier, service and UI side effects. `*Repository`: persistence, no `ref` or `BuildContext`. |
| Widgets | Forward `super.key`; use shared widgets and theme tokens ([Design system](design-system.md)) |
| State | Riverpod for everything beyond trivial local UI state |
| Tests | Logic only, no new widget tests ([Testing](testing.md)) |
| Voice | Warm, calm, never shaming |
| Glossary | Learning Hub definitions stay inline through `InlineGlossaryText`; no standalone glossary |

## Recipes

### Adding a screen or route

1. Put the screen in the owning feature's `presentation/`. Extend an existing feature rather than duplicating a main screen.
2. Register the path in `lib/app/app_router.dart` (kebab-case). If it belongs under a tab, add its prefix to `_isSecondaryRoute` or `_indexFor` in `authenticated_shell.dart`.
3. For a Settings tool, add an entry to `aikoNavigationItems` in `lib/app/aiko_navigation.dart`.
4. Handle loading, empty and error states with `AikoScreenState`.
5. Update [Architecture → Navigation](architecture.md#navigation) and [Features](features.md).

### Adding a field

1. Domain model (`domain/`) and its `copyWith`.
2. Brick model (`lib/brick/models/*.model.dart`) and a **new** migration in `lib/brick/db/`, added to `migrations` and the schema in `schema.g.dart`. Never edit an old migration.
3. Both codec halves in `lib/brick/adapters/*.dart` (SQLite and Firestore) and the mapper in `lib/brick/offline_model_mappers.dart`.
4. Security Rules if the field needs validation (`firebase/firestore.rules`) and a rules test.
5. A round-trip test in `test/brick/`.
6. [Data model](data-model.md).

### Adding a collection

All of [Adding a field](#adding-a-field), plus:

1. A `FirestoreAdapter` with a `collectionName`, registered in `firestoreAdapters` (`lib/brick/model_dictionary.dart`).
2. Owner-scoped rules: add the name to `financeCollection` (or write a dedicated match) and add allow and deny tests.
3. A repository in the feature's `data/` that resolves the user through `OfflineUserContext` and calls `OfflineStore`.
4. A provider; add the collection to `firebaseSyncProvider` so other devices refresh.
5. Anonymous-data claiming in `OfflineDataMigrator` if records can be created signed-out.
6. Deletion: `deleteAccount` removes the `users/{uid}` subtree automatically; also delete any global server-side data.
7. [Data model](data-model.md), [Backend](backend.md) and [Security](security.md).

### Adding a calculation

1. A pure `*Service` method with injected `asOf` and data, returning `Money` for money.
2. Unit tests covering edge cases (empty data, other currencies, month boundaries).
3. A provider in `lib/app/providers.dart` that watches its inputs and calls `ref.keepAlive()` after success.
4. [Calculations](calculations.md).

### Adding a calculator

1. Add a `_CalculatorItem` to `lib/features/calculators/presentation/calculator_library_screen.dart`.
2. Add a `_CalculatorKind`, a `_CalculatorConfig.fromTitle` case and the math in `calculator_detail_screen.dart`, with pure formulas in `CalculatorServices`. Without a config case, the entry falls back to compound interest.
3. Add tests in `test/features/calculators/`.
4. Update [Features → Calculators](features.md#calculators) and the known-gaps list.

### Adding a Cloud Function

1. Export it from `firebase/functions/src/index.ts`. Derive the user from `request.auth` or a verified ID token, rate-limit it, validate inputs, and declare secrets in the options.
2. Treat a missing or `local-unconfigured` secret as "unavailable", not a crash.
3. Call it through `FirebaseBackend.functions` from a repository or service.
4. Add emulator tests in `firebase/test/functions.test.cjs`.
5. Add any new secret to `.secret.local.example`, [Deployment → Storage and Functions](deployment.md#storage-and-functions) and [Backend](backend.md).

### Adding a string

See [Localization](localization.md#adding-or-changing-a-string).

## Commits and pull requests

- Small, focused commits with an imperative subject ("Add rollover to weekly budgets").
- Describe user-visible changes and their risks, how you validated them, and which docs you updated.
- Don't commit generated or local files: `build/`, `lib/l10n/app_localizations*.dart`, `web/sqflite_sw.js`, `web/sqlite3.wasm`, `.env`, `.firebase-data/`, `firebase/functions/lib/`, `firebase/functions/.secret.local`.
