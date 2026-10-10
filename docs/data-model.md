# Data model

This page lists every persisted record: domain types, Firestore documents, SQLite tables, preference keys and Storage paths. When you change a field, update its codec, migration, Security Rules, round-trip test and this page together ([Contributing](contributing.md#adding-a-field)).

## Conventions

| Rule | Detail |
| --- | --- |
| Money | `Money` (`lib/core/money/money.dart`) wraps `Decimal` plus an ISO currency code. Stored as a **decimal string** (`"1234.50"`) with a separate `currency` field. Security Rules reject numbers for `amount`, `current_balance`, `quantity`, `average_cost` and `current_price`. Never use `double` for money. |
| IDs | Client-generated UUID v4 strings, stable across devices and imports. Default category and group clones use deterministic UUID v5 IDs ([below](#default-taxonomy)). |
| Ownership | Every finance document carries `user_id`, which must equal the `{uid}` path segment. Profiles use the uid as their document ID. |
| Dates | ISO-8601 strings (`DateTime.toIso8601String()`); `updated_at` is UTC. |
| Field names | Domain uses camelCase; Firestore and SQLite use snake_case. `OfflineStore` converts query fields automatically. |
| Versioning | `updated_at` and `version` exist on every record; the Firestore SDK resolves conflicts last-write-wins per document. |
| Deletes | Hard deletes. Listeners on other devices drop the record; no tombstones. |

## Firestore layout

```text
users/{uid}/
  profiles/{uid}
  accounts/{id}
  transactions/{id}
  categories/{id}
  category_groups/{id}
  investment_holdings/{id}
  attachments/{id}
  transaction_splits/{id}     # allowed by rules; not written by the app today
  preferences/{key}           # {value: string}
  integrations/line           # read-only to clients
line_links/{lineUserId}       # server only
line_pairings/{sha256(code)}  # server only
rate_limits/{uid}:{action}    # server only
```

Everything outside these paths is denied. Rules: [Backend → Security Rules](backend.md#security-rules).

### `accounts`

Domain: `Account` (`lib/features/accounts/domain/account.dart`). SQLite: `OfflineAccount`.

| Field | Type | Notes |
| --- | --- | --- |
| `id`, `user_id` | string | |
| `name` | string | |
| `type` | string | `AccountType`: `cash`, `bank`, `eWallet`, `creditCard`, `loan`, `investment`, `asset`, `liability`, `goal`, `other` |
| `currency` | string | Account currency |
| `current_balance` | decimal string | For goals, the amount saved |
| `institution` | string? | |
| `include_in_net_worth`, `is_active` | bool | |
| `details` | map | Type-specific details; stored locally as `details_json` text |
| `goal_target_amount` | decimal string? | Goals only; same currency as the account |
| `goal_target_date` | ISO string? | Goals only |
| `goal_priority` | string | `high`, `medium` (default), `low` |
| `updated_at`, `version` | string, int | |

`details` always has a `_type` discriminator. Money values inside are `{"amount": "…", "currency": "…"}`.

| `_type` | Keys |
| --- | --- |
| `cash`, `bank`, `eWallet` | none |
| `creditCard` | `creditLimit`, `statementDay` (1–31), `dueDay` (1–31), `aprPercent`, `rewardsType` (`cashback`/`points`/`miles`/`none`), `annualFee`, `minimumPayment`, `sharesLimit`, `sharedLimitAccountId` |
| `loan` | `loanType` (`mortgage`/`auto`/`personal`/`student`/`other`), `principal`, `interestRatePercent`, `termMonths`, `monthlyPayment`, `nextDueDate` |
| `investment` | `accountNumberLast4` |
| `asset` | `assetClass` (`cash`/`stocks`/`realEstate`/`vehicle`/`other`), `purchasePrice`, `purchaseDate`, `notes` |
| `liability` | `liabilityType`, `interestRatePercent`, `notes` |
| `other` (also goals) | `notes` |

`AccountValidator` (`lib/features/accounts/domain/account_validator.dart`) enforces the invariants: statement and due days within 1–31, non-negative APR and rates, a credit limit unless the card shares another card's limit, no sharing with itself, matching currencies for limits and loan amounts, at least one term month, and a purchase date whenever a purchase price is set.

### `transactions`

Domain: `FinanceTransaction` (`lib/features/transactions/domain/transaction.dart`). SQLite: `OfflineTransaction`.

| Field | Type | Notes |
| --- | --- | --- |
| `id`, `user_id`, `account_id` | string | |
| `type` | string | `TransactionType` (below) |
| `amount` | decimal string | Must be > 0 except for `adjustment` |
| `currency` | string | |
| `date` | ISO string | |
| `category_id` | string? | A default category's per-user clone ID or a custom category ID |
| `merchant`, `note` | string? | |
| `tags` | string[] | |
| `status` | string | `draft`, `posted` (default), `voided`, `archived` |
| `is_recurring` | bool | |
| `recurring_frequency` | string? | `once`, `daily`, `weekly`, `monthly`, `annually` |
| `recurring_end_date` | ISO string? | Inclusive; null = open-ended |
| `recurring_max_occurrences` | int? | |
| `recurring_day_of_week` | int? | 1 = Monday … 7 = Sunday |
| `recurring_day_of_month` | int? | 1–31, clamped to month length |
| `recurring_month_of_year` | int? | 1–12 |
| `reminder_at` | ISO string? | Local time for a device reminder |
| `updated_at`, `version` | string, int | |

`TransactionType` values: `income`, `expense`, `transfer`, `transferOut`, `transferIn`, `refund`, `investmentBuy`, `investmentSell`, `dividend`, `interest`, `loanPayment`, `creditCardPayment`, `taxPayment`, `fee`, `adjustment`. A transfer is saved as a `transferOut` row on the source account and a `transferIn` row on the destination.

**Balance effect** (`applyToAccountBalance`): `income` and `transferIn` add to the account balance; every other type subtracts. A transaction whose currency differs from its account's currency leaves the balance unchanged, because no exchange rate is stored.

Recurring rows are templates. `RecurringProjection` generates display-only future occurrences with IDs like `<id>#preview#<date>`; previews are never saved.

`FinanceTransaction.splits` exists in the domain, and the repository validates that splits sum to the amount, but the transaction codec does not persist splits and no screen creates them yet.

### `categories`

Domain: `Category` (`lib/features/categories/domain/category.dart`). SQLite: `OfflineCategory`.

| Field | Type | Notes |
| --- | --- | --- |
| `id`, `user_id` | string | |
| `template_id` | string? | Set on default-category clones; the system template ID |
| `name`, `icon`, `color` | string | `color` is `#RRGGBB` |
| `type` | string | `CategoryType`: `income`, `expense`, `transfer`, `finance`, `tax`, `investment`, `adjustment` |
| `group` | string | Fixed 50/30/20 bucket (`CategoryBudgetGroup`): `needs`, `wants`, `savings`, `debt`, `investment`, `tax`, `business`, `custom` |
| `group_id` | string? | User-visible category group |
| `parent_id` | string? | |
| `is_active` | bool | Custom categories are archived (`false`), not deleted |
| `created_at` | ISO string? | |
| `budget_enabled` | bool | |
| `budget_amount`, `budget_currency` | decimal string?, string? | The category's budget limit |
| `budget_period` | string | `daily`, `weekly`, `monthly`, `yearly` |
| `budget_rollover` | bool | Intended to roll unused budget into the next period; stored but not applied by any calculation yet |
| `alert_thresholds` | int[] | Default `[50, 75, 90, 100]` percent |
| `updated_at`, `version` | string, int | |

Budgets are fields on the category; there is no separate budgets collection.

### `category_groups`

Domain: `CategoryGroup`. Fields: `id`, `user_id`, `template_id`, `name`, `icon`, `color`, `sort_order`, `created_at`, `budget_amount`, `budget_currency` (a group-level budget), `updated_at`, `version`.

### `profiles`

Domain: `Profile` (`lib/features/settings/domain/profile.dart`). Document ID = uid.

| Field | Notes |
| --- | --- |
| `id`, `email`, `display_name` | `display_name` defaults to the email's local part |
| `base_currency`, `country`, `timezone` | Defaults `THB`, `TH`, `Asia/Bangkok` (`kDefaultBaseCurrency`, `kDefaultCountry`) |
| `preferred_theme` | `system`, `light`, `dark` |
| `aiko_character_visibility`, `aiko_personality_setting` | Defaults `full`, `supportive` |
| `security_status` | `notConfigured`, `pinEnabled`, `biometricEnabled`, `lockedOut` |
| `full_name`, `gender`, `date_of_birth`, `phone_number` | Optional personal fields; `gender` defaults to `preferNotToSay` |
| `avatar_path` | Device cache path (other devices fall back to the URL) |
| `avatar_url` | Firebase Storage download URL |
| `updated_at`, `version` | |

### `investment_holdings`

Domain: `InvestmentHolding` (`lib/features/investments/domain/investment_holding.dart`). Fields: `id`, `user_id`, `symbol`, `asset_class`, `quantity`, `average_cost`, `current_price`, `market_value` (decimal strings), `currency`, `target_allocation_percent` (number, optional; no UI sets it yet), `created_at`, `updated_at`, `version`.

### `attachments`

Written by `TransactionAttachmentRepository` (`lib/features/transactions/data/transaction_attachment_repository.dart`).

| Field | Notes |
| --- | --- |
| `id`, `user_id`, `created_at` | |
| `linked_entity_type`, `linked_entity_id` | `transaction`, transaction ID |
| `storage_bucket`, `storage_path` | `receipts`, `users/{uid}/receipts/{id}/{file_name}` |
| `file_name`, `content_type`, `size_bytes` | Max 10 MiB |
| `is_sensitive` | bool |
| `export_policy` | `include` or `exclude` (whether exports include the file) |

Supported types: PDF, JPEG, PNG, WebP, HEIC, text/CSV/Markdown and Word. Metadata is also cached per transaction in `LocalFileCache` so it is available offline.

### `preferences`

Small synced settings stored as `{ "value": "<string>" }` through `SyncedPreferences` (`lib/core/storage/synced_preferences.dart`). Signed out, the same keys live in device secure storage.

| Key | Value | Owner |
| --- | --- | --- |
| `aiko_language_code` | `en` or `th`; absent = follow device | `AppLocaleController` |
| `transaction_rules_v1` | JSON array of `TransactionRule` | `TransactionRuleStore` |
| `travel_mode_v1` | JSON of the active trip and exchange rate | `TravelModeNotifier` |

### `integrations/line`

`{connected: true}` once LINE pairing succeeds. Only Cloud Functions write it.

## Device-only storage

These values never sync.

| Store | Key or table | Purpose |
| --- | --- | --- |
| Secure storage | `aiko_offline_user_id` | Current owner ID (`local:<uuid>` or uid) |
| Secure storage | `aiko_known_account` | `true` after a successful sign-in; routes returning users to `/auth` |
| Secure storage | `aiko_defaults_seeded:<uid>` | Stamp recording that this device ensured the user's profile and default categories ([Cost](cost.md)) |
| Secure storage | `transaction_capture_settings` | Android capture on/off and target account |
| `aiko_files.sqlite` | `files(path, bytes)` | Attachment and avatar bytes; attachment metadata cache |
| App support dir | `capture_inbox/*.json` | Captured SMS and notifications waiting to be processed (Android) |

## Local SQLite schema

`AikoBrickRepository` (`lib/brick/repository.dart`) opens `aiko_offline.sqlite` with tables `OfflineAccount`, `OfflineTransaction`, `OfflineCategory`, `OfflineCategoryGroup`, `OfflineInvestmentHolding` and `OfflineProfile`. The schema is `lib/brick/db/schema.g.dart`. Migrations in `lib/brick/db/<timestamp>.migration.dart` run in version order at startup; the latest is `20260725185723` (`template_id` on categories and groups). Earlier migrations folded the old budgets table into categories and the old goals table into accounts.

Rules for local schema changes:

- Existing migrations are immutable. Add a new migration for every column change and register it in `schema.g.dart`.
- Codecs in `lib/brick/adapters/*.dart` and `lib/brick/model_dictionary.dart` are maintained by hand. Keep the SQLite and Firestore halves in sync.
- Domain ↔ Brick mapping lives in `lib/brick/offline_model_mappers.dart`.
- Tolerate legacy NULLs with `fromGenerator` helpers (see `accountDetailsFromSqlite`, `goalPriorityFromColumn`).
- `test/brick/brick_migration_integrity_test.dart` and `test/brick/fresh_database_test.dart` guard the migration chain.

## Default taxonomy

`CategoryDefaults` and `CategoryGroupDefaults` (`lib/features/categories/domain/category_defaults.dart`) define **81 system categories** (11 income, 70 expense) and **13 groups**:

Income & Earnings · Investments & Savings · Food & Drink · Transport · Housing & Utilities · Health & Fitness · Shopping & Personal · Entertainment & Leisure · Education · Travel · Family & Giving · Bills & Financial · Other.

Templates have fixed IDs (for example `00000000-0000-0000-c200-000000000001` for Groceries). Each signed-in user gets clones with deterministic IDs:

```dart
Uuid().v5(namespace, 'category:${uid.toLowerCase()}:${templateId.toLowerCase()}')
```

So every device computes the same clone IDs, sign-in can create them idempotently, and imported transactions that reference template IDs are re-pointed to the user's clones (`CategoryDefaults.categoryIdForUser`). On clones, Security Rules allow edits only to the budget fields, and clones cannot be deleted. In local-only mode the templates are used directly, with stored budget overlays.

## Storage paths

| Path | Contents | Rule |
| --- | --- | --- |
| `users/{uid}/receipts/{id}/{fileName}` | Transaction attachments | Owner only, 1 byte–10 MiB, image/PDF/text/Word |
| `users/{uid}/avatars/avatar.{ext}` | Profile photo | Same |
| `users/{uid}/documents/…`, `users/{uid}/exports/…` | Reserved by rules | Same |

Account deletion removes everything under `users/{uid}/` ([Backend](backend.md#deleteaccount)).
