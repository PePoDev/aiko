# Data model

This page lists every persisted record: domain types, Firestore documents, the local record store, preference keys, device-only values and Storage paths. When you change a field, update its record, codec and mapper, Security Rules, round-trip test and this page together ([Contributing](contributing.md#adding-a-field)).

## Conventions

| Rule | Detail |
| --- | --- |
| Money | `Money` (`lib/core/money/money.dart`) wraps `Decimal` plus an ISO currency code. Stored as a **decimal string** (`"1234.50"`) with a separate `currency` field. Security Rules reject numbers for `amount`, `current_balance`, `quantity`, `average_cost` and `current_price`. Never use `double` for money. |
| IDs | Client-generated UUID v4 strings, stable across devices and imports. Default category and group clones use deterministic UUID v5 IDs ([below](#default-taxonomy)). |
| Ownership | Every finance document carries `user_id`, which must equal the `{uid}` path segment. Profiles use the uid as their document ID. |
| Dates | ISO-8601 strings (`DateTime.toIso8601String()`); `updated_at` is UTC. |
| Field names | Domain uses camelCase; Firestore documents and local records (the same rows) use snake_case. `RecordQuery.orderBy` takes the row field name, for example `date`. |
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
  preferences/{key}           # {value: string} or {items: {item: string}}
  integrations/line           # read-only to clients
line_links/{lineUserId}       # server only
line_pairings/{sha256(code)}  # server only
rate_limits/{uid}:{action}    # server only
```

Everything outside these paths is denied. Rules: [Backend → Security Rules](backend.md#security-rules).

### `accounts`

Domain: `Account` (`lib/features/accounts/domain/account.dart`). Record: `OfflineAccount`.

| Field | Type | Notes |
| --- | --- | --- |
| `id`, `user_id` | string | |
| `name` | string | |
| `type` | string | `AccountType`: `cash`, `bank`, `eWallet`, `creditCard`, `loan`, `investment`, `asset`, `liability`, `goal`, `other` |
| `currency` | string | Account currency |
| `current_balance` | decimal string | For goals, the amount saved |
| `institution` | string? | |
| `include_in_net_worth`, `is_active` | bool | |
| `details` | map | Type-specific details; `OfflineAccount.detailsJson` holds the same map as JSON text |
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

Domain: `FinanceTransaction` (`lib/features/transactions/domain/transaction.dart`). Record: `OfflineTransaction`.

| Field | Type | Notes |
| --- | --- | --- |
| `id`, `user_id`, `account_id` | string | |
| `type` | string | `TransactionType` (below) |
| `amount` | decimal string | Must be > 0, except `adjustment`, whose amount is signed (positive raises the balance, negative lowers it) |
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
| `transfer_group_id` | string? | Shared by the two legs of one transfer so they are edited and deleted together; null on other rows and on legs saved before legs were linked |
| `updated_at`, `version` | string, int | |

`TransactionType` values: `income`, `expense`, `transfer`, `transferOut`, `transferIn`, `refund`, `investmentBuy`, `investmentSell`, `dividend`, `interest`, `loanPayment`, `creditCardPayment`, `taxPayment`, `fee`, `adjustment`. A transfer is saved as a `transferOut` row on the source account and a `transferIn` row on the destination, linked by `transfer_group_id`. `transfer` is a legacy single-row type. An `adjustment` is a balance correction: an account's opening balance, or the difference when its balance is edited; it is never income or spending.

**Balance effect** (`applyToAccountBalance`): the inflow types (`income`, `transferIn`, `refund`, `dividend`, `interest`, `investmentSell`) add their amount, an `adjustment` adds its signed amount, and every other type subtracts. A transaction whose currency differs from its account's currency leaves the balance unchanged, because no exchange rate is stored ([Calculations](calculations.md#account-balances)).

Recurring rows are templates. `RecurringProjection` generates display-only future occurrences with IDs like `<id>#preview#<date>`; previews are never saved.

`FinanceTransaction.splits` exists in the domain, and the repository validates that splits sum to the amount, but the transaction codec does not persist splits and no screen creates them yet.

### `categories`

Domain: `Category` (`lib/features/categories/domain/category.dart`). Record: `OfflineCategory`.

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
| `created_at` | ISO string? | Stamped on new custom categories. Default clones are seeded without it and clients never stamp them; Security Rules let a clone's empty `created_at` be set once |
| `budget_enabled` | bool | |
| `budget_amount`, `budget_currency` | decimal string?, string? | The category's budget limit |
| `budget_period` | string | `daily`, `weekly`, `monthly`, `yearly` |
| `budget_rollover` | bool | Carries what was left of the previous period's budget into the current one ([Calculations](calculations.md#category-budget-progress)) |
| `alert_thresholds` | int[] | Default `[50, 75, 90, 100]` percent |
| `updated_at`, `version` | string, int | |

Budgets are fields on the category; there is no separate budgets collection.

### `category_groups`

Domain: `CategoryGroup`. Record: `OfflineCategoryGroup`. Fields: `id`, `user_id`, `template_id`, `name`, `icon`, `color`, `sort_order`, `created_at` (same rule as categories), `budget_amount`, `budget_currency` (a group-level budget), `updated_at`, `version`.

### `profiles`

Domain: `Profile` (`lib/features/settings/domain/profile.dart`). Record: `OfflineProfile`. Document ID = uid.

| Field | Notes |
| --- | --- |
| `id`, `email`, `display_name` | `display_name` defaults to the email's local part |
| `base_currency`, `country`, `timezone` | Defaults `THB`, `TH` (`kDefaultBaseCurrency`, `kDefaultCountry`) and the device's timezone, or `Asia/Bangkok` when it isn't known (`defaultProfileTimezone`), with or without an account |
| `preferred_theme` | `system`, `light`, `dark` |
| `aiko_character_visibility`, `aiko_personality_setting` | Defaults `full`, `supportive` |
| `security_status` | `notConfigured`, `pinEnabled`, `biometricEnabled`, `lockedOut` |
| `full_name`, `gender`, `date_of_birth`, `phone_number` | Optional personal fields; `gender` defaults to `preferNotToSay` |
| `avatar_path` | Device cache path of this save's photo, `aiko-cache:avatars/{uid}/{stamp}.{ext}`; other devices fall back to the URL |
| `avatar_url` | Firebase Storage download URL. Keeps the previous photo's URL until the new upload finishes; a failed upload never clears it. Removing the photo clears both fields |
| `updated_at`, `version` | |

### `investment_holdings`

Domain: `InvestmentHolding` (`lib/features/investments/domain/investment_holding.dart`). Record: `OfflineInvestmentHolding`. Fields: `id`, `user_id`, `symbol`, `asset_class`, `quantity`, `average_cost`, `current_price`, `market_value` (decimal strings), `currency`, `target_allocation_percent` (number, optional; no UI sets it yet), `created_at`, `updated_at`, `version`.

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

Supported types: PDF, JPEG, PNG, WebP, HEIC, text/CSV/Markdown and Word. Signed in, the document is written only after the file's upload, so `storage_path` is always the Storage path. Until then the same row, with an `aiko-cache:` path, waits in the device's `attachments` table ([below](#device-only-storage)); guest and local-only attachments live only there.

### `preferences`

Small synced settings, through `SyncedPreferences` (`lib/core/storage/synced_preferences.dart`). A document is either `{"value": "<string>"}` or, for lists that several devices may change offline, `{"items": {"<item>": "<string>"}}`, changed item by item with `set(merge: true)` and `FieldValue.delete()` (`ItemizedPreference`). Signed out, the same keys live in device secure storage (items as one JSON object), and signed in this device keeps a copy of each as `<uid>:<key>` ([Architecture → Preferences](architecture.md#preferences)).

| Key | Shape | Value | Owner |
| --- | --- | --- | --- |
| `aiko_language_code` | value | `en` or `th`; absent = follow device | `AppLocaleController` |
| `transaction_rules_v2` | items | One item per rule id; the value is the `TransactionRule` JSON | `TransactionRuleStore` |
| `travel_mode_v1` | value | JSON of the active trip and exchange rate. Each foreign fee is the money JSON plus an optional `merchant` (fees saved without one still load) | `TravelModeNotifier` |
| `learning_progress_v2` | items | One item per `<lesson key>:<level>` reached (`read`, `completed`), value empty; a lesson's progress is its highest level, so it never goes back | `LessonProgressStore` |
| `dismissed_notifications_v2` | items | One item per dismissed notification id; the value is when it was dismissed (ISO). Dismissals of notifications no longer shown are dropped after 60 days | `NotificationDismissalStore` |

The earlier single-value keys `transaction_rules_v1` (JSON array of rules), `learning_progress_v1` (JSON object of lesson key → level) and `dismissed_notifications_v1` (JSON array of ids) are read until the first `_v2` write, which carries them over. They are left untouched for older app versions, which keep using them.

### `integrations/line`

`{connected: true}` once LINE pairing succeeds. Only Cloud Functions write it.

## Device-only storage

These values never sync.

| Store | Key or table | Purpose |
| --- | --- | --- |
| Secure storage | `aiko_offline_user_id` | Current owner ID (`local:<uuid>` or uid) |
| Secure storage | `aiko_known_account` | `true` after a successful sign-in; routes returning users to `/auth` |
| Secure storage | `aiko_guest_mode` | `true` while a cloud build is used without an account ([Architecture](architecture.md#guest-mode-and-sign-in)) |
| Secure storage | `aiko_guest_claim:<uid>` | How an interrupted guest sign-in should finish (`newAccount` or `existingAccount`) |
| Secure storage | `aiko_defaults_seeded:<uid>` | Stamp recording that this device knows the user's profile and default categories exist ([Cost](cost.md)) |
| Secure storage | `aiko_default_accounts_seeded:<uid>` | `true` once this device seeded the user's default Cash and Bank accounts (`DefaultAccountsSeedMarker`) |
| Secure storage | `<uid>:<preference key>` | This device's copy of a synced preference, for offline reads |
| Secure storage | Preference keys without a uid | Guest and local-only preferences; moved into the account at sign-in |
| Secure storage | `<uid>:profile_changes_v1` | Profile fields saved on a stand-in profile, applied when the real one loads |
| Secure storage | `<uid>:sync_last_synced_at` | Last time everything was in sync, for the offline banner |
| Secure storage | `transaction_capture_settings` | Android capture on/off and target account |
| `aiko_local.sqlite` | `records`, `meta` | Guest and local-only records, and device values ([below](#local-record-store)) |
| `aiko_files.sqlite` | `files(path, bytes, size, cached_at)` | Attachment and avatar bytes. Copies of cloud files (`receipts/users/…`) are trimmed oldest first to 100 MB (30 MB on the web); device-only bytes (`attachments/…`, `avatars/…`) never are |
| `aiko_files.sqlite` | `attachments(id, owner_id, transaction_id, data, created_at)` | Attachment metadata kept on the device: every guest and local-only attachment, and a signed-in one until its upload finishes. `data` is the Firestore row as JSON |
| `aiko_files.sqlite` | `file_jobs(id, owner_id, kind, data, seq, attempts)` | `FileSyncQueue` jobs in `seq` order: `attachment-upload`, `avatar-upload`, `attachments-purge` (up to 30 transaction ids) and `storage-delete`. `attempts` ≥ 5 marks a failed job waiting for the next launch |
| App support dir | `capture_inbox/*.json` | Captured SMS and notifications waiting to be booked (Android) |
| App support dir | `capture_ledger.json` | The last 200 captured messages, to spot the same payment arriving again |

`aiko_files.sqlite` is at schema version 3 (`LocalFileCache.schemaVersion`): version 2 added `attachments` and `file_jobs`, version 3 `size` and `cached_at`. Metadata that earlier versions kept as one `attachment-metadata/…` entry per transaction in `files` is moved into `attachments` once, and its never-uploaded files are queued.

## Local record store

`LocalRecordStore` (`lib/core/storage/local_record_store.dart`) opens `aiko_local.sqlite` (IndexedDB on the web) with two tables:

| Table | Columns | Holds |
| --- | --- | --- |
| `records` | `collection`, `id`, `owner_id`, `data`, `updated_at`; primary key `(collection, id)`, index on `(collection, owner_id)` | Guest and local-only records of every collection; `data` is the record's Firestore row as JSON |
| `meta` | `key`, `value` | `legacy_import:aiko_offline.sqlite` (when the old database was imported) and `legacy_import_failures:…`; device values under `device:` (`DeviceValueStore`): `fx_rates_v1` (last rates per base currency, newest 8), `prices_updated_at:<uid>` (last price refresh; `local` signed out) and `line_linked:<uid>` (last LINE status) |

The schema version is `PRAGMA user_version` (`LocalRecordStore.schemaVersion`, now 1). A layout change bumps it and extends `_upgrade`; a new field needs no migration, because the row is stored whole.

The earlier Brick database, `aiko_offline.sqlite` (one table per record type, one column per field), is imported once at startup by `LegacyStoreImport` and then deleted. Its decoders are tolerant (booleans as 0/1, JSON text columns, missing tables, columns or NULLs fall back to defaults, unreadable rows are skipped), and the import never replaces a record already in the store.

Rules for record changes:

- Add the field to the record class in `lib/core/offline/records/`, to both halves of its codec (`toRow`, `fromRow`) and to the domain mapping in `record_mappers.dart`. Read missing values with a default, since older documents and rows don't have them.
- Add a round-trip test in `test/core/offline/records/`; `record_codecs_test.dart` checks that existing documents of every collection read back unchanged.

## Default taxonomy

`CategoryDefaults` and `CategoryGroupDefaults` (`lib/features/categories/domain/category_defaults.dart`) define **81 system categories** (11 income, 70 expense) and **13 groups**:

Income & Earnings · Investments & Savings · Food & Drink · Transport · Housing & Utilities · Health & Fitness · Shopping & Personal · Entertainment & Leisure · Education · Travel · Family & Giving · Bills & Financial · Other.

Templates have fixed IDs (for example `00000000-0000-0000-c200-000000000001` for Groceries). Each signed-in user gets clones with deterministic IDs:

```dart
Uuid().v5(namespace, 'category:${uid.toLowerCase()}:${templateId.toLowerCase()}')
```

So every device computes the same clone IDs, sign-in can create them idempotently, and imported transactions that reference template IDs are re-pointed to the user's clones (`CategoryDefaults.categoryIdForUser`). On clones, Security Rules allow edits only to the budget fields (plus setting an empty `created_at` once), and clones cannot be deleted. Guests and local-only builds use the templates directly, with budget overlays stored under the template IDs; a guest's overlays become the account's clones at sign-in.

## Storage paths

| Path | Contents | Rule |
| --- | --- | --- |
| `users/{uid}/receipts/{id}/{fileName}` | Transaction attachments | Owner only, 1 byte–10 MiB, image/PDF/text/Word |
| `users/{uid}/avatars/{microseconds}.{ext}` | Profile photo, one object per save; the previous one is deleted once the profile points at the new URL | Same |
| `users/{uid}/documents/…`, `users/{uid}/exports/…` | Reserved by rules | Same |

Account deletion removes everything under `users/{uid}/` ([Backend](backend.md#deleteaccount)).
