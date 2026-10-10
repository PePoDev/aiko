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
2. Register the path in `lib/app/app_router.dart` (kebab-case). If it belongs under a destination other than Overview, add it to `_routeOwners` in `lib/app/aiko_navigation.dart` so the right tab and sidebar entry stay highlighted.
3. For a tool, add an entry to `aikoNavigationItems` in `lib/app/aiko_navigation.dart`; it appears in Settings and in the sidebar. A new primary destination goes in `aikoPrimaryDestinations` and `aikoBottomBarPaths`.
4. Open panels with `showAikoSheet` and route-less pages with `openAikoPage`, and check the screen at 390px and 1440px wide ([Web and mobile](design-system.md#web-and-mobile)).
5. Put every user-facing string in both ARB files and read it through `context.l10n`; check the screen in Thai too ([Localization](localization.md#writing-strings-in-code)).
6. Handle loading, empty and error states with `AikoScreenState`.
7. Update [Architecture → Navigation](architecture.md#navigation) and [Features](features.md).

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
4. A provider; add the collection to `firebaseSyncProvider` so other devices refresh and its reads become cache-first ([Cost](cost.md#cost-checklist-for-changes)).
5. Anonymous-data claiming in `OfflineDataMigrator` if records can be created signed-out.
6. Deletion: `deleteAccount` removes the `users/{uid}` subtree automatically; also delete any global server-side data.
7. [Data model](data-model.md), [Backend](backend.md) and [Security](security.md).

### Adding a calculation

1. A pure `*Service` method with injected `asOf` and data, returning `Money` for money.
2. Unit tests covering edge cases (empty data, other currencies, month boundaries).
3. A provider in `lib/app/providers.dart` that watches its inputs and calls `ref.keepAlive()` after success.
4. [Calculations](calculations.md).

### Adding a calculator

1. Put the formula in `CalculatorServices` (or the rules in `thai_tax_rules.dart`) and test it in `test/features/calculators/`.
2. Add a `_CalculatorItem` to `calculator_library_screen.dart` and its English and Thai title, category and description to the ARB files and `_calculatorText`. The id is a stable English name.
3. Add a `CalculatorForm` for the id in `calculatorForm` (`calculator_forms.dart`): fields with labels from `l10n` (`money: true` for amounts, `suffixText: '%'` for rates, `options` for a choice, `showWhen` for fields that depend on it), example `initialValue`s, and `calculate`, which reads values through `CalculatorInputs` and returns a `CalculatorResult`. Set `currency: 'THB'` when the rules are Thai. `calculator_forms_test.dart` fails until every library id has a form that calculates from its starting values, for every choice.
4. Update [Features → Calculators](features.md#calculators) and [Calculations](calculations.md#calculators).

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
