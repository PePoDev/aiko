# Quickstart: Aiko Product Expansion Roadmap

## Prerequisites

- Complete the MVP setup in `specs/001-aiko-finance-app/quickstart.md`.
- Create or choose a Supabase Cloud project before credentialed smoke testing.
- Keep `SUPABASE_URL` and `SUPABASE_ANON_KEY` out of source control until provided through dart defines or local environment files.
- Keep all expansion modules behind feature flags or progressive disclosure until individually validated.

## 1. Planning Validation

Review these documents before generating tasks:

- `specs/002-aiko-product-expansion/spec.md`
- `specs/002-aiko-product-expansion/plan.md`
- `specs/002-aiko-product-expansion/research.md`
- `specs/002-aiko-product-expansion/data-model.md`
- `specs/002-aiko-product-expansion/contracts/`

## 2. Quality Gates

Run formatting:

```bash
dart format --set-exit-if-changed .
```

Run static analysis:

```bash
flutter analyze
```

Run unit and widget tests:

```bash
flutter test
```

Run integration tests after each expansion slice has a critical journey:

```bash
flutter test integration_test
```

Push schema changes to Supabase Cloud after linking the project:

```bash
supabase login
SUPABASE_PROJECT_REF=<your-project-ref> ./scripts/supabase_cloud_prepare.sh
```

## 3. Manual Planning Checks

- Aiko character rules keep data first and allow reduced/hidden character visuals.
- Import/export flows include preview, confirmation, rollback, and sensitive-data warnings.
- Advanced finance modules show source data, assumptions, uncertainty, and disclaimers.
- Monetization never blocks data export, account deletion, privacy controls, or critical warnings.
- Beginner users can keep a simple experience through progressive disclosure.

## 4. Release Evidence

Each expansion slice must document:

- unit/widget/integration evidence,
- accessibility review,
- performance measurement or justified deferral,
- Android/iOS validation status,
- RLS/storage ownership evidence for new Supabase entities.
