# Budgets → Categories, Goals → Accounts merge

> **Status:** Plan, not implementation. Approved direction: budgets become fields on `Category`; goals become a new `AccountType.goal`; sub-pages move to a flat Settings list.
> **Scope:** ~60 files, 5 PRs. Conflicts with AGENTS.md ownership model and must update it.

---

## Why this is being done

Reduce the surface area of the Aiko app: two full feature modules (Budgets, Goals) collapse into existing primary-nav modules (Categories, Accounts). All Budget and Goal sub-routes become Settings entries. Net result: one fewer primary concept, fewer top-level screens, no separate data tables for budget limits and goal targets.

## Conflicts with AGENTS.md (must update)

| AGENTS.md rule | New rule |
|---|---|
| "Categories owns Name, type, group, icon, color, active/archive state" | "Categories owns Name, type, group, icon, color, active/archive state, and optional budget limit (amount, period, rollover, alert thresholds)." |
| "Budgets owns Category inclusion, limits, periods, rollover, alerts" | "Budgets is dissolved. Limits live on the Category that owns them." |
| "Budget forms own budget inclusion — category forms do not" | REPEAL. Category editor surfaces a "Budget" section for non-default categories. |
| "Accounts owns Balances, currency, account type, active state, net-worth inclusion" | "Accounts owns balances, currency, account type, active state, net-worth inclusion, and (when type=goal) target amount, target date, priority." |
| (none) | "Goals is dissolved. Goals are Accounts with type=goal." |
| (none) | "Settings (Menu → Planning group) lists Budget and Goals tools, plus their sub-routes, in a flat list." |

The Ownership table in AGENTS.md needs the rows for `Budgets` and `Goals` deleted and the `Categories` / `Accounts` rows extended. The "Budget forms own budget inclusion" rule is removed.

## Architecture after merge

### Data model

**Category** (`lib/features/categories/domain/category.dart`) gains:

```dart
Money? monthlyLimit;        // base currency, null = no budget
BudgetPeriod period;        // weekly / monthly / yearly, default monthly
bool rollover;              // unused budget carries forward, default false
List<int> alertThresholds;  // 0..1 ratios; default [0.5, 0.75, 0.9, 1.0]
```

The 81 default categories stay free of budget fields. The data goes into a single new column on the offline model + Postgres table — see PR1.

**Account** (`lib/features/accounts/domain/account.dart`) gains:

```dart
// already has: type, currency, currentBalance, ...
Money? targetAmount;   // required when type=goal, null otherwise
DateTime? targetDate;  // required when type=goal, null otherwise
GoalPriority priority; // high / medium / low; default medium
```

`AccountType.goal` is a new enum value. The Account form gets a "Goal details" subform shown when the user picks type=goal.

**Removed:** the `Budget` domain model, the `Budget` Brick model, the `budgets` table, the `Goal` domain model, the `Goal` Brick model, the `goals` table. Existing rows must be migrated (see PR1).

### Services & domain

- `BudgetProgressService` (`lib/features/budgets/application/budget_progress_service.dart`) becomes `CategoryBudgetProgressService` (`lib/features/categories/application/category_budget_progress_service.dart`). Same algorithm, but operates on `Map<CategoryId, Category>` instead of `List<Budget>`.
- `GoalForecastService` (`lib/features/goals/application/goal_forecast_service.dart`) becomes `AccountGoalForecastService` (`lib/features/accounts/application/account_goal_forecast_service.dart`). Same algorithm, but inputs are `Account` rows with `type=goal` and an associated `Account.balance()` call.

### Routes

| Old route | New route |
|---|---|
| `/budget` | (removed) |
| `/budget/pace` | `/settings/pace` |
| `/budget/safe-to-spend` | `/settings/safe-to-spend` |
| `/budget/cash-flow` | `/settings/cash-flow` |
| `/budget/cash-flow-sankey` | `/settings/cash-flow-sankey` |
| `/goals` | (removed) |
| `/goals/detail` | (gone — replaced by account detail screen) |
| `/goals/saving-plan` | `/settings/saving-plan` |
| `/goals/chance-of-success` | `/settings/chance-of-success` |

### Settings layout

Settings currently groups items under "Planning / Insights and AI / Tools and Data / Settings and Security." Per the user, **flat list, no grouping** — the existing groups stay for now (backward-compat) but the new Budget/Goal entries sit in Planning, un-grouped. Long-term, a separate "flatten Settings" task can address the wider grouping.

Entries to add (all under existing **Planning** group):

- Budget: Pace
- Budget: Safe to Spend
- Budget: Cash Flow
- Budget: Cash Flow (Sankey)
- Goals: Saving Plan
- Goals: Chance of Success

Plus the existing Planning items. Visually: a flat list of tappable rows, each with a leading icon, title, and a short trailing description.

## Dashboard impact

Three dashboard panels currently read `budgetsProvider` / `goalsProvider` and must be rewired:

| Panel | File | New data source |
|---|---|---|
| Category Budgets | `home_dashboard_screen.dart:898, 1685` | derived: `categoriesProvider` × `transactionsProvider` |
| Aiko Goal Simulator | `home_dashboard_screen.dart:1272` | derived: `accountsProvider` filtered to `type=goal` |
| Upcoming due dates | `home_dashboard_screen.dart:42, 44` | unchanged (already reads `goalsProvider` for goal due dates — now reads `accountsProvider` for `type=goal` with `targetDate`) |

The `Budget.dailySpendingId` magic (currently a special non-deletable budget row at `providers.dart:503`) goes away. Daily Spending becomes a derived panel from transaction date instead of a stored budget.

## Risks

1. **Data migration.** Existing users have `budgets` and `goals` rows. They must be migrated to `categories` and `accounts` rows. The migration runs offline (Brick) and online (Supabase). See PR1.
2. **Dashboard regression.** Three panels depend on these providers. They must be rewired in lockstep with the provider changes.
3. **AGENTS.md / README drift.** Ownership rules and Core Features need updating; the rule "Budget forms own budget inclusion" is removed.
4. **T-101 (sync fields), T-505 (test coverage) and T-507 (move unit tests out of integration_test/) all touch budget/goal code paths.** They should be done first, OR the merge should re-do their work on the new files. Decision: do T-101/T-505/T-507 first.

## PR breakdown (5 PRs)

### PR0 — Pre-flight (do before PR1)

These existing tasks must finish first; they touch files we're about to rewrite anyway.

- **T-101** Add missing sync fields to Brick models.
- **T-505** Cover the modules that currently have zero tests (so we have a regression net for the merge).
- **T-507** Move real unit tests out of `integration_test/` (the `learning_sync_monetization_flow_test.dart` still imports the soon-to-be-deleted `sync_state.dart`, which T-003 already removed — so this is already half-done, but double-check).

Do not start the merge until PR0 is green.

### PR1 — Data model & migration (no UI)

Goal: new data shape lives, old shape still works, migration is reversible.

1. Add `monthlyLimit`, `period`, `rollover`, `alertThresholds` to `Category` (domain + Brick model + Postgres migration).
2. Add `AccountType.goal`, `targetAmount`, `targetDate`, `priority` to `Account` (domain + Brick model + Postgres migration).
3. Write a one-time migration script: read every `Budget` row → write to `Category.budget` fields, read every `Goal` row → write to `Account` with `type=goal`. Old tables stay for now (deprecated).
4. Update `lib/brick/offline_model_mappers.dart` to read both old and new shapes (old shape returns the new fields populated; new shape returns new fields only). Mappers are the only place the dual-read lives.
5. Tests: full round-trip of the migration in `test/brick/budget_to_category_migration_test.dart` and `test/brick/goal_to_account_migration_test.dart`. Coverage target: a real `Budget` row → equivalent `Category` row with the same `monthlyLimit`; a real `Goal` row → equivalent `Account` row with `type=goal`.

Verify: `flutter test` green; existing `Budget`/`Goal` screens still render.

### PR2 — Domain services & providers (no UI)

Goal: the new services exist; the old ones still exist (called by old UI). The dashboard can be rewired next.

1. Create `CategoryBudgetProgressService` (copy of `BudgetProgressService`, operates on categories).
2. Create `AccountGoalForecastService` (copy of `GoalForecastService`, operates on accounts).
3. Add `categoryBudgetsDerivedProvider` (derives budget map from `categoriesProvider` × `transactionsProvider`).
4. Add `goalAccountsDerivedProvider` (filters `accountsProvider` to `type=goal`).
5. Keep `budgetsProvider` and `goalsProvider` for now; the old screens still call them.

Verify: `flutter analyze` clean; `flutter test` clean; no UI changes.

### PR3 — Dashboard rewiring (UI only)

Goal: the dashboard reads the new providers. Old screens still exist as legacy.

1. Replace `budgetsProvider` reads in `home_dashboard_screen.dart:42, 898, 1685` with `categoryBudgetsDerivedProvider`.
2. Replace `goalsProvider` reads in `home_dashboard_screen.dart:44, 1272` with `goalAccountsDerivedProvider`.
3. Replace `Budget.dailySpendingId` check (in `providers.dart:503`) with a derived "today's spend" calculation.
4. Update `home_dashboard_widget_test.dart` to override the new providers.
5. Update `test/features/dashboard/` mocks to construct `Category` with budget fields and `Account` with `type=goal` instead of `Budget` / `Goal` fixtures.

Verify: dashboard renders identically for an existing user; existing tests pass after fixture swap.

### PR4 — Settings entries (additive)

Goal: all Budget and Goal sub-routes are reachable from Settings. Old screens still exist (re-exported through the same routes).

1. Add 6 entries to the Settings "Planning" group:
   - Budget: Pace → `/settings/pace`
   - Budget: Safe to Spend → `/settings/safe-to-spend`
   - Budget: Cash Flow → `/settings/cash-flow`
   - Budget: Cash Flow (Sankey) → `/settings/cash-flow-sankey`
   - Goals: Saving Plan → `/settings/saving-plan`
   - Goals: Chance of Success → `/settings/chance-of-success`
2. Add the 6 routes to `app_router.dart`. Each route simply delegates to the existing screen widget (zero behavioral change).
3. Test: `test/app/idea_route_coverage_test.dart` + a new `test/app/settings_budget_goals_test.dart` that visits each entry and confirms navigation.

Verify: Settings shows the new entries; tapping each opens the existing screen; no dead routes.

### PR5 — Remove the old features

Goal: the old Budget and Goals modules are gone. This is the risky one.

1. Delete `lib/features/budgets/` (6 files: `application/`, `data/`, `domain/`, `presentation/`).
2. Delete `lib/features/goals/` (9 files).
3. Remove `budgetsProvider` and `goalsProvider` from `lib/app/providers.dart`. Remove `BudgetRepository`, `GoalRepository` providers and their imports.
4. Update `Category` form (`category_editor_sheet.dart`, `category_group_editor_sheet.dart`) to include a "Budget" section for non-default categories (amount, period, rollover, alert thresholds).
5. Update `Account` form (`account_form_screen.dart` and its subforms) to include a "Goal details" subform shown when type=goal.
6. Drop the `budgets` and `goals` Supabase tables in a final migration. Drop the offline model files. Drop the Brick migrations.
7. Update `lib/brick/offline_model_mappers.dart` to remove the old mappings.
8. Update `AGENTS.md` Ownership table and remove the "Budget forms own budget inclusion" rule. Update `README.md` §"Core Features" (delete the "Smart Budgeting" and "Financial Goals" entries; describe the merged behavior under Categories and Accounts).
9. Update `test/helpers/factories.dart` to drop `makeBudget` / `makeGoal` and add `makeCategoryWithBudget` / `makeAccountGoal`.
10. Update all tests that imported the deleted models.

Verify: `flutter analyze` clean; `flutter test` clean; full integration test green; an existing user with budget/goal data opens the app and sees the migrated state on the right screens.

---

## Order of operations

PR0 → PR1 → PR2 → PR3 → PR4 → PR5

PR0 must complete first. PR1–PR4 are additive and can ship in any order once PR0 is green. PR5 is the deletion and is the last PR — it must be a single commit so revert is clean.

## What this plan does NOT cover

- **Pro tier accounting/balance sheets** (advanced double-entry, business reports): untouched.
- **Calculators** (60+): untouched. "Savings Goal" / "Retirement" calculators still exist as standalone tools.
- **Aiko AI features** (insights, monthly review, chat): untouched.
- **Existing T-201 dashboard split, T-202 form split, T-412 broken budget progress bar**: separate tasks. Some of them get easier after this merge.
- **T-617 centralize default baseCurrency/country**: separate task; orthogonal.

## Open questions for the next session

1. **Budget rollover** — is unused budget supposed to carry forward forever, or just one period? AGENTS.md is silent.
2. **Alert thresholds** — current budgets use `[0.5, 0.75, 0.9, 1.0]`. Default per category, or per category-group? Category-level feels right.
3. **Goal account balance** — when an Account has `type=goal`, is its `currentBalance` the saved amount, or does it require a linked savings account? Recommend: `currentBalance` is the saved amount; the "linked account" feature is a stretch goal for a later phase.
4. **Multiple goal targets per category** — current code only allows one budget per category. If the new field is on `Category`, that constraint stays. Confirm.
5. **Migration cutoff** — after PR1, is the dual-read window 1 release, 2 releases, or "until CI shows zero old-shape rows"?

## Acceptance criteria for "the merge is done"

- AGENTS.md Ownership table has no `Budgets` or `Goals` rows.
- `lib/features/budgets/` and `lib/features/goals/` are deleted.
- A user who previously had 5 budgets and 3 goals, after the migration, sees 5 categories with budget fields set and 3 accounts with `type=goal`. The data is identical to before; the screens are different.
- Settings lists 6 new entries under Planning, each tappable, each opening the right sub-screen.
- The dashboard's Category Budgets panel, Aiko Goal Simulator, and Upcoming due dates all render the same numbers as before, sourced from `categoriesProvider` and `accountsProvider`.
- No new test failures. `flutter analyze` clean.
