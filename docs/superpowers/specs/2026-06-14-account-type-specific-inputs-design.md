# Account-type-specific input design

**Status:** Approved
**Date:** 2026-06-14
**Owner:** accounts feature

## Problem

The account form (`accounts_screen.dart`, `onboarding_account_form.dart`) only branches on `institution` for non-cash types. Every other account type reuses the same five fields, so users can't enter the data they actually need:

- A credit card has no place to enter a credit limit, statement day, due day, APR, or to share a limit with another card.
- A loan has no place to enter interest rate, term, monthly payment, or next due date.
- An investment account has no place to record the broker or account number.

The `credit_card_profiles` table already exists, but the form never writes to it.

## Goal

Make the account form shape itself to the selected account type, with a small, composable form-state model that stays easy to read and test.

## Approach (option A — inline subforms, option 1 — subform widgets)

The form stays a single sheet. Below the type dropdown, an inline subform section appears for the selected type. Each type's subform is its own widget that owns its own controllers and validation. The parent form just orchestrates common fields + the right subform.

## Scope (account types & fields)

| Type | Subform fields |
| --- | --- |
| `cash` | (none — placeholder subform) |
| `bank` | `accountNumberLast4` (optional), `accountHolderName` (optional) |
| `eWallet` | `linkedPhoneOrEmail` (optional) |
| `creditCard` | `creditLimit`, `statementDay` (1-31), `dueDay` (1-31), `aprPercent`, `rewardsType` (cashback / points / miles / none), `annualFee`, `minimumPayment`, `sharesLimit` (bool) + `sharedLimitAccountId` (when true) |
| `loan` | `loanType` (mortgage / auto / personal / student / other), `principal`, `interestRatePercent`, `termMonths`, `monthlyPayment`, `nextDueDate` |
| `investment` | `accountNumberLast4` (optional) |
| `asset` | `assetClass` (realEstate / vehicle / collectible / other), `purchasePrice` (optional), `purchaseDate` (optional), `notes` (optional) |
| `liability` | `liabilityType` (optional), `interestRatePercent` (optional), `notes` (optional) |
| `other` | `notes` (optional) |

`institution` and `currency` stay common across all types.

## Architecture

```
lib/features/accounts/
├── domain/
│   ├── account.dart                     # existing — add type-specific details field
│   ├── account_details.dart             # NEW — sealed union of per-type details
│   └── account_validation_messages.dart # NEW — single source of validation copy
├── presentation/
│   ├── accounts_screen.dart             # unchanged
│   ├── account_form/
│   │   ├── account_form_sheet.dart      # NEW — parent form (orchestrates)
│   │   ├── account_common_fields.dart   # NEW — name, type, currency, balance, toggles
│   │   ├── subforms/
│   │   │   ├── account_subform.dart     # NEW — interface (read/write/validate/reset)
│   │   │   ├── cash_subform.dart        # NEW — empty placeholder
│   │   │   ├── bank_subform.dart        # NEW
│   │   │   ├── ewallet_subform.dart     # NEW
│   │   │   ├── credit_card_subform.dart # NEW
│   │   │   ├── loan_subform.dart        # NEW
│   │   │   ├── investment_subform.dart  # NEW
│   │   │   ├── asset_subform.dart       # NEW
│   │   │   ├── liability_subform.dart   # NEW
│   │   │   └── other_subform.dart       # NEW
│   │   └── account_form_helpers.dart    # NEW — day picker, currency picker, etc.
│   └── onboarding_account_form.dart     # refactored to compose the same subforms
├── data/
│   ├── account_dto.dart                 # updated to read/write details JSON
│   ├── account_details_dto.dart         # NEW — serializes the union
│   └── account_repository.dart          # unchanged signature
└── application/
    ├── accounts_provider.dart           # updated to accept Account + details
    └── shared_limit_resolver.dart       # NEW — auto-flips children when parent deleted

lib/brick/
├── models/account.model.dart            # updated — add `detailsJson` column
└── offline_model_mappers.dart           # updated — map detailsJson → Account.details
```

**Migration:** `supabase/migrations/<ts>_account_details.sql` adds a `details jsonb` column to `accounts` (default `'{}'`, RLS unchanged).

## Data model

```dart
sealed class AccountDetails {
  const AccountDetails();
  const factory AccountDetails.cash() = CashDetails;
  const factory AccountDetails.bank({
    String? accountNumberLast4,
    String? accountHolderName,
  }) = BankDetails;
  const factory AccountDetails.eWallet({String? linkedPhoneOrEmail}) = EWalletDetails;
  const factory AccountDetails.creditCard({
    Money? creditLimit,
    required int statementDay,
    required int dueDay,
    double? aprPercent,
    RewardsType? rewardsType,
    Money? annualFee,
    Money? minimumPayment,
    @Default(false) bool sharesLimit,
    String? sharedLimitAccountId,
  }) = CreditCardDetails;
  const factory AccountDetails.loan({
    required LoanType loanType,
    required Money principal,
    required double interestRatePercent,
    required int termMonths,
    required Money monthlyPayment,
    required DateTime nextDueDate,
  }) = LoanDetails;
  const factory AccountDetails.investment({String? accountNumberLast4}) = InvestmentDetails;
  const factory AccountDetails.asset({
    required AssetClass assetClass,
    Money? purchasePrice,
    DateTime? purchaseDate,
    String? notes,
  }) = AssetDetails;
  const factory AccountDetails.liability({
    String? liabilityType,
    double? interestRatePercent,
    String? notes,
  }) = LiabilityDetails;
  const factory AccountDetails.other({String? notes}) = OtherDetails;
}

enum RewardsType { cashback, points, miles, none }
enum LoanType { mortgage, auto, personal, student, other }
// AssetClass already exists in lib/features/assets/domain/asset.dart — reuse
```

`Account` gains one field: `final AccountDetails details;` (defaults to `const AccountDetails.cash()`). Factory `Account.defaultDetailsFor(AccountType)` returns the right empty variant.

**Validation invariants (baked into the model via pure `Account.validate`):**
- `CreditCardDetails`: `statementDay` and `dueDay` ∈ 1-31; `aprPercent` ≥ 0; `creditLimit != null` when `sharesLimit == false`; `sharedLimitAccountId != null` when `sharesLimit == true`; `creditLimit.currency == currentBalance.currency` when both present.
- `LoanDetails`: `termMonths` > 0; `interestRatePercent` ≥ 0; all `Money` fields share currency.
- `AssetDetails`: `purchasePrice` set ⇒ `purchaseDate` set.

**Reference invariants (impure — checked by the controller, not the model):**
- `CreditCardDetails.sharedLimitAccountId` references an existing credit-card account owned by the same user. Checked by querying `accountsProvider`; throws `AccountValidationException('sharedLimitAccountId', 'Referenced card not found.')` on miss.
- `CreditCardDetails.sharedLimitAccountId` does not equal the account's own `id` (no self-reference). Same exception type.

**Sealed-class generation:** `AccountDetails` and its variants use the `freezed` package (already in the build_runner pipeline via Brick). The `@Default(false)` annotation is a freezed feature, not hand-rolled. `build_runner` regenerates the union and `copyWith` whenever the file changes.

## Subform widget contract

```dart
abstract class AccountSubform extends ConsumerStatefulWidget {
  const AccountSubform({super.key});
}

abstract class AccountSubformState<T extends AccountSubform>
    extends ConsumerState<T> {
  AccountDetails getDetails();
  void resetTo(AccountDetails initial);
  String? validate();
}
```

Conventions:
- All inputs use shared `aiko_data_widgets.dart` primitives.
- `AnimatedSize` (200ms easeOut) wraps the subform so it slides in/out on type change.
- `onChanged` callback debounced 150ms to avoid rebuilding the parent on every keystroke.
- Controllers disposed in `dispose()`; subforms with no controllers extend a `StatelessSubform` base.
- Empty subforms (`cash`, `other`) render a single `AikoInlineNotice` explaining no extras are needed.

## Parent form orchestration

`AccountFormSheet` is the only file that knows about every subform. It:
- Holds common state (name, type, currency, balance, institution, toggles).
- Switches the active subform on type change, re-keying the widget so its `initState` rebuilds.
- On type change with unsaved subform data, shows a confirm dialog ("Switching type resets the details you entered.").
- Reads the active subform's `getDetails()` at save time.
- Composes `OnboardingAccountForm` and `AccountFormSheet` to share the same subforms (single source of truth).

`AccountDetailScreen` adds a new "Type details" `FinanceCard` that renders the current details as a key/value list using `aiko_data_widgets.dart` — read-only view of what the subform produced.

## Data flow & save

```
AccountFormSheet
    │ saveAccount(account)
    ▼
AccountsController
    │ Account.validate(account) → throws on invariants
    │ AccountDto.fromDomain(account) → maps common + details JSON
    ▼
OfflineStore (Brick SQLite)
    │ persists detailsJson immediately, queues for sync
    ▼
Supabase (Postgres + jsonb details column)
```

- `AccountDetailsDto` serializes the union to a stable JSON map keyed by variant name (`{"_type":"creditCard",...}`). `Money` fields serialize as `{"amount":"...","currency":"..."}`.
- `OfflineAccount.detailsJson` (new column) stores the same JSON string; offline model mapper parses it back.
- Shared-limit child: when a parent card is deleted, `SharedLimitResolver` flips all referencing children to `sharesLimit = false`. Idempotent, no provider spam.
- Shared-limit child: subsequent reads compute the child's `creditLimit` as the parent's value at read time via `CreditCardMetrics.effectiveLimit(child, allAccounts)` in `lib/features/credit_cards/application/credit_card_metrics_service.dart` (existing service extended with one new method) — single source of truth, no stale duplication.
- Type change on edit discards the previous type's details; no merge.

## Error handling

| Failure | UI behavior |
| --- | --- |
| Common field validation | Inline error under the field |
| Subform validation | Returned by parent → `AikoInlineNotice` at the top of the subform |
| Model invariant (`Account.validate`) | Form catches `AccountValidationException(field, message)`, finds matching `FormField`, shows error inline; cross-field errors → snackbar |
| Type-change with unsaved subform data | Confirm dialog (Cancel / Continue) |
| Offline save failure | Snackbar "Saved locally — will sync when online." Local write still succeeds |
| Supabase sync failure | Silent; surfaced in Settings → Sync |
| Shared-limit parent card deleted | Silent migration; child's detail screen shows "No longer shares a limit" notice next visit |
| Subform build throws | Caught by parent's `ErrorWidget.builder` fallback; standard aiko error card with Retry |
| Shared-limit reference is soft-deleted | Subform disables dropdown item; shows "Referenced card unavailable" with a "Set your own limit" inline action |

Validation messages live in `lib/features/accounts/domain/account_validation_messages.dart` — single source of copy.

## Testing

**Unit (`test/features/accounts/`):**
- `account_details_test.dart` — round-trip JSON for every variant; invariants on `Account.validate`.
- `account_dto_test.dart` — common + details fields persist and reload identically; null vs missing details handled.
- `shared_limit_resolver_test.dart` — deleting parent flips children; idempotent; doesn't touch non-referencing accounts.
- `account_default_details_for_test.dart` — every `AccountType` returns a non-null, type-correct default.

**Widget (`test/features/accounts/presentation/`):**
- `credit_card_subform_test.dart` — renders with initial details; `getDetails()` returns expected union; `validate()` fails on missing limit / out-of-range days / shared-limit-without-parent; `resetTo` rebuilds controllers.
- `loan_subform_test.dart` — same shape, currency consistency.
- `account_form_sheet_test.dart` — selecting a type renders the right subform; valid form calls `saveAccount` with the correct `Account` + `details`; type-change confirm dialog blocks when dirty; validation errors don't submit.
- `account_detail_screen_test.dart` — type-specific "Type details" card renders right key/value rows per type.

**Repository / provider:**
- `account_repository_test.dart` — extend to cover `detailsJson` round-trip via `OfflineStore` in-memory.
- `accounts_controller_test.dart` — `saveAccount` rejects invalid details, accepts valid ones, calls `OfflineStore.upsert` with the right mapper output.

**Integration (`integration_test/account_crud_test.dart`):**
- Create cash → bank → credit card (with shared limit) → loan; verify subform fields, save, and re-open round-trip.
- Delete parent credit card → open child → assert "set your own limit" notice appears.
- Toggle offline mode mid-form → assert save still works locally, queue picks it up on reconnect.

**Coverage gate:** ≥85% line coverage on new code paths. `flutter test --coverage` runs in CI.

**Manual QA checklist (added to AGENTS.md):**
- Add each account type from a fresh state — subform appears, validates, saves.
- Edit each type — values pre-populate, save round-trips identically.
- Toggle shared limit on/off — limit field appears/disappears, referenced card picker excludes self.
- Delete parent card — child detail screen shows migration notice.
- Offline add — account persists locally, syncs on reconnect, no double-write.
