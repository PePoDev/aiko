# Per-User Default Category Clones Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace invalid fixed-ID budget overlays with deterministic per-user clones of all 81 built-in categories and 13 built-in groups, while draining existing Brick queue jobs without clearing local data.

**Architecture:** PostgreSQL keeps ownerless fixed-ID rows as immutable templates and creates deterministic UUIDv5 clones for each profile. Dart uses the same UUIDv5 namespace and names, treats clone rows as read-only built-ins through `templateId`, and remaps anonymous or legacy template references before sync. Compatibility triggers rewrite legacy POST upserts and transaction references to clone IDs while existing ownership RLS remains authoritative.

**Tech Stack:** Flutter/Dart, Riverpod, Brick offline-first SQLite/Supabase adapters, `uuid` 4.5.3, PostgreSQL, Supabase RLS/PostgREST, pgTAP

---

## File Map

**Create**

- `supabase/migrations/20260725184638_default_category_clones.sql` - canonical templates, clone schema, backfill, UUIDv5 helpers, account setup, integrity and compatibility triggers.
- `supabase/migrations/20260726041549_default_category_clone_guards.sql` - custom-category legacy group rewrites and split/transaction owner enforcement.
- `supabase/migrations/20260726042034_fix_split_trigger_record_guard.sql` - split-only trigger record guard compatible with both transaction tables.
- `supabase/tests/database/default_category_clones.test.sql` - catalog, deterministic clone and idempotent setup coverage.
- `supabase/tests/database/default_category_clones_rls.test.sql` - ownership and cross-user integrity coverage.
- `supabase/tests/database/default_category_clone_compatibility.test.sql` - exact legacy Coffee payload and transaction rewrite coverage.
- `supabase/tests/fixtures/default_category_clones_legacy.sql` - pre-migration fixed-ID overlay and transaction fixture.
- `supabase/tests/migrations/default_category_clones_backfill.test.sql` - legacy budget and reference preservation coverage.
- `test/brick/default_category_clone_serialization_test.dart` - Brick `template_id` round-trip coverage.
- `test/brick/template_id_migration_repair_test.dart` - interrupted local migration recovery coverage.
- `test/core/offline/offline_data_migrator_test.dart` - anonymous clone rekey and local-only cleanup coverage.
- `test/features/transactions/data/transaction_repository_test.dart` - category-template reference normalization coverage.
- `test/features/categories/data/category_repository_test.dart` - same-name custom and built-in category coexistence coverage.

**Modify**

- `supabase/tests/database/default_categories.test.sql` - expand global catalog assertions from categories only to categories and groups.
- `lib/features/categories/domain/category.dart` - add `templateId`, effective template identity and identity-aware `copyWith` support.
- `lib/features/categories/domain/category_defaults.dart` - deterministic clone IDs, user clone factories and legacy normalization.
- `lib/brick/models/category.model.dart` - persist category `template_id`.
- `lib/brick/models/category_group.model.dart` - persist group `template_id`.
- `lib/brick/offline_model_mappers.dart` - round-trip clone identity.
- `lib/brick/adapters/offline_category_adapter.g.dart` - generated category adapter.
- `lib/brick/adapters/offline_category_group_adapter.g.dart` - generated group adapter.
- `lib/brick/db/schema.g.dart` - generated SQLite schema and current migration version.
- `lib/brick/repository.dart` - transactionally repair interrupted `template_id` migrations before Brick initialization.
- `lib/brick/db/20260725185723.migration.dart` - generated local `template_id` column migration.
- `lib/features/categories/data/category_repository.dart` - save clone rows directly, always populate `createdAt`, and exclude built-ins from custom-name conflicts.
- `lib/features/categories/data/category_group_repository.dart` - save group clones directly and protect clone deletion.
- `lib/app/providers.dart` - derive authenticated clones, normalize legacy rows and remove fixed-ID overlay merging.
- `lib/features/transactions/data/transaction_repository.dart` - normalize template references on read and save.
- `lib/core/offline/offline_data_migrator.dart` - claim groups before categories and remap cloned identities and transactions.
- `lib/features/auth/data/auth_repository.dart` - invoke idempotent clone repair after profile upsert and rotate to a fresh anonymous identity on logout.
- `lib/features/auth/presentation/auth_screens.dart` - invalidate user-scoped providers after authentication.
- `lib/features/settings/presentation/profile_screen.dart` - invalidate user-scoped providers after logout.
- `lib/features/transactions/presentation/transaction_form_screen.dart` - consume cloned groups and compare effective template identities.
- `lib/features/categories/presentation/category_management_screen.dart` - keep category/group clone IDs aligned during loading and grouping.
- `test/features/categories/domain/category_defaults_test.dart` - UUIDv5 and clone invariants.
- `test/brick/budget_to_category_migration_test.dart` - mapper coverage for `templateId`.
- `test/app/providers_test.dart` - authenticated/anonymous clone selection and legacy precedence.
- `test/features/auth/auth_repository_test.dart` - clone repair RPC ordering.
- `README.md` - replace global in-memory-only taxonomy guidance with the template/clone model.

Repository policy requires inline execution on `main`. Do not create a worktree, branch, or commit unless the user explicitly asks.

### Task 1: Lock Down PostgreSQL Clone Behavior

**Files:**

- Create: `supabase/tests/database/default_category_clones.test.sql`
- Create: `supabase/tests/database/default_category_clones_rls.test.sql`
- Create: `supabase/tests/database/default_category_clone_compatibility.test.sql`
- Create: `supabase/tests/fixtures/default_category_clones_legacy.sql`
- Create: `supabase/tests/migrations/default_category_clones_backfill.test.sql`
- Modify: `supabase/tests/database/default_categories.test.sql`

- [ ] **Step 1: Expand the global-template test before changing the schema**

Keep the existing 81-category checks and add assertions that currently fail:

```sql
select is(
  (select count(*)::integer from public.category_groups where user_id is null),
  13,
  'all built-in category groups are global templates'
);

select is(
  (select count(*)::integer
   from public.categories
   where user_id is null and group_id is not null),
  81,
  'every category template has its canonical global group'
);

select is(
  (select count(*)::integer
   from public.categories
   where user_id is null
     and (budget_amount is not null or budget_currency is not null)),
  0,
  'global category templates are budget-free'
);
```

Update `plan(...)` to the exact final assertion count.

- [ ] **Step 2: Add deterministic setup tests**

In `default_category_clones.test.sql`, insert two isolated profiles with IDs
`11111111-1111-4111-8111-111111111111` and
`22222222-2222-4222-8222-222222222222`, call
`ensure_default_category_clones` for both, and assert:

```sql
select is(
  public.default_category_group_clone_id(
    '11111111-1111-4111-8111-111111111111',
    '00000000-0000-0000-c300-000000000004'
  ),
  '35c0421d-5cf3-506c-a571-673b06e355e4'::uuid,
  'Food & Drink group clone uses the shared UUIDv5 algorithm'
);

select is(
  public.default_category_clone_id(
    '11111111-1111-4111-8111-111111111111',
    '00000000-0000-0000-c200-000000000003'
  ),
  '72a3b441-4610-5bf3-9df7-ffe1c177faef'::uuid,
  'Coffee clone uses the shared UUIDv5 algorithm'
);

select is(
  (select count(*)::integer from public.category_groups
   where user_id = '11111111-1111-4111-8111-111111111111'
     and template_id is not null),
  13,
  'profile has 13 group clones'
);

select is(
  (select count(*)::integer from public.categories
   where user_id = '11111111-1111-4111-8111-111111111111'
     and template_id is not null),
  81,
  'profile has 81 category clones'
);
```

Also assert a second setup call preserves counts and a changed Coffee budget,
all clone IDs differ between users, every category clone points to its owner's
group clone, and a same-named custom Coffee row can coexist.

- [ ] **Step 3: Add legacy payload and reference tests**

In `default_category_clone_compatibility.test.sql`, run as an authenticated test
user and replay the reported shape:

```sql
insert into public.categories (
  id, user_id, name, type, "group", group_id, parent_id, icon, color,
  budget_enabled, is_active, created_at, budget_amount, budget_currency,
  budget_period, budget_rollover, alert_thresholds, updated_at, version
) values (
  '00000000-0000-0000-c200-000000000003',
  '11111111-1111-4111-8111-111111111111',
  'Coffee', 'expense', 'wants',
  '00000000-0000-0000-c300-000000000004',
  null, 'coffee', '#8B5A2B', true, true, null,
  '3000', 'THB', 'monthly', false, '[50,75,90,100]'::jsonb,
  '2026-07-25T17:58:36.262483Z', 1
) on conflict (id) do update set
  budget_amount = excluded.budget_amount,
  budget_currency = excluded.budget_currency,
  updated_at = excluded.updated_at;
```

Assert the deterministic Coffee clone owns the budget, has non-null
`created_at`, points to the user's Food & Drink clone, and the global Coffee row
remains ownerless and budget-free. Insert a transaction and transaction split
with the fixed Coffee template ID and assert both references become the user's
clone ID.

- [ ] **Step 4: Add RLS tests**

Use `set local role authenticated` plus
`set_config('request.jwt.claim.sub', '11111111-1111-4111-8111-111111111111', true)`. Assert user A can update
its clone but cannot update the global template, see user B's clones, assign a
category to user B's group clone, or create a transaction/split referencing user
B's category. Assert compatibility functions are `SECURITY INVOKER`, and revoke
function execution from `PUBLIC` and `anon` is observable through privileges.

- [ ] **Step 5: Add a staged legacy backfill fixture**

Against the initial schema only, insert two profiles/accounts, a user-owned
fixed Food & Drink group with a budget, a user-owned fixed Coffee category with
distinct budget fields, transactions and transaction splits for both users
referencing fixed Coffee, and a custom category assigned to fixed Food & Drink.
In `supabase/tests/migrations/default_category_clones_backfill.test.sql`, assert after migration that the
fixed rows are global/budget-free, the original owner's clone retained both
budgets, each user's transactions/splits reference its own Coffee clone, the
custom category points to its owner's group clone, and custom row counts remain
unchanged.

- [ ] **Step 6: Run the pgTAP tests and verify RED**

Run on a disposable Supabase CLI database:

```powershell
supabase start
supabase db reset --local --no-seed
supabase test db --local "supabase/tests/database/default_categories.test.sql"
supabase test db --local "supabase/tests/database/default_category_clones.test.sql"
```

Expected: FAIL because group templates, `template_id`, UUIDv5 helpers, clone
setup and compatibility triggers do not exist.

Run the staged backfill test on the disposable database:

```powershell
supabase db reset --local --version 20260708000000 --sql-paths "tests/fixtures/default_category_clones_legacy.sql"
supabase db push --local
supabase test db --local "supabase/tests/migrations/default_category_clones_backfill.test.sql"
```

Expected before the migration exists: FAIL because clone schema and backfill do
not exist.

### Task 2: Implement the Clone Migration and Backfill

**Files:**

- Create: `supabase/migrations/20260725184638_default_category_clones.sql`

- [ ] **Step 1: Create the migration through the Supabase CLI**

Run:

```powershell
supabase migration new default_category_clones
```

Continue with the CLI-generated
`supabase/migrations/20260725184638_default_category_clones.sql` path.

- [ ] **Step 2: Add deterministic identity helpers and schema fields**

The migration must enable `uuid-ossp` in `extensions`, add nullable
`template_id` UUID columns, self-FKs, partial unique indexes on
`(user_id, template_id)`, and deterministic checks. Use these exact helpers:

```sql
create extension if not exists "uuid-ossp" with schema extensions;

create or replace function public.default_category_group_clone_id(
  p_user_id uuid,
  p_template_id uuid
) returns uuid
language sql
immutable strict parallel safe
set search_path = ''
as $$
  select extensions.uuid_generate_v5(
    'ee336da0-4337-4fa0-b100-ec0dddcb5b95'::uuid,
    'group:' || p_user_id::text || ':' || p_template_id::text
  );
$$;

create or replace function public.default_category_clone_id(
  p_user_id uuid,
  p_template_id uuid
) returns uuid
language sql
immutable strict parallel safe
set search_path = ''
as $$
  select extensions.uuid_generate_v5(
    'ee336da0-4337-4fa0-b100-ec0dddcb5b95'::uuid,
    'category:' || p_user_id::text || ':' || p_template_id::text
  );
$$;
```

Drop `categories_user_parent_name_idx` and replace it with the same expression
restricted to `user_id is not null and template_id is null`, so a custom Coffee
does not block the mandatory Coffee clone.

- [ ] **Step 3: Materialize the complete canonical catalog**

Define migration-local catalog tables/CTEs containing all 13 groups and all 81
categories from `CategoryGroupDefaults.all` and `CategoryDefaults.all`. Each
category row must include fixed template ID, name, type, budget group, global
group template ID, icon, color and `budget_enabled`. Assert catalog counts in a
`DO` block before mutating persistent rows:

```sql
if (select count(*) from migration_default_group_templates) <> 13 then
  raise exception 'expected 13 default category groups';
end if;
if (select count(*) from migration_default_category_templates) <> 81 then
  raise exception 'expected 81 default categories';
end if;
```

Do not infer group mapping from names and do not copy the incomplete identity
fields from `20260725174449_seed_default_categories.sql`.

- [ ] **Step 4: Snapshot and canonicalize legacy fixed-ID rows**

Before changing fixed rows, snapshot user-owned fixed-ID categories/groups and
their budget fields into migration-local tables. Then canonicalize fixed IDs as
ownerless, budget-free templates and insert missing templates. Preserve the
legacy owner and budget snapshot for clone insertion.

- [ ] **Step 5: Create and repair clones idempotently**

Implement `public.ensure_default_category_clones(p_user_id uuid default
auth.uid())` as `SECURITY INVOKER`. It must reject an authenticated caller that
passes another user ID, insert groups before categories, derive IDs through the
two helper functions, copy template identity, keep clone budgets on conflict,
and repair category clone `group_id` values. Revoke execute from `PUBLIC` and
`anon`; grant it to `authenticated` and `service_role`.

Add `profiles_10_ensure_default_category_clones`, an `AFTER INSERT` trigger that
calls the same function for `NEW.id`. Run the function for every existing
profile during migration, then apply snapshotted legacy budget values to the
original owner's clone.

- [ ] **Step 6: Backfill references and enforce tenant integrity**

Remap:

```text
custom category fixed group_id -> owner's deterministic group clone
category clone group_id        -> owner's corresponding group clone
transaction category_id        -> transaction owner's category clone
transaction_split category_id  -> split owner's category clone
```

Install invoker validation triggers that require `template_id` to reference an
ownerless template, require category/group ownership to match, and prevent
transactions or splits from referencing another user's category.

- [ ] **Step 7: Add legacy POST compatibility triggers**

Before insert, if a submitted user-owned category/group ID identifies a global
template, rewrite `NEW.id` to the deterministic clone ID, set `template_id`,
canonicalize identity from the template, map `group_id`, and set
`created_at = coalesce(NEW.created_at, now())`. Preserve submitted budget
fields. Add transaction/split triggers that rewrite fixed template references
and reject cross-user clone references.

Trigger names and order:

```text
category_groups_10_rewrite_legacy_template_insert
categories_10_rewrite_legacy_template_insert
category_groups_90_validate_clone
categories_90_validate_clone
transactions_10_rewrite_template_category
transaction_splits_10_rewrite_template_category
```

- [ ] **Step 8: Restrict budget RPCs to owned clones**

Replace `aiko_budget_status`'s category predicate with
`c.user_id = auth.uid()`. Preserve its signature and existing grants. End the
migration with `notify pgrst, 'reload schema';`.

- [ ] **Step 9: Reset the disposable database and verify GREEN**

Run:

```powershell
supabase db reset --local --no-seed
supabase test db --local "supabase/tests/database"
```

Expected: all global-template, clone, compatibility and RLS pgTAP assertions
PASS. Do not apply the migration to the persistent self-hosted stack yet.

Repeat the staged initial-schema fixture command from Task 1 and verify
`supabase/tests/migrations/default_category_clones_backfill.test.sql` also passes after `db push`.

### Task 3: Add Deterministic Clone Identity to the Domain

**Files:**

- Modify: `lib/features/categories/domain/category.dart`
- Modify: `lib/features/categories/domain/category_defaults.dart`
- Modify: `test/features/categories/domain/category_defaults_test.dart`

- [ ] **Step 1: Write failing UUIDv5 and identity tests**

Add tests for the exact PostgreSQL vectors and clone invariants:

```dart
const userA = '11111111-1111-4111-8111-111111111111';

expect(
  CategoryGroupDefaults.cloneIdForUser(
    userId: userA,
    templateId: CategoryGroupDefaults.foodAndDrinkId,
  ),
  '35c0421d-5cf3-506c-a571-673b06e355e4',
);
expect(
  CategoryDefaults.cloneIdForUser(
    userId: userA,
    templateId: CategoryDefaults.coffeeId,
  ),
  '72a3b441-4610-5bf3-9df7-ffe1c177faef',
);

final coffee = CategoryDefaults.forUser(userA).singleWhere(
  (category) => category.templateId == CategoryDefaults.coffeeId,
);
expect(coffee.isDefault, isTrue);
expect(
  coffee.groupId,
  CategoryGroupDefaults.cloneIdForUser(
    userId: userA,
    templateId: CategoryGroupDefaults.foodAndDrinkId,
  ),
);
```

Also assert two users receive different IDs, all 81 categories and 13 groups
are cloned, custom rows remain non-default, and a fixed-ID anonymous template
still reports default.

- [ ] **Step 2: Run the domain test and verify RED**

```powershell
flutter test test/features/categories/domain/category_defaults_test.dart
```

Expected: FAIL because clone helpers and `templateId` do not exist.

- [ ] **Step 3: Implement clone-aware domain models**

Add nullable `templateId` to `Category` and `CategoryGroup`; include it in
identity-aware `copyWith` methods. Add:

```dart
String? get effectiveTemplateId =>
    templateId ?? (CategoryDefaults.allIds.contains(id) ? id : null);
bool get isDefault => effectiveTemplateId != null;
```

For groups, use `CategoryGroupDefaults.systemIds` and keep `isSystem` as an
alias to `isDefault` for existing callers.

- [ ] **Step 4: Implement shared deterministic factories**

Use:

```dart
const _defaultCloneNamespace = 'ee336da0-4337-4fa0-b100-ec0dddcb5b95';

const Uuid().v5(
  _defaultCloneNamespace,
  'category:${userId.toLowerCase()}:${templateId.toLowerCase()}',
);
```

Add corresponding group generation with `group:`. Implement
`CategoryDefaults.forUser`, `CategoryGroupDefaults.forUser`, fixed-reference
mapping, and normalization helpers that preserve legacy budget fields while
rekeying fixed IDs and group references.

- [ ] **Step 5: Format and verify GREEN**

```powershell
dart format lib/features/categories/domain/category.dart lib/features/categories/domain/category_defaults.dart test/features/categories/domain/category_defaults_test.dart
flutter test test/features/categories/domain/category_defaults_test.dart
```

Expected: all default catalog and clone identity tests PASS.

### Task 4: Persist Clone Identity Through Brick

**Files:**

- Modify: `lib/brick/models/category.model.dart`
- Modify: `lib/brick/models/category_group.model.dart`
- Modify: `lib/brick/offline_model_mappers.dart`
- Create: `test/brick/default_category_clone_serialization_test.dart`
- Modify: `test/brick/budget_to_category_migration_test.dart`
- Generate: `lib/brick/adapters/offline_category_adapter.g.dart`
- Generate: `lib/brick/adapters/offline_category_group_adapter.g.dart`
- Generate: `lib/brick/db/schema.g.dart`
- Create: `lib/brick/db/20260725185723.migration.dart`

- [ ] **Step 1: Write failing mapper tests**

Construct category and group `Offline*` rows with a `templateId`, convert each
to domain and back, and assert the same template ID survives. Add adapter
serialization assertions that Supabase maps `template_id` and SQLite maps
`template_id`.

- [ ] **Step 2: Run mapper tests and verify RED**

```powershell
flutter test test/brick/budget_to_category_migration_test.dart test/brick/default_category_clone_serialization_test.dart
```

Expected: FAIL because `templateId` is not accepted or serialized.

- [ ] **Step 3: Add model fields and mapper wiring**

Add to both Brick models:

```dart
@Sqlite(name: 'template_id')
@Supabase(name: 'template_id')
final String? templateId;
```

Wire `templateId` in both directions in `offline_model_mappers.dart`.

- [ ] **Step 4: Regenerate and review Brick artifacts**

```powershell
dart run build_runner build
```

Review generated diffs. The generated `20260725185723` migration must add only nullable
`template_id` columns to `OfflineCategory` and `OfflineCategoryGroup`; remove
spurious generated operations before continuing.

- [ ] **Step 5: Verify GREEN**

```powershell
dart format lib/brick/models/category.model.dart lib/brick/models/category_group.model.dart lib/brick/offline_model_mappers.dart test/brick
flutter test test/brick/budget_to_category_migration_test.dart test/brick/default_category_clone_serialization_test.dart
```

Expected: mapper and adapter tests PASS.

### Task 5: Replace Overlay Merging With Clone Rows

**Files:**

- Modify: `lib/features/categories/data/category_repository.dart`
- Modify: `lib/features/categories/data/category_group_repository.dart`
- Modify: `lib/app/providers.dart`
- Modify: `test/app/providers_test.dart`

- [ ] **Step 1: Write failing provider tests**

Add injectable fake category/group repositories and cover:

```text
anonymous local user -> fixed template IDs remain
custom Coffee -> coexists with built-in Coffee clone
custom category fixed group ID -> authenticated group clone ID
```

- [ ] **Step 2: Run provider tests and verify RED**

```powershell
flutter test test/app/providers_test.dart
```

Expected: FAIL because providers still merge fixed-ID overlays.

- [ ] **Step 3: Make repositories clone-safe**

Remove the special overlay upsert branch. Always set a missing timestamp using
`DateTime.now().toUtc()`, including defaults/clones. Skip duplicate-name checks
for clone rows, save the clone ID directly, and reject deletion when
`effectiveTemplateId != null`.

Expose `currentUserId()` and `list({String? userId})` so providers query and
derive clones for the same resolved user.

- [ ] **Step 4: Implement authenticated and anonymous provider branches**

For authenticated IDs, select each template in canonical order with precedence:

```text
stored row with templateId -> normalized fixed-ID legacy row -> derived clone
```

Append active custom rows without name-based suppression. For `local:` IDs,
retain fixed templates and the current local overlay behavior until sign-in.
Apply the same precedence to groups, with custom groups first and built-in
groups afterward.

- [ ] **Step 5: Format and verify GREEN**

```powershell
dart format lib/features/categories/data lib/app/providers.dart test/app/providers_test.dart
flutter test test/app/providers_test.dart
```

Expected: clone selection and existing provider tests PASS.

### Task 6: Remap Anonymous and Legacy Transaction References

**Files:**

- Modify: `lib/features/transactions/data/transaction_repository.dart`
- Modify: `lib/core/offline/offline_data_migrator.dart`
- Create: `test/features/transactions/data/transaction_repository_test.dart`
- Create: `test/core/offline/offline_data_migrator_test.dart`

- [ ] **Step 1: Write failing repository and migrator tests**

Assert authenticated reads/saves map fixed Coffee to the user's deterministic
clone, while null/custom/already-cloned IDs and anonymous fixed IDs remain
unchanged. For claiming, assert operation order is group, category, transaction;
fixed rows are rekeyed with `templateId`; custom IDs remain; custom categories'
fixed `groupId` values are mapped; and old rekeyed rows are deleted with
`localOnly: true`.

- [ ] **Step 2: Run tests and verify RED**

```powershell
flutter test test/features/transactions/data/transaction_repository_test.dart test/core/offline/offline_data_migrator_test.dart
```

Expected: FAIL because reference mapping and group claiming do not exist.

- [ ] **Step 3: Normalize transaction repository references**

Resolve the owner once. For non-`local:` users, map fixed template category IDs
on both read and save through `CategoryDefaults.categoryIdForUser`; do not map
custom or clone IDs.

- [ ] **Step 4: Extend anonymous data claiming**

Claim in this order:

```text
accounts -> category groups -> categories -> transactions
```

Use domain normalization helpers. If rekeying changes a row ID, upsert the new
row first and then call `OfflineStore.delete(oldRow, localOnly: true)`. Map each
claimed transaction's fixed template category ID before upserting it for the
real user. Repeated claiming must return zero once old local rows are gone.

- [ ] **Step 5: Format and verify GREEN**

```powershell
dart format lib/features/transactions/data/transaction_repository.dart lib/core/offline/offline_data_migrator.dart test/features/transactions/data/transaction_repository_test.dart test/core/offline/offline_data_migrator_test.dart
flutter test test/features/transactions/data/transaction_repository_test.dart test/core/offline/offline_data_migrator_test.dart
```

Expected: all normalization and claiming tests PASS.

### Task 7: Repair Clones During Auth and Align Category UI Identity

**Files:**

- Modify: `lib/features/auth/data/auth_repository.dart`
- Modify: `lib/features/auth/presentation/auth_screens.dart`
- Modify: `lib/features/settings/presentation/profile_screen.dart`
- Modify: `lib/features/transactions/presentation/transaction_form_screen.dart`
- Modify: `lib/features/categories/presentation/category_management_screen.dart`
- Modify: `test/features/auth/auth_repository_test.dart`

- [ ] **Step 1: Write the failing auth ordering test**

Extend the existing Supabase mock so
`ensureProfileAndDefaultsExistForTesting(...)` must perform:

```text
profiles upsert -> ensure_default_category_clones RPC -> account lookup/default
```

Assert the RPC is called on every repair path, not only new profile insertion.

- [ ] **Step 2: Run the auth test and verify RED**

```powershell
flutter test test/features/auth/auth_repository_test.dart
```

Expected: FAIL because the clone repair RPC is not called.

- [ ] **Step 3: Call clone repair before anonymous claiming**

After profile upsert, call:

```dart
await client.rpc('ensure_default_category_clones');
```

Keep `_ensureProfileAndDefaultsExist` before `_prepareOfflineDataForSync` on
sign-in and restore so parent clones exist before queued claimed transactions.

- [ ] **Step 4: Invalidate cached user-scoped providers**

After authentication and logout, invalidate categories, category groups,
transactions, accounts and profile providers. This prevents a kept-alive prior
user or anonymous taxonomy from appearing after identity changes.

- [ ] **Step 5: Stop rebuilding raw fixed-ID groups in UI**

Use the loaded `categoryGroupsProvider` rows directly in transaction/category
grouping. Replace fixed group ID checks with
`group.effectiveTemplateId == CategoryGroupDefaults.unfiledGroupId`. During
loading, derive `CategoryGroupDefaults.forUser(...)` when categories are clones
instead of mixing cloned categories with fixed group IDs.

- [ ] **Step 6: Format and verify targeted tests**

```powershell
dart format lib/features/auth lib/features/settings/presentation/profile_screen.dart lib/features/transactions/presentation/transaction_form_screen.dart lib/features/categories/presentation/category_management_screen.dart test/features/auth/auth_repository_test.dart
flutter test test/features/auth/auth_repository_test.dart test/app/providers_test.dart
```

Expected: auth ordering and provider tests PASS.

### Task 8: Apply Locally, Drain Job 14, and Run Final Gates

**Files:**

- Modify: `README.md`

- [ ] **Step 1: Update repository guidance**

Document ownerless global templates, deterministic per-user clones,
`template_id`, account setup, anonymous remapping and the rule that clone IDs
are never edited or deleted as custom taxonomy.

- [ ] **Step 2: Run Supabase security and migration checks**

```powershell
supabase db advisors --local
supabase migration list --local
supabase test db --local "supabase/tests/database"
```

Expected: no new security findings, migration ordering is correct, and all
pgTAP tests PASS.

- [ ] **Step 3: Apply the tested migration to the persistent local stack**

Use the repo's configured self-hosted connection without printing credentials.
Do not run `db reset`. After applying, verify:

```sql
select count(*) from public.category_groups where user_id is null;
select count(*) from public.categories where user_id is null;
select count(*) from public.categories
where user_id = '11111111-1111-4111-8111-111111111111'
  and template_id is not null;
```

Expected: `13`, `81`, `81`.

- [ ] **Step 4: Replay the sanitized HTTP request**

Create a fresh test user/token and POST the reported Coffee body through
PostgREST with `created_at: null`. Expected: HTTP 2xx; the user's Coffee clone
has the submitted budget; global Coffee is unchanged. Never commit or print the
token.

- [ ] **Step 5: Restart the app and verify the persisted queue**

Hot restart or rebuild so Brick loads the regenerated schema and HTTP client.
Verify `HttpJobs.id = 14` disappears and Kong/PostgREST records a 2xx category
POST. Do not clear app data. If the emulator was recreated and job 14 no longer
exists, document that live queue-drain verification was unavailable and retain
the exact compatibility replay as evidence.

- [ ] **Step 6: Run formatting and complete Flutter verification**

```powershell
dart format --set-exit-if-changed .
flutter analyze
flutter test
git diff --check
```

Expected: formatter exits 0, analyzer reports no issues, all Flutter tests pass,
and diff check reports no whitespace errors.

- [ ] **Step 7: Inspect the final diff**

```powershell
git status --short
git diff --stat
git diff
```

Confirm only the approved template/clone design, regression tests, generated
Brick artifacts and documentation changed. Do not commit unless explicitly
requested.
