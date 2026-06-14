# Handoff — Expand the single "System" category group into meaningful default groups

> **For the implementing agent.** This is self-contained; you do not need the originating conversation.
> Read this top to bottom, confirm the **Decisions to make** section with the user, then implement.
> Keep diffs minimal and follow `CLAUDE.md` (Architecture + Design System + Backend rules).

---

## 1. Goal

Today Aiko ships **one** global category group called **"System"** that owns all 30 built-in
categories. We want to replace it with a set of **meaningful, budget-friendly default groups**
(Food & Drink, Transport, Health & Fitness, …), each holding well-chosen default categories, so a
brand-new user lands on a sensible taxonomy they can budget against immediately.

Hard constraints:

- **Never change an existing fixed UUID or delete an existing default category** — live transactions
  reference them by id. We only **re-file** existing categories into new groups and **add** new ones.
- **Append-only migrations** — never edit an existing `supabase/migrations/*.sql`; add a new one.
- Defaults stay **global** (`user_id = NULL`), injected in-memory, never stored per-user in Brick.

---

## 2. How the system works today (architecture you must preserve)

There are **two different "group" concepts** — do not conflate them:

| Concept | Where | Purpose |
| --- | --- | --- |
| `CategoryBudgetGroup` (enum) | `lib/features/categories/domain/category.dart` | Fixed 50/30/20 taxonomy: `needs, wants, savings, debt, investment, tax, business, custom`. This is what **budgeting math** reads. Every category carries one via `Category.group`. |
| `CategoryGroup` (class) | same file | **Organisational bucket** that sections the Categories screen. Category links to it via `Category.groupId`. This is the thing we are expanding from 1 → many. |

**A category therefore needs BOTH:** a `group` (budget bucket) *and* a `groupId` (visual group).

### Three sources of truth that MUST stay in sync

1. **Dart** — `lib/features/categories/domain/category_defaults.dart`
   - `CategoryDefaults` — the 30 categories as domain objects + their fixed UUIDs + `allIds` set + `legacySlugToUuid`.
   - `CategoryGroupDefaults` — currently only `system` (one group) + `systemId` + `systemSortOrder`.
2. **SQL (categories)** — `supabase/migrations/20260613120000_system_categories.sql` inserts the 30 rows (`user_id = NULL, is_default = true`).
3. **SQL (group + filing)** — `supabase/migrations/20260614120000_system_category_group.sql` inserts the System group and `update categories set group_id = …systemId where user_id is null`.

### UUID scheme (stable — extend, never reshuffle)

- `…-c100-…` = income categories (currently `0001`–`000a`, i.e. 10 used).
- `…-c200-…` = expense categories (currently `0001`–`0013` hex, i.e. 19 used).
- `…-c300-…` = category groups (only `0001` = "System").

New rows simply continue each block in hex (income next = `…000b`, expense next = `…0014`, groups next = `…0002`).

### In-memory injection (no Brick storage for defaults)

- Groups: `categoryGroupsProvider.build()` in `lib/app/providers.dart` returns
  `[...userGroups, CategoryGroupDefaults.system]`.
- Categories: `CategoryService.defaultCategoriesFor()` returns `CategoryDefaults.all`, merged in
  `lib/features/categories/presentation/category_management_screen.dart`.
- **No `build_runner`** is needed — this is data + light logic only, no Brick model field changes.

### The "absorb unfiled" behaviour (critical)

`category_management_screen.dart::_belongsToGroup` makes the **System** group also claim every unfiled
custom category (`groupId == null/empty`). When we split System into many groups, **exactly one** group
must keep this absorber role (recommend the renamed "Other" group). See Decision D3.

### Other touch points that key off "is this the system group?"

- `CategoryGroup.isSystem => id == CategoryGroupDefaults.systemId` (single id today).
- Editor blocks adding into / editing system groups: `onAddCategory: group.isSystem ? null : …` and the
  group picker in `category_editor_sheet.dart` excludes system groups.
- `category_management_screen.dart` (~lines 120-126) filters out system groups then re-appends the single
  System group for ordering.
- Icons: string key → Material icon in `lib/features/categories/presentation/category_visual.dart`
  (`aikoCategoryIcon` switch + `aikoCategoryIconPresets`). New categories using new icon keys need entries here.

---

## 3. Decisions to make (confirm with the user before coding)

- **D1 — Granularity.** The proposed taxonomy below is intentionally rich (e.g. Food & Drink → Lunch,
  Dinner, Dessert, Bubble Tea, Snacks). Very fine leaves look nice but dilute per-category budgets and
  can overwhelm onboarding. *Recommendation:* ship the full set but mark the "trim candidates" (★) as the
  first things to cut if the user wants leaner defaults.
- **D2 — Rename `c300…0001` "System" → "Other".** Keep the **stable id**, just change the display name,
  and keep it as the last group + the unfiled absorber. End users shouldn't see a group literally named
  "System". *Recommendation: yes.*
- **D3 — Which group absorbs unfiled custom categories?** Recommend the renamed **Other** group (id
  `c300…0001`). Introduce `CategoryGroupDefaults.unfiledGroupId = systemId` and switch `_belongsToGroup`
  to gate the absorber on `group.id == unfiledGroupId` instead of `group.isSystem`.
- **D4 — Can users add their own categories *into* a default group?** Today the UI blocks adding into a
  system group. Allowing it (a user-owned category row with `group_id` = a global group id — already valid
  via the FK + per-user RLS) makes the meaningful groups far more useful. *Recommendation: allow it* —
  change `onAddCategory` to be enabled for default groups while still blocking renaming/deleting the group
  itself. If the user prefers frozen defaults, skip this and leave `onAddCategory` null for system groups.
- **D5 — Group ordering.** Recommend default groups sort **after** any user-created groups (preserves
  today's behaviour) but in a deliberate internal order: Income → Investments → everyday expense groups →
  Other last. Encoded via `sortOrder` (see table).

---

## 4. Proposed default taxonomy

13 groups, ~66 categories. **EXISTING** = keep id, just re-file into the new group. **NEW** = add row.
`budget` = `CategoryBudgetGroup`. `budgetEnabled` = `true` for expense, `false` for income (keep the
existing `_sys` rule). ★ = trim candidate (D1).

### Groups (`category_groups`, `user_id = NULL`)

| Group id (`…-c300-…`) | Name | icon | color | sort_order | role |
| --- | --- | --- | --- | --- | --- |
| `0002` | Income & Earnings | salary | `#16A34A` | `1<<20 +1` | income |
| `0003` | Investments & Savings | investment | `#8B5CF6` | `1<<20 +2` | income/returns |
| `0004` | Food & Drink | food | `#F97316` | `1<<20 +3` | expense |
| `0005` | Transport | transport | `#3B82F6` | `1<<20 +4` | expense |
| `0006` | Housing & Utilities | housing | `#7C3AED` | `1<<20 +5` | expense |
| `0007` | Health & Fitness | health | `#10B981` | `1<<20 +6` | expense |
| `0008` | Shopping & Personal | shopping | `#EC4899` | `1<<20 +7` | expense |
| `0009` | Entertainment & Leisure | entertainment | `#F43F5E` | `1<<20 +8` | expense |
| `000a` | Education | education | `#F59E0B` | `1<<20 +9` | expense |
| `000b` | Travel | travel | `#38BDF8` | `1<<20 +10` | expense |
| `000c` | Family & Giving | gift | `#6366F1` | `1<<20 +11` | expense |
| `000d` | Bills & Financial | fee | `#DC2626` | `1<<20 +12` | expense |
| `0001` | **Other** *(existing "System", renamed)* | category | `#64748B` | `1<<20 +99` | catch-all / **unfiled absorber** |

### Income & Earnings (`group_id c300…0002`)

| Category id (`…-c100-…`) | Name | budget | icon | status |
| --- | --- | --- | --- | --- |
| `0001` | Salary | custom | salary | EXISTING |
| `0002` | Bonus | custom | gift | EXISTING |
| `0003` | Freelance | business | work | EXISTING |
| `0004` | Business | business | business | EXISTING |
| `0008` | Refunds | custom | refund | EXISTING |
| `0009` | Gift Received *(currently "Gift")* | custom | gift | EXISTING |
| `000a` | Other Income *(currently "Other")* | custom | category | EXISTING |

### Investments & Savings (`group_id c300…0003`)

| Category id | Name | budget | icon | status |
| --- | --- | --- | --- | --- |
| `c100…0005` | Interest | savings | savings | EXISTING |
| `c100…0006` | Dividends | investment | investment | EXISTING |
| `c100…0007` | Rental Income *(currently "Rental")* | investment | home | EXISTING |
| `c100…000b` | Capital Gains ★ | investment | investing | NEW |

### Food & Drink (`group_id c300…0004`)

| Category id | Name | budget | icon | status |
| --- | --- | --- | --- | --- |
| `c200…0001` | Groceries | needs | groceries | EXISTING |
| `c200…0002` | Dining Out *(currently "Dining")* | wants | dining | EXISTING |
| `c200…0003` | Coffee | wants | coffee | EXISTING |
| `c200…0014` | Lunch | wants | dining | NEW |
| `c200…0015` | Dinner | wants | dining | NEW |
| `c200…0016` | Dessert ★ | wants | dessert | NEW |
| `c200…0017` | Bubble Tea ★ | wants | drink | NEW |
| `c200…0018` | Drinks / Bar ★ | wants | drink | NEW |
| `c200…0019` | Snacks ★ | wants | snack | NEW |

### Transport (`group_id c300…0005`)

| Category id | Name | budget | icon | status |
| --- | --- | --- | --- | --- |
| `c200…0004` | Transport | needs | transport | EXISTING |
| `c200…0005` | Fuel | needs | fuel | EXISTING |
| `c200…001a` | Taxi / Rideshare | needs | taxi | NEW |
| `c200…001b` | Parking | needs | parking | NEW |
| `c200…001c` | Vehicle Maintenance | needs | maintenance | NEW |
| `c200…001d` | Tolls ★ | needs | transport | NEW |

### Housing & Utilities (`group_id c300…0006`)

| Category id | Name | budget | icon | status |
| --- | --- | --- | --- | --- |
| `c200…0006` | Rent / Mortgage *(currently "Rent")* | needs | home | EXISTING |
| `c200…0007` | Utilities | needs | utilities | EXISTING |
| `c200…0008` | Phone | needs | phone | EXISTING |
| `c200…0009` | Internet | needs | internet | EXISTING |
| `c200…001e` | Home Maintenance | needs | maintenance | NEW |
| `c200…001f` | Furniture & Appliances ★ | wants | furniture | NEW |

### Health & Fitness (`group_id c300…0007`)

| Category id | Name | budget | icon | status |
| --- | --- | --- | --- | --- |
| `c200…000c` | Health | needs | health | EXISTING |
| `c200…000d` | Insurance | needs | insurance | EXISTING |
| `c200…0020` | Pharmacy / Medicine | needs | medicine | NEW |
| `c200…0021` | Dental ★ | needs | dental | NEW |
| `c200…0022` | Fitness / Gym | wants | gym | NEW |

### Shopping & Personal (`group_id c300…0008`)

| Category id | Name | budget | icon | status |
| --- | --- | --- | --- | --- |
| `c200…000b` | Shopping | wants | shopping | EXISTING |
| `c200…0023` | Clothing | wants | clothing | NEW |
| `c200…0024` | Electronics | wants | electronics | NEW |
| `c200…0025` | Personal Care | wants | personal_care | NEW |

### Entertainment & Leisure (`group_id c300…0009`)

| Category id | Name | budget | icon | status |
| --- | --- | --- | --- | --- |
| `c200…0010` | Entertainment | wants | entertainment | EXISTING |
| `c200…000a` | Subscriptions | wants | subscriptions | EXISTING |
| `c200…0026` | Movies ★ | wants | movie | NEW |
| `c200…0027` | Games ★ | wants | game | NEW |
| `c200…0028` | Music / Streaming ★ | wants | music | NEW |
| `c200…0029` | Concerts / Events ★ | wants | concert | NEW |
| `c200…002a` | Hobbies | wants | hobby | NEW |

### Education (`group_id c300…000a`)

| Category id | Name | budget | icon | status |
| --- | --- | --- | --- | --- |
| `c200…000e` | Education | needs | education | EXISTING |
| `c200…002b` | Books | needs | book | NEW |
| `c200…002c` | Courses | needs | education | NEW |

### Travel (`group_id c300…000b`)

| Category id | Name | budget | icon | status |
| --- | --- | --- | --- | --- |
| `c200…000f` | Travel | wants | travel | EXISTING |
| `c200…002d` | Flights ★ | wants | travel | NEW |
| `c200…002e` | Accommodation ★ | wants | hotel | NEW |
| `c200…002f` | Foreign Fees ★ | wants | fee | NEW |

### Family & Giving (`group_id c300…000c`)

| Category id | Name | budget | icon | status |
| --- | --- | --- | --- | --- |
| `c200…0030` | Gifts | wants | gift | NEW |
| `c200…0031` | Childcare | needs | childcare | NEW |
| `c200…0032` | Pets | needs | pet | NEW |
| `c200…0033` | Donations / Charity | custom | donation | NEW |

### Bills & Financial (`group_id c300…000d`)

| Category id | Name | budget | icon | status |
| --- | --- | --- | --- | --- |
| `c200…0011` | Fees | custom | fee | EXISTING |
| `c200…0012` | Taxes | tax | tax | EXISTING |
| `c200…0034` | Loan Payment | debt | loan | NEW |
| `c200…0035` | Credit Card Payment | debt | credit_card | NEW |
| `c200…0036` | Savings Contribution | savings | savings | NEW |

### Other (`group_id c300…0001`, absorber)

| Category id | Name | budget | icon | status |
| --- | --- | --- | --- | --- |
| `c200…0013` | Other | custom | category | EXISTING |

> **Note on renames:** "Gift"→"Gift Received", "Other"(income)→"Other Income", "Dining"→"Dining Out",
> "Rental"→"Rental Income", "Rent"→"Rent / Mortgage" are **display-only** (ids unchanged) and safe.
> `legacySlugToUuid` is keyed by old slug, not name, so renames don't touch it. If the user prefers zero
> renames, keep the current names — they still work.

---

## 5. New icon keys to add

`category_visual.dart` maps unknown keys to a generic icon, so the app won't crash, but add these to
`aikoCategoryIcon` (and optionally `aikoCategoryIconPresets`) for correct glyphs. Suggested Material icons:

| key | Material icon |
| --- | --- |
| `dessert` | `Icons.icecream_outlined` |
| `drink` | `Icons.local_bar_outlined` |
| `snack` | `Icons.bakery_dining_outlined` |
| `taxi` | `Icons.local_taxi_outlined` |
| `parking` | `Icons.local_parking_outlined` |
| `maintenance` | `Icons.build_outlined` |
| `furniture` | `Icons.chair_outlined` |
| `medicine` | `Icons.medication_outlined` |
| `dental` | `Icons.medical_information_outlined` |
| `clothing` | `Icons.checkroom_outlined` |
| `electronics` | `Icons.devices_outlined` |
| `personal_care` | `Icons.spa_outlined` |
| `movie` | `Icons.movie_outlined` |
| `game` | `Icons.sports_esports_outlined` |
| `music` | `Icons.music_note_outlined` |
| `concert` | `Icons.confirmation_number_outlined` |
| `hobby` | `Icons.palette_outlined` |
| `book` | `Icons.menu_book_outlined` |
| `hotel` | `Icons.hotel_outlined` |
| `childcare` | `Icons.child_care_outlined` |
| `pet` | `Icons.pets_outlined` |
| `donation` | `Icons.volunteer_activism_outlined` |
| `loan` | `Icons.account_balance_outlined` |
| `credit_card` | `Icons.credit_card_outlined` |

(`investing`, `gym`, `home`, `dining`, `travel`, `fee` etc. already exist — reuse them.)

---

## 6. File-by-file change plan

1. **`lib/features/categories/domain/category_defaults.dart`**
   - `CategoryGroupDefaults`: add a fixed-UUID const per new group; add `unfiledGroupId = systemId`;
     add `systemIds` (Set of all 13 group ids) and `all` (List<CategoryGroup> of all 13, with the
     `sortOrder`s above). Keep `system`/`systemId` for back-compat (rename its display to "Other").
   - `CategoryDefaults`: add the new category UUID consts; add them to `allIds`; add their `_sys(...)`
     entries. Give `_sys` a `required String groupId` param and pass the correct group id per category
     (today it hard-codes `systemId`). Keep `budgetEnabled: type == CategoryType.expense`.
2. **`lib/features/categories/domain/category.dart`**
   - `CategoryGroup.isSystem` → `CategoryGroupDefaults.systemIds.contains(id)`.
3. **`lib/app/providers.dart`**
   - `categoryGroupsProvider.build()` → `return [...userGroups, ...CategoryGroupDefaults.all];`
4. **`lib/features/categories/presentation/category_management_screen.dart`**
   - Replace the single `CategoryGroupDefaults.system` append (~lines 120-126) with all of
     `CategoryGroupDefaults.all`.
   - `_belongsToGroup`: gate the unfiled-absorber branch on `group.id == CategoryGroupDefaults.unfiledGroupId`
     (not `group.isSystem`); all groups still claim categories whose `groupId == group.id`.
   - (D4, optional) allow `onAddCategory` for default groups.
5. **`lib/features/categories/presentation/category_editor_sheet.dart`**
   - If D4 is adopted, the group picker should offer default groups as assignment targets (today it
     excludes system groups). Otherwise leave as-is.
6. **`lib/features/categories/presentation/category_visual.dart`** — add the new icon-key cases (Section 5).
7. **New migration `supabase/migrations/2026MMDDHHMMSS_default_category_groups.sql`** (append-only):
   - `insert into category_groups …` the 12 new groups (`user_id = NULL`), and
     `update category_groups set name = 'Other' where id = '…c300…0001'`.
   - `insert into categories …` the ~36 new category rows (`user_id = NULL, is_default = true`,
     matching budget `group`, icon, color, `budget_enabled`).
   - `update categories set group_id = '<group-uuid>' where id = '<category-uuid>'` for **every** default
     category (existing + new) so each lands in its new group. Use `on conflict (id) do nothing` on inserts.
   - Optional display renames via `update … set name = …` for the 5 renamed categories (D…).

---

## 7. Tests to update / add

Run `flutter test` and fix fallout. Known assertions that will break:

- **`test/features/categories/category_management_screen_widget_test.dart`** — multiple `find.text('System')`
  expectations, the `system-group-section` key, `add-category-in-group-<systemId>` absence, the
  "group picker excludes the System group" test, and the `_CategoriesGroupsNotifier` that injects only
  `CategoryGroupDefaults.system`. Update to the new group names ("Other", "Food & Drink", …) and inject
  `CategoryGroupDefaults.all`.
- Add a focused test asserting: (a) every `CategoryDefaults` entry has a `groupId` in
  `CategoryGroupDefaults.systemIds`; (b) `CategoryDefaults.allIds.length` equals the new total; (c) the
  **Other** group still absorbs an unfiled custom category; (d) each new group renders its expected
  categories on the management screen.
- Sanity-check `test/features/budgets/budget_goal_widget_test.dart` and
  `test/features/transactions/transaction_detail_screen_widget_test.dart` still pass (they reference
  `CategoryDefaults.*Id`s that are unchanged).

---

## 8. Docs to update (count + naming)

- **`CLAUDE.md`** — "30 global system rows", "30 global system categories", and the `categories` table row
  ("30 global system rows") → new count. Update the Architecture note that says system categories belong to
  "the global, read-only **System** category group" to describe the new multi-group default set + the
  "Other" absorber.
- **`README.md`** — any "30 … system categories" / "System group" references.
- Dart + SQL doc comments that say "30 system categories" / "single global System group".

---

## 9. Quality gates (run all before claiming done — from `CLAUDE.md`)

```bash
dart format --set-exit-if-changed .
flutter analyze
flutter test
flutter test integration_test
```

`dart run build_runner build` is **not** required (no Brick model field changes). If you (against this
plan) add a Brick model field, you must run it and commit generated output.

To apply the migration to a dev project: `supabase db push` (never edit shipped migrations).

---

## 10. Risks / gotchas checklist

- [ ] Existing category UUIDs unchanged; only `group_id` re-filed and (optional) display names changed.
- [ ] Exactly **one** group (Other) keeps the unfiled-absorber role — verify a custom category with null
      `groupId` shows up under Other and nowhere else.
- [ ] All 13 default groups are read-only (`isSystem` true) — can't be renamed/deleted; (D4) may allow
      *adding categories into* them while still blocking group edits.
- [ ] `sortOrder`s keep user-created groups first and "Other" last.
- [ ] New `category_groups` migration runs after `20260614120000_*` and uses `on conflict do nothing`.
- [ ] Every supplemental/Categories screen renders without a Supabase session (defaults are in-memory).
- [ ] Budget `group` (needs/wants/…) chosen per leaf so 50/30/20 + Safe-to-Spend stay sensible.
- [ ] Icon keys added to `category_visual.dart`; no category falls back to the generic glyph unintentionally.
