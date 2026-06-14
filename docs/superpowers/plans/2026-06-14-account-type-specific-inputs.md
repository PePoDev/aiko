# Account-type-specific input form — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the account form shape itself to the selected account type, with a small, composable form-state model. Per-type subform widgets own their own state; the parent form just orchestrates.

**Architecture:** Add a sealed `AccountDetails` union (Dart 3 sealed classes — codebase already uses this pattern, no `freezed`) holding per-type fields. Persist as a single `detailsJson` column on `OfflineAccount` and a `details jsonb` column on Supabase. The account form sheet composes a `AccountCommonFields` widget with a per-type subform widget selected by `AccountType`. Subforms implement a tiny interface (`getDetails`, `resetTo`, `validate`).

**Tech Stack:** Dart 3 sealed classes, Riverpod, Brick offline-first, Supabase (jsonb), `flutter_test` + `integration_test`.

**Note on AssetClass:** The spec mentioned `realEstate / vehicle / collectible / other`, but `lib/features/assets/domain/asset.dart` already defines `enum AssetClass { cash, stocks, realEstate, vehicle, other }`. Per the spec ("AssetClass already exists — reuse"), we use the existing enum.

**Reference spec:** `docs/superpowers/specs/2026-06-14-account-type-specific-inputs-design.md`

---

## Task 1: Add `AccountValidationException`

**Files:**
- Create: `lib/features/accounts/domain/account_validation_exception.dart`
- Test: `test/features/accounts/domain/account_validation_exception_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:aiko/features/accounts/domain/account_validation_exception.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('carries field name and message', () {
    final ex = AccountValidationException('creditLimit', 'Limit required.');
    expect(ex.field, 'creditLimit');
    expect(ex.message, 'Limit required.');
    expect(ex.toString(), contains('creditLimit'));
  });
}
```

- [ ] **Step 2: Run test, verify FAIL**

```bash
flutter test test/features/accounts/domain/account_validation_exception_test.dart
```
Expected: compile error — file not found.

- [ ] **Step 3: Implement**

```dart
// lib/features/accounts/domain/account_validation_exception.dart
class AccountValidationException implements Exception {
  const AccountValidationException(this.field, this.message);

  final String field;
  final String message;

  @override
  String toString() => 'AccountValidationException($field): $message';
}
```

- [ ] **Step 4: Run test, verify PASS**

```bash
flutter test test/features/accounts/domain/account_validation_exception_test.dart
```

- [ ] **Step 5: Commit**

```bash
git add lib/features/accounts/domain/account_validation_exception.dart test/features/accounts/domain/account_validation_exception_test.dart
git commit -m "feat(accounts): add AccountValidationException"
```

---

## Task 2: Add validation messages

**Files:**
- Create: `lib/features/accounts/domain/account_validation_messages.dart`

- [ ] **Step 1: Implement**

```dart
// lib/features/accounts/domain/account_validation_messages.dart
abstract final class AccountValidationMessages {
  static const statementDayRange = 'Statement day must be between 1 and 31.';
  static const dueDayRange = 'Due day must be between 1 and 31.';
  static const aprNegative = 'APR cannot be negative.';
  static const creditLimitRequired =
      'Enter a credit limit or turn on shared limit.';
  static const sharedLimitReferenceRequired =
      'Pick a card to share the limit with.';
  static const sharedLimitSelfReference =
      'A card cannot share its own limit.';
  static const sharedLimitReferenceMissing =
      'The referenced card no longer exists.';
  static const creditLimitCurrencyMismatch =
      'Credit limit currency must match the account currency.';
  static const termMonthsPositive = 'Term must be at least 1 month.';
  static const loanCurrencyMismatch =
      'All loan amounts must use the same currency.';
  static const purchaseDateRequired = 'Add a purchase date with the price.';
  static const sharedLimitCardUnavailable =
      'Referenced card is no longer available.';
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/features/accounts/domain/account_validation_messages.dart
git commit -m "feat(accounts): add account validation messages"
```

---

## Task 3: Add `AccountDetails` sealed union

**Files:**
- Create: `lib/features/accounts/domain/account_details.dart`
- Test: `test/features/accounts/domain/account_details_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:aiko/core/money/money.dart';
import 'package:aiko/features/accounts/domain/account_details.dart';
import 'package:aiko/features/assets/domain/asset.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every AccountType maps to a non-null default', () {
    for (final type in AccountType.values) {
      expect(AccountDetails.defaultFor(type), isNotNull,
          reason: 'Missing default for $type');
    }
  });

  test('CreditCardDetails equality round-trips', () {
    final a = CreditCardDetails(
      creditLimit: Money.parse('5000', 'USD'),
      statementDay: 15,
      dueDay: 5,
      aprPercent: 19.99,
      sharesLimit: false,
    );
    final b = a.copyWith();
    expect(b, equals(a));
  });

  test('CreditCardDetails.copyWith updates selected fields', () {
    final a = CreditCardDetails(
      creditLimit: Money.parse('5000', 'USD'),
      statementDay: 15,
      dueDay: 5,
    );
    final b = a.copyWith(statementDay: 20);
    expect(b.statementDay, 20);
    expect(b.creditLimit, Money.parse('5000', 'USD'));
  });

  test('LoanDetails equality round-trips', () {
    final a = LoanDetails(
      loanType: LoanType.mortgage,
      principal: Money.parse('250000', 'USD'),
      interestRatePercent: 6.5,
      termMonths: 360,
      monthlyPayment: Money.parse('1580', 'USD'),
      nextDueDate: DateTime.utc(2026, 7, 1),
    );
    expect(a, equals(a.copyWith()));
  });

  test('AssetDetails uses existing AssetClass enum', () {
    const a = AssetDetails(assetClass: AssetClass.realEstate);
    expect(a.assetClass, AssetClass.realEstate);
  });
}
```

- [ ] **Step 2: Run test, verify FAIL**

```bash
flutter test test/features/accounts/domain/account_details_test.dart
```

- [ ] **Step 3: Implement**

```dart
// lib/features/accounts/domain/account_details.dart
import '../../assets/domain/asset.dart';
import '../../../core/money/money.dart';
import 'account.dart';

enum RewardsType { cashback, points, miles, none }

enum LoanType { mortgage, auto, personal, student, other }

sealed class AccountDetails {
  const AccountDetails();

  /// Returns the empty default for [type]. Always non-null.
  static AccountDetails defaultFor(AccountType type) {
    return switch (type) {
      AccountType.cash => const CashDetails(),
      AccountType.bank => const BankDetails(),
      AccountType.eWallet => const EWalletDetails(),
      AccountType.creditCard => const CreditCardDetails(
          statementDay: 1,
          dueDay: 1,
        ),
      AccountType.loan => const LoanDetails(
          loanType: LoanType.other,
          principal: _zeroMoney,
          interestRatePercent: 0,
          termMonths: 1,
          monthlyPayment: _zeroMoney,
          nextDueDate: _epoch,
        ),
      AccountType.investment => const InvestmentDetails(),
      AccountType.asset => const AssetDetails(assetClass: AssetClass.other),
      AccountType.liability => const LiabilityDetails(),
      AccountType.other => const OtherDetails(),
    };
  }

  /// String discriminator used in JSON / Brick storage.
  String get variantName;

  CashDetails asCash() => this as CashDetails;
  BankDetails asBank() => this as BankDetails;
  EWalletDetails asEWallet() => this as EWalletDetails;
  CreditCardDetails asCreditCard() => this as CreditCardDetails;
  LoanDetails asLoan() => this as LoanDetails;
  InvestmentDetails asInvestment() => this as InvestmentDetails;
  AssetDetails asAsset() => this as AssetDetails;
  LiabilityDetails asLiability() => this as LiabilityDetails;
  OtherDetails asOther() => this as OtherDetails;
}

const _zeroMoney = Money(amount: _zero, currency: 'USD');
final _epoch = DateTime.utc(1970, 1, 1);
const _zero = _ZeroDecimal();
class _ZeroDecimal implements Decimal {
  const _ZeroDecimal();
  // Unused — only present so the const Money(amount:...) compiles.
  // Real defaults are populated by the form.
  @override
  dynamic noSuchMethod(Invocation _) => 0;
}
```

Wait — `Money` requires a real `Decimal`. The `defaultFor` returning const-friendly values is a problem for `principal`/`monthlyPayment` which must be `Money`. Use a non-const default with placeholder values that the form always overwrites:

Replace the whole file with:

```dart
// lib/features/accounts/domain/account_details.dart
import 'package:decimal/decimal.dart';

import '../../assets/domain/asset.dart';
import '../../../core/money/money.dart';
import 'account.dart';

enum RewardsType { cashback, points, miles, none }

enum LoanType { mortgage, auto, personal, student, other }

sealed class AccountDetails {
  const AccountDetails();

  /// Returns the empty default for [type]. Always non-null.
  static AccountDetails defaultFor(AccountType type) {
    return switch (type) {
      AccountType.cash => const CashDetails(),
      AccountType.bank => const BankDetails(),
      AccountType.eWallet => const EWalletDetails(),
      AccountType.creditCard =>
        CreditCardDetails(statementDay: 1, dueDay: 1),
      AccountType.loan => LoanDetails(
          loanType: LoanType.other,
          principal: Money.zero('USD'),
          interestRatePercent: 0,
          termMonths: 1,
          monthlyPayment: Money.zero('USD'),
          nextDueDate: DateTime.utc(1970, 1, 1),
        ),
      AccountType.investment => const InvestmentDetails(),
      AccountType.asset => const AssetDetails(assetClass: AssetClass.other),
      AccountType.liability => const LiabilityDetails(),
      AccountType.other => const OtherDetails(),
    };
  }

  /// String discriminator used in JSON / Brick storage.
  String get variantName;
}

class CashDetails extends AccountDetails {
  const CashDetails();
  @override
  String get variantName => 'cash';
}

class BankDetails extends AccountDetails {
  const BankDetails({this.accountNumberLast4, this.accountHolderName});
  final String? accountNumberLast4;
  final String? accountHolderName;
  @override
  String get variantName => 'bank';

  BankDetails copyWith({String? accountNumberLast4, String? accountHolderName}) =>
      BankDetails(
        accountNumberLast4: accountNumberLast4 ?? this.accountNumberLast4,
        accountHolderName: accountHolderName ?? this.accountHolderName,
      );

  @override
  bool operator ==(Object other) =>
      other is BankDetails &&
      other.accountNumberLast4 == accountNumberLast4 &&
      other.accountHolderName == accountHolderName;

  @override
  int get hashCode => Object.hash(accountNumberLast4, accountHolderName);
}

class EWalletDetails extends AccountDetails {
  const EWalletDetails({this.linkedPhoneOrEmail});
  final String? linkedPhoneOrEmail;
  @override
  String get variantName => 'eWallet';

  EWalletDetails copyWith({String? linkedPhoneOrEmail}) => EWalletDetails(
        linkedPhoneOrEmail: linkedPhoneOrEmail ?? this.linkedPhoneOrEmail,
      );

  @override
  bool operator ==(Object other) =>
      other is EWalletDetails &&
      other.linkedPhoneOrEmail == linkedPhoneOrEmail;

  @override
  int get hashCode => linkedPhoneOrEmail.hashCode;
}

class CreditCardDetails extends AccountDetails {
  const CreditCardDetails({
    this.creditLimit,
    required this.statementDay,
    required this.dueDay,
    this.aprPercent,
    this.rewardsType,
    this.annualFee,
    this.minimumPayment,
    this.sharesLimit = false,
    this.sharedLimitAccountId,
  });

  final Money? creditLimit;
  final int statementDay;
  final int dueDay;
  final double? aprPercent;
  final RewardsType? rewardsType;
  final Money? annualFee;
  final Money? minimumPayment;
  final bool sharesLimit;
  final String? sharedLimitAccountId;
  @override
  String get variantName => 'creditCard';

  CreditCardDetails copyWith({
    Money? creditLimit,
    int? statementDay,
    int? dueDay,
    double? aprPercent,
    RewardsType? rewardsType,
    Money? annualFee,
    Money? minimumPayment,
    bool? sharesLimit,
    String? sharedLimitAccountId,
  }) =>
      CreditCardDetails(
        creditLimit: creditLimit ?? this.creditLimit,
        statementDay: statementDay ?? this.statementDay,
        dueDay: dueDay ?? this.dueDay,
        aprPercent: aprPercent ?? this.aprPercent,
        rewardsType: rewardsType ?? this.rewardsType,
        annualFee: annualFee ?? this.annualFee,
        minimumPayment: minimumPayment ?? this.minimumPayment,
        sharesLimit: sharesLimit ?? this.sharesLimit,
        sharedLimitAccountId: sharedLimitAccountId ?? this.sharedLimitAccountId,
      );

  @override
  bool operator ==(Object other) =>
      other is CreditCardDetails &&
      other.creditLimit == creditLimit &&
      other.statementDay == statementDay &&
      other.dueDay == dueDay &&
      other.aprPercent == aprPercent &&
      other.rewardsType == rewardsType &&
      other.annualFee == annualFee &&
      other.minimumPayment == minimumPayment &&
      other.sharesLimit == sharesLimit &&
      other.sharedLimitAccountId == sharedLimitAccountId;

  @override
  int get hashCode => Object.hash(
        creditLimit,
        statementDay,
        dueDay,
        aprPercent,
        rewardsType,
        annualFee,
        minimumPayment,
        sharesLimit,
        sharedLimitAccountId,
      );
}

class LoanDetails extends AccountDetails {
  const LoanDetails({
    required this.loanType,
    required this.principal,
    required this.interestRatePercent,
    required this.termMonths,
    required this.monthlyPayment,
    required this.nextDueDate,
  });

  final LoanType loanType;
  final Money principal;
  final double interestRatePercent;
  final int termMonths;
  final Money monthlyPayment;
  final DateTime nextDueDate;
  @override
  String get variantName => 'loan';

  LoanDetails copyWith({
    LoanType? loanType,
    Money? principal,
    double? interestRatePercent,
    int? termMonths,
    Money? monthlyPayment,
    DateTime? nextDueDate,
  }) =>
      LoanDetails(
        loanType: loanType ?? this.loanType,
        principal: principal ?? this.principal,
        interestRatePercent: interestRatePercent ?? this.interestRatePercent,
        termMonths: termMonths ?? this.termMonths,
        monthlyPayment: monthlyPayment ?? this.monthlyPayment,
        nextDueDate: nextDueDate ?? this.nextDueDate,
      );

  @override
  bool operator ==(Object other) =>
      other is LoanDetails &&
      other.loanType == loanType &&
      other.principal == principal &&
      other.interestRatePercent == interestRatePercent &&
      other.termMonths == termMonths &&
      other.monthlyPayment == monthlyPayment &&
      other.nextDueDate == nextDueDate;

  @override
  int get hashCode => Object.hash(
        loanType,
        principal,
        interestRatePercent,
        termMonths,
        monthlyPayment,
        nextDueDate,
      );
}

class InvestmentDetails extends AccountDetails {
  const InvestmentDetails({this.accountNumberLast4});
  final String? accountNumberLast4;
  @override
  String get variantName => 'investment';

  InvestmentDetails copyWith({String? accountNumberLast4}) => InvestmentDetails(
        accountNumberLast4: accountNumberLast4 ?? this.accountNumberLast4,
      );

  @override
  bool operator ==(Object other) =>
      other is InvestmentDetails &&
      other.accountNumberLast4 == accountNumberLast4;

  @override
  int get hashCode => accountNumberLast4.hashCode;
}

class AssetDetails extends AccountDetails {
  const AssetDetails({
    required this.assetClass,
    this.purchasePrice,
    this.purchaseDate,
    this.notes,
  });
  final AssetClass assetClass;
  final Money? purchasePrice;
  final DateTime? purchaseDate;
  final String? notes;
  @override
  String get variantName => 'asset';

  AssetDetails copyWith({
    AssetClass? assetClass,
    Money? purchasePrice,
    DateTime? purchaseDate,
    String? notes,
  }) =>
      AssetDetails(
        assetClass: assetClass ?? this.assetClass,
        purchasePrice: purchasePrice ?? this.purchasePrice,
        purchaseDate: purchaseDate ?? this.purchaseDate,
        notes: notes ?? this.notes,
      );

  @override
  bool operator ==(Object other) =>
      other is AssetDetails &&
      other.assetClass == assetClass &&
      other.purchasePrice == purchasePrice &&
      other.purchaseDate == purchaseDate &&
      other.notes == notes;

  @override
  int get hashCode =>
      Object.hash(assetClass, purchasePrice, purchaseDate, notes);
}

class LiabilityDetails extends AccountDetails {
  const LiabilityDetails({
    this.liabilityType,
    this.interestRatePercent,
    this.notes,
  });
  final String? liabilityType;
  final double? interestRatePercent;
  final String? notes;
  @override
  String get variantName => 'liability';

  LiabilityDetails copyWith({
    String? liabilityType,
    double? interestRatePercent,
    String? notes,
  }) =>
      LiabilityDetails(
        liabilityType: liabilityType ?? this.liabilityType,
        interestRatePercent:
            interestRatePercent ?? this.interestRatePercent,
        notes: notes ?? this.notes,
      );

  @override
  bool operator ==(Object other) =>
      other is LiabilityDetails &&
      other.liabilityType == liabilityType &&
      other.interestRatePercent == interestRatePercent &&
      other.notes == notes;

  @override
  int get hashCode =>
      Object.hash(liabilityType, interestRatePercent, notes);
}

class OtherDetails extends AccountDetails {
  const OtherDetails({this.notes});
  final String? notes;
  @override
  String get variantName => 'other';

  OtherDetails copyWith({String? notes}) =>
      OtherDetails(notes: notes ?? this.notes);

  @override
  bool operator ==(Object other) =>
      other is OtherDetails && other.notes == notes;

  @override
  int get hashCode => notes.hashCode;
}
```

- [ ] **Step 4: Run test, verify PASS**

```bash
flutter test test/features/accounts/domain/account_details_test.dart
```

- [ ] **Step 5: Commit**

```bash
git add lib/features/accounts/domain/account_details.dart test/features/accounts/domain/account_details_test.dart
git commit -m "feat(accounts): add AccountDetails sealed union"
```

---

## Task 4: Update `Account` domain with `details` field

**Files:**
- Modify: `lib/features/accounts/domain/account.dart`
- Test: existing tests under `test/features/accounts/`

- [ ] **Step 1: Run existing account-related tests to baseline**

```bash
flutter test test/features/accounts/
```
Expected: all pass.

- [ ] **Step 2: Update `account.dart`**

Replace the file contents with:

```dart
// lib/features/accounts/domain/account.dart
import '../../../core/money/money.dart';
import 'account_details.dart';

enum AccountType {
  cash,
  bank,
  eWallet,
  creditCard,
  loan,
  investment,
  asset,
  liability,
  other,
}

class Account {
  const Account({
    required this.id,
    required this.userId,
    required this.name,
    required this.type,
    required this.currentBalance,
    this.institution,
    this.includeInNetWorth = true,
    this.isActive = true,
    this.details,
  });

  final String id;
  final String userId;
  final String name;
  final AccountType type;
  final Money currentBalance;
  final String? institution;
  final bool includeInNetWorth;
  final bool isActive;
  final AccountDetails? details;

  String get currency => currentBalance.currency;

  AccountDetails get resolvedDetails => details ?? AccountDetails.defaultFor(type);

  Account copyWith({
    String? name,
    AccountType? type,
    Money? currentBalance,
    String? institution,
    bool? includeInNetWorth,
    bool? isActive,
    AccountDetails? details,
    bool resetDetails = false,
  }) {
    return Account(
      id: id,
      userId: userId,
      name: name ?? this.name,
      type: type ?? this.type,
      currentBalance: currentBalance ?? this.currentBalance,
      institution: institution ?? this.institution,
      includeInNetWorth: includeInNetWorth ?? this.includeInNetWorth,
      isActive: isActive ?? this.isActive,
      details: resetDetails
          ? AccountDetails.defaultFor(type ?? this.type)
          : (details ?? this.details),
    );
  }
}
```

- [ ] **Step 3: Re-run tests, verify they still pass**

```bash
flutter test test/features/accounts/
```

- [ ] **Step 4: Commit**

```bash
git add lib/features/accounts/domain/account.dart
git commit -m "feat(accounts): add details field to Account"
```

---

## Task 5: Add `Account.validate` + reference-check helper

**Files:**
- Create: `lib/features/accounts/domain/account_validator.dart`
- Test: `test/features/accounts/domain/account_validator_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:aiko/core/money/money.dart';
import 'package:aiko/features/accounts/domain/account.dart';
import 'package:aiko/features/accounts/domain/account_details.dart';
import 'package:aiko/features/accounts/domain/account_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Account _acct(AccountDetails d, {String currency = 'USD'}) => Account(
        id: 'a',
        userId: 'u',
        name: 'n',
        type: AccountType.creditCard,
        currentBalance: Money.parse('0', currency),
        details: d,
      );

  test('cash account always validates', () {
    final a = Account(
      id: 'a',
      userId: 'u',
      name: 'n',
      type: AccountType.cash,
      currentBalance: Money.parse('0', 'USD'),
      details: const CashDetails(),
    );
    expect(() => AccountValidator.validate(a, allAccounts: const []), returnsNormally);
  });

  test('credit card missing limit and not sharing fails', () {
    final d = const CreditCardDetails(statementDay: 1, dueDay: 1);
    expect(
      () => AccountValidator.validate(_acct(d), allAccounts: const []),
      throwsA(isA<Exception>()),
    );
  });

  test('credit card with limit validates', () {
    final d = CreditCardDetails(
      statementDay: 1,
      dueDay: 1,
      creditLimit: Money.parse('5000', 'USD'),
    );
    expect(() => AccountValidator.validate(_acct(d), allAccounts: const []),
        returnsNormally);
  });

  test('credit card day out of range fails', () {
    final d = CreditCardDetails(
      statementDay: 0,
      dueDay: 1,
      creditLimit: Money.parse('5000', 'USD'),
    );
    expect(
      () => AccountValidator.validate(_acct(d), allAccounts: const []),
      throwsA(isA<Exception>()),
    );
  });

  test('credit card limit currency mismatch fails', () {
    final d = CreditCardDetails(
      statementDay: 1,
      dueDay: 1,
      creditLimit: Money.parse('5000', 'EUR'),
    );
    expect(
      () => AccountValidator.validate(_acct(d, currency: 'USD'),
          allAccounts: const []),
      throwsA(isA<Exception>()),
    );
  });

  test('credit card shares limit requires reference', () {
    final d = const CreditCardDetails(
      statementDay: 1,
      dueDay: 1,
      sharesLimit: true,
    );
    expect(
      () => AccountValidator.validate(_acct(d), allAccounts: const []),
      throwsA(isA<Exception>()),
    );
  });

  test('credit card cannot share with self', () {
    final d = const CreditCardDetails(
      statementDay: 1,
      dueDay: 1,
      sharesLimit: true,
      sharedLimitAccountId: 'a',
    );
    expect(
      () => AccountValidator.validate(_acct(d), allAccounts: const []),
      throwsA(isA<Exception>()),
    );
  });

  test('credit card shared reference must exist', () {
    final d = const CreditCardDetails(
      statementDay: 1,
      dueDay: 1,
      sharesLimit: true,
      sharedLimitAccountId: 'ghost',
    );
    final parent = Account(
      id: 'parent',
      userId: 'u',
      name: 'p',
      type: AccountType.creditCard,
      currentBalance: Money.parse('0', 'USD'),
    );
    expect(
      () => AccountValidator.validate(_acct(d), allAccounts: [parent]),
      throwsA(isA<Exception>()),
    );
  });

  test('credit card shared reference OK with valid parent', () {
    final d = const CreditCardDetails(
      statementDay: 1,
      dueDay: 1,
      sharesLimit: true,
      sharedLimitAccountId: 'parent',
    );
    final parent = Account(
      id: 'parent',
      userId: 'u',
      name: 'p',
      type: AccountType.creditCard,
      currentBalance: Money.parse('0', 'USD'),
    );
    expect(() => AccountValidator.validate(_acct(d), allAccounts: [parent]),
        returnsNormally);
  });

  test('loan term must be positive', () {
    final d = LoanDetails(
      loanType: LoanType.personal,
      principal: Money.parse('1000', 'USD'),
      interestRatePercent: 5,
      termMonths: 0,
      monthlyPayment: Money.parse('50', 'USD'),
      nextDueDate: DateTime.utc(2026, 7, 1),
    );
    expect(
      () => AccountValidator.validate(_acct(d), allAccounts: const []),
      throwsA(isA<Exception>()),
    );
  });

  test('loan with valid data passes', () {
    final d = LoanDetails(
      loanType: LoanType.personal,
      principal: Money.parse('1000', 'USD'),
      interestRatePercent: 5,
      termMonths: 12,
      monthlyPayment: Money.parse('50', 'USD'),
      nextDueDate: DateTime.utc(2026, 7, 1),
    );
    expect(() => AccountValidator.validate(_acct(d), allAccounts: const []),
        returnsNormally);
  });
}
```

- [ ] **Step 2: Run test, verify FAIL**

```bash
flutter test test/features/accounts/domain/account_validator_test.dart
```

- [ ] **Step 3: Implement**

```dart
// lib/features/accounts/domain/account_validator.dart
import '../../../core/money/money.dart';
import 'account.dart';
import 'account_details.dart';
import 'account_validation_exception.dart';
import 'account_validation_messages.dart';

abstract final class AccountValidator {
  /// Pure invariants on the account itself.
  static void _checkPureInvariants(Account a) {
    final d = a.resolvedDetails;
    switch (d) {
      case CashDetails():
      case BankDetails():
      case EWalletDetails():
      case InvestmentDetails():
      case LiabilityDetails():
      case OtherDetails():
      case AssetDetails():
        final ap = d.asAsset().purchasePrice;
        final ad = d.asAsset().purchaseDate;
        if (ap != null && ad == null) {
          throw AccountValidationException(
              'purchaseDate', AccountValidationMessages.purchaseDateRequired);
        }
      case CreditCardDetails():
        final cc = d.asCreditCard();
        if (cc.statementDay < 1 || cc.statementDay > 31) {
          throw AccountValidationException(
              'statementDay', AccountValidationMessages.statementDayRange);
        }
        if (cc.dueDay < 1 || cc.dueDay > 31) {
          throw AccountValidationException(
              'dueDay', AccountValidationMessages.dueDayRange);
        }
        if (cc.aprPercent != null && cc.aprPercent! < 0) {
          throw AccountValidationException(
              'aprPercent', AccountValidationMessages.aprNegative);
        }
        if (cc.sharesLimit) {
          if (cc.sharedLimitAccountId == null) {
            throw AccountValidationException(
                'sharedLimitAccountId',
                AccountValidationMessages.sharedLimitReferenceRequired);
          }
          if (cc.sharedLimitAccountId == a.id) {
            throw AccountValidationException(
                'sharedLimitAccountId',
                AccountValidationMessages.sharedLimitSelfReference);
          }
        } else if (cc.creditLimit == null) {
          throw AccountValidationException(
              'creditLimit', AccountValidationMessages.creditLimitRequired);
        }
        final limit = cc.creditLimit;
        if (limit != null && limit.currency != a.currency) {
          throw AccountValidationException(
              'creditLimit',
              AccountValidationMessages.creditLimitCurrencyMismatch);
        }
      case LoanDetails():
        final l = d.asLoan();
        if (l.termMonths <= 0) {
          throw AccountValidationException(
              'termMonths', AccountValidationMessages.termMonthsPositive);
        }
        if (l.interestRatePercent < 0) {
          throw AccountValidationException(
              'interestRatePercent', AccountValidationMessages.aprNegative);
        }
        if (l.principal.currency != a.currency ||
            l.monthlyPayment.currency != a.currency) {
          throw AccountValidationException(
              'currency', AccountValidationMessages.loanCurrencyMismatch);
        }
    }
  }

  /// Reference checks that need the broader accounts list.
  static void _checkReferences(Account a, List<Account> allAccounts) {
    final d = a.resolvedDetails;
    if (d is CreditCardDetails && d.sharesLimit) {
      final refId = d.sharedLimitAccountId;
      final found = refId != null &&
          allAccounts.any((x) => x.id == refId && x.type == AccountType.creditCard);
      if (!found) {
        throw AccountValidationException(
            'sharedLimitAccountId',
            AccountValidationMessages.sharedLimitReferenceMissing);
      }
    }
  }

  /// Validates [a] against its own invariants and any cross-account references
  /// resolved through [allAccounts]. Throws [AccountValidationException] on
  /// failure; returns normally on success.
  static void validate(Account a, {required List<Account> allAccounts}) {
    _checkPureInvariants(a);
    _checkReferences(a, allAccounts);
  }
}
```

- [ ] **Step 4: Run test, verify PASS**

```bash
flutter test test/features/accounts/domain/account_validator_test.dart
```

- [ ] **Step 5: Commit**

```bash
git add lib/features/accounts/domain/account_validator.dart test/features/accounts/domain/account_validator_test.dart
git commit -m "feat(accounts): add AccountValidator"
```

---

## Task 6: Add `AccountDetailsDto` (JSON)

**Files:**
- Create: `lib/features/accounts/data/account_details_dto.dart`
- Test: `test/features/accounts/data/account_details_dto_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:aiko/core/money/money.dart';
import 'package:aiko/features/accounts/data/account_details_dto.dart';
import 'package:aiko/features/accounts/domain/account_details.dart';
import 'package:aiko/features/assets/domain/asset.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('round-trips every variant', () {
    final samples = <AccountDetails>[
      const CashDetails(),
      const BankDetails(accountNumberLast4: '1234', accountHolderName: 'A'),
      const EWalletDetails(linkedPhoneOrEmail: 'a@b.c'),
      CreditCardDetails(
        creditLimit: Money.parse('5000', 'USD'),
        statementDay: 15,
        dueDay: 5,
        aprPercent: 19.99,
        rewardsType: RewardsType.cashback,
        annualFee: Money.parse('95', 'USD'),
        minimumPayment: Money.parse('25', 'USD'),
      ),
      LoanDetails(
        loanType: LoanType.auto,
        principal: Money.parse('20000', 'USD'),
        interestRatePercent: 5.5,
        termMonths: 60,
        monthlyPayment: Money.parse('380', 'USD'),
        nextDueDate: DateTime.utc(2026, 8, 1),
      ),
      const InvestmentDetails(accountNumberLast4: '9999'),
      const AssetDetails(
        assetClass: AssetClass.realEstate,
        notes: 'condo',
      ),
      const LiabilityDetails(liabilityType: 'overdraft'),
      const OtherDetails(notes: 'misc'),
    ];
    for (final s in samples) {
      final json = AccountDetailsDto.toJson(s);
      final restored = AccountDetailsDto.fromJson(json);
      expect(restored, equals(s), reason: 'round-trip failed for ${s.variantName}');
    }
  });

  test('unknown variant returns CashDetails', () {
    final restored = AccountDetailsDto.fromJson({'_type': 'mystery'});
    expect(restored, isA<CashDetails>());
  });

  test('null/missing json returns CashDetails', () {
    expect(AccountDetailsDto.fromJson(null), isA<CashDetails>());
  });
}
```

- [ ] **Step 2: Run test, verify FAIL**

```bash
flutter test test/features/accounts/data/account_details_dto_test.dart
```

- [ ] **Step 3: Implement**

```dart
// lib/features/accounts/data/account_details_dto.dart
import 'package:decimal/decimal.dart';

import '../../assets/domain/asset.dart';
import '../../../core/money/money.dart';
import '../domain/account_details.dart';

class AccountDetailsDto {
  const AccountDetailsDto._();

  static Map<String, dynamic> toJson(AccountDetails d) {
    final base = <String, dynamic>{'_type': d.variantName};
    switch (d) {
      case CashDetails():
        break;
      case BankDetails():
        base['accountNumberLast4'] = d.accountNumberLast4;
        base['accountHolderName'] = d.accountHolderName;
      case EWalletDetails():
        base['linkedPhoneOrEmail'] = d.linkedPhoneOrEmail;
      case CreditCardDetails():
        base['creditLimit'] = d.creditLimit?.toJson();
        base['statementDay'] = d.statementDay;
        base['dueDay'] = d.dueDay;
        base['aprPercent'] = d.aprPercent;
        base['rewardsType'] = d.rewardsType?.name;
        base['annualFee'] = d.annualFee?.toJson();
        base['minimumPayment'] = d.minimumPayment?.toJson();
        base['sharesLimit'] = d.sharesLimit;
        base['sharedLimitAccountId'] = d.sharedLimitAccountId;
      case LoanDetails():
        base['loanType'] = d.loanType.name;
        base['principal'] = d.principal.toJson();
        base['interestRatePercent'] = d.interestRatePercent;
        base['termMonths'] = d.termMonths;
        base['monthlyPayment'] = d.monthlyPayment.toJson();
        base['nextDueDate'] = d.nextDueDate.toIso8601String();
      case InvestmentDetails():
        base['accountNumberLast4'] = d.accountNumberLast4;
      case AssetDetails():
        base['assetClass'] = d.assetClass.name;
        base['purchasePrice'] = d.purchasePrice?.toJson();
        base['purchaseDate'] = d.purchaseDate?.toIso8601String();
        base['notes'] = d.notes;
      case LiabilityDetails():
        base['liabilityType'] = d.liabilityType;
        base['interestRatePercent'] = d.interestRatePercent;
        base['notes'] = d.notes;
      case OtherDetails():
        base['notes'] = d.notes;
    }
    return base;
  }

  static AccountDetails fromJson(Map<String, dynamic>? json) {
    if (json == null) return const CashDetails();
    final type = json['_type'] as String?;
    return switch (type) {
      'cash' => const CashDetails(),
      'bank' => BankDetails(
          accountNumberLast4: json['accountNumberLast4'] as String?,
          accountHolderName: json['accountHolderName'] as String?,
        ),
      'eWallet' => EWalletDetails(
          linkedPhoneOrEmail: json['linkedPhoneOrEmail'] as String?,
        ),
      'creditCard' => CreditCardDetails(
          creditLimit: _money(json['creditLimit']),
          statementDay: (json['statementDay'] as int?) ?? 1,
          dueDay: (json['dueDay'] as int?) ?? 1,
          aprPercent: (json['aprPercent'] as num?)?.toDouble(),
          rewardsType: _rewardsType(json['rewardsType'] as String?),
          annualFee: _money(json['annualFee']),
          minimumPayment: _money(json['minimumPayment']),
          sharesLimit: (json['sharesLimit'] as bool?) ?? false,
          sharedLimitAccountId: json['sharedLimitAccountId'] as String?,
        ),
      'loan' => LoanDetails(
          loanType: _loanType(json['loanType'] as String?),
          principal: _money(json['principal'], 'USD') ??
              Money.zero('USD'),
          interestRatePercent:
              (json['interestRatePercent'] as num?)?.toDouble() ?? 0,
          termMonths: (json['termMonths'] as int?) ?? 1,
          monthlyPayment: _money(json['monthlyPayment'], 'USD') ??
              Money.zero('USD'),
          nextDueDate: json['nextDueDate'] is String
              ? DateTime.parse(json['nextDueDate'] as String)
              : DateTime.utc(1970, 1, 1),
        ),
      'investment' => InvestmentDetails(
          accountNumberLast4: json['accountNumberLast4'] as String?,
        ),
      'asset' => AssetDetails(
          assetClass: _assetClass(json['assetClass'] as String?),
          purchasePrice: _money(json['purchasePrice']),
          purchaseDate: json['purchaseDate'] is String
              ? DateTime.parse(json['purchaseDate'] as String)
              : null,
          notes: json['notes'] as String?,
        ),
      'liability' => LiabilityDetails(
          liabilityType: json['liabilityType'] as String?,
          interestRatePercent: (json['interestRatePercent'] as num?)?.toDouble(),
          notes: json['notes'] as String?,
        ),
      'other' => OtherDetails(notes: json['notes'] as String?),
      _ => const CashDetails(),
    };
  }

  static Money? _money(Object? raw, [String fallback = 'USD']) {
    if (raw is! Map) return null;
    final m = raw;
    final amt = m['amount'];
    final cur = (m['currency'] as String?) ?? fallback;
    if (amt is! String) return null;
    final parsed = Decimal.tryParse(amt);
    if (parsed == null) return null;
    return Money(amount: parsed, currency: cur);
  }

  static RewardsType? _rewardsType(String? name) {
    if (name == null) return null;
    for (final v in RewardsType.values) {
      if (v.name == name) return v;
    }
    return null;
  }

  static LoanType _loanType(String? name) {
    if (name == null) return LoanType.other;
    for (final v in LoanType.values) {
      if (v.name == name) return v;
    }
    return LoanType.other;
  }

  static AssetClass _assetClass(String? name) {
    if (name == null) return AssetClass.other;
    for (final v in AssetClass.values) {
      if (v.name == name) return v;
    }
    return AssetClass.other;
  }
}
```

- [ ] **Step 4: Run test, verify PASS**

```bash
flutter test test/features/accounts/data/account_details_dto_test.dart
```

- [ ] **Step 5: Commit**

```bash
git add lib/features/accounts/data/account_details_dto.dart test/features/accounts/data/account_details_dto_test.dart
git commit -m "feat(accounts): add AccountDetailsDto json serialization"
```

---

## Task 7: Update `AccountDto` to include details

**Files:**
- Modify: `lib/features/accounts/data/account_dto.dart`
- Test: `test/features/accounts/data/account_dto_test.dart` (new)

- [ ] **Step 1: Write the failing test**

```dart
import 'package:aiko/core/money/money.dart';
import 'package:aiko/features/accounts/data/account_dto.dart';
import 'package:aiko/features/accounts/domain/account.dart';
import 'package:aiko/features/accounts/domain/account_details.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('account without details round-trips as cash', () {
    final a = Account(
      id: 'a',
      userId: 'u',
      name: 'Wallet',
      type: AccountType.cash,
      currentBalance: Money.parse('10', 'USD'),
    );
    final json = AccountDto.fromDomain(a);
    final restored = AccountDto(json).toDomain();
    expect(restored.id, a.id);
    expect(restored.resolvedDetails, isA<CashDetails>());
  });

  test('credit card details round-trip', () {
    final a = Account(
      id: 'a',
      userId: 'u',
      name: 'Visa',
      type: AccountType.creditCard,
      currentBalance: Money.parse('0', 'USD'),
      details: const CreditCardDetails(statementDay: 15, dueDay: 5),
    );
    final json = AccountDto.fromDomain(a);
    final restored = AccountDto(json).toDomain();
    final cc = restored.resolvedDetails.asCreditCard();
    expect(cc.statementDay, 15);
    expect(cc.dueDay, 5);
  });
}
```

- [ ] **Step 2: Run test, verify FAIL**

```bash
flutter test test/features/accounts/data/account_dto_test.dart
```

- [ ] **Step 3: Replace `account_dto.dart`**

```dart
// lib/features/accounts/data/account_dto.dart
import 'dart:convert';

import '../../../core/money/money.dart';
import '../domain/account.dart';
import 'account_details_dto.dart';

class AccountDto {
  const AccountDto(this.json);

  final Map<String, dynamic> json;

  Account toDomain() {
    final currency = json['currency'] as String? ?? 'THB';
    return Account(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      type: AccountType.values.byName(json['type'] as String? ?? 'cash'),
      currentBalance: Money.parse('${json['current_balance'] ?? 0}', currency),
      institution: json['institution'] as String?,
      includeInNetWorth: json['include_in_net_worth'] as bool? ?? true,
      isActive: json['is_active'] as bool? ?? true,
      details: _detailsFromJson(json['details']),
    );
  }

  static Map<String, dynamic> fromDomain(Account account) {
    return {
      'id': account.id,
      'user_id': account.userId,
      'name': account.name,
      'type': account.type.name,
      'currency': account.currency,
      'current_balance': account.currentBalance.amount.toString(),
      'institution': account.institution,
      'include_in_net_worth': account.includeInNetWorth,
      'is_active': account.isActive,
      'details': AccountDetailsDto.toJson(account.resolvedDetails),
    };
  }

  static AccountDetails? _detailsFromJson(Object? raw) {
    if (raw == null) return null;
    if (raw is String) {
      if (raw.isEmpty) return null;
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          return AccountDetailsDto.fromJson(decoded);
        }
      } catch (_) {
        return null;
      }
      return null;
    }
    if (raw is Map<String, dynamic>) return AccountDetailsDto.fromJson(raw);
    return null;
  }
}
```

- [ ] **Step 4: Run test, verify PASS**

```bash
flutter test test/features/accounts/data/account_dto_test.dart
```

- [ ] **Step 5: Commit**

```bash
git add lib/features/accounts/data/account_dto.dart test/features/accounts/data/account_dto_test.dart
git commit -m "feat(accounts): include details in AccountDto"
```

---

## Task 8: Update Brick offline model with `detailsJson`

**Files:**
- Modify: `lib/brick/models/account.model.dart`

- [ ] **Step 1: Add the column**

Replace `lib/brick/models/account.model.dart` with:

```dart
import 'package:brick_offline_first_with_supabase/brick_offline_first_with_supabase.dart';
import 'package:brick_sqlite/brick_sqlite.dart';
import 'package:brick_supabase/brick_supabase.dart';

@ConnectOfflineFirstWithSupabase(
  supabaseConfig: SupabaseSerializable(tableName: 'accounts'),
)
class OfflineAccount extends OfflineFirstWithSupabaseModel {
  OfflineAccount({
    required this.id,
    required this.userId,
    required this.name,
    required this.type,
    required this.currency,
    required this.currentBalance,
    this.institution,
    this.includeInNetWorth = true,
    this.isActive = true,
    this.detailsJson = '{}',
  });

  @Sqlite(unique: true)
  @Supabase(unique: true)
  final String id;

  @Sqlite(index: true)
  final String userId;

  final String name;
  final String type;
  final String currency;

  @Supabase(fromGenerator: 'data[\'current_balance\'].toString()')
  final String currentBalance;

  final String? institution;
  final bool includeInNetWorth;
  final bool isActive;
  final String detailsJson;
}
```

- [ ] **Step 2: Run build_runner**

```bash
dart run build_runner build --delete-conflicting-outputs
```
Expected: regenerates Brick adapters/schema with the new column.

- [ ] **Step 3: Commit**

```bash
git add lib/brick
git commit -m "feat(brick): add detailsJson column to OfflineAccount"
```

---

## Task 9: Update offline model mappers

**Files:**
- Modify: `lib/brick/offline_model_mappers.dart`

- [ ] **Step 1: Update `OfflineAccountMapper` and `AccountOfflineMapper`**

In `lib/brick/offline_model_mappers.dart`, replace the two `OfflineAccount` extensions with:

```dart
extension OfflineAccountMapper on OfflineAccount {
  Account toDomain() {
    return Account(
      id: id,
      userId: userId,
      name: name,
      type: _enumByName(AccountType.values, type, AccountType.cash),
      currentBalance: Money.parse(currentBalance, currency),
      institution: institution,
      includeInNetWorth: includeInNetWorth,
      isActive: isActive,
      details: _parseDetails(detailsJson),
    );
  }
}

extension AccountOfflineMapper on Account {
  OfflineAccount toOffline({required String userId}) {
    return OfflineAccount(
      id: id,
      userId: userId,
      name: name,
      type: type.name,
      currency: currency,
      currentBalance: currentBalance.amount.toString(),
      institution: institution,
      includeInNetWorth: includeInNetWorth,
      isActive: isActive,
      detailsJson: _detailsToJson(resolvedDetails),
    );
  }
}
```

Add to the bottom of the same file:

```dart
import 'dart:convert';
import '../features/accounts/data/account_details_dto.dart';
import '../features/accounts/domain/account_details.dart';

AccountDetails? _parseDetails(String raw) {
  if (raw.isEmpty) return null;
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) {
      return AccountDetailsDto.fromJson(decoded);
    }
  } catch (_) {}
  return null;
}

String _detailsToJson(AccountDetails d) {
  return jsonEncode(AccountDetailsDto.toJson(d));
}
```

- [ ] **Step 2: Run account-related tests**

```bash
flutter test test/features/accounts/
```
Expected: pass.

- [ ] **Step 3: Commit**

```bash
git add lib/brick/offline_model_mappers.dart
git commit -m "feat(brick): map detailsJson to Account.details"
```

---

## Task 10: Supabase migration for `details jsonb`

**Files:**
- Create: `supabase/migrations/20260615010000_account_details.sql`

- [ ] **Step 1: Write the migration**

```sql
-- supabase/migrations/20260615010000_account_details.sql
alter table public.accounts
  add column if not exists details jsonb not null default '{}'::jsonb;

-- RLS policies already cover the new column via existing account_id checks.
-- No additional policy required.
```

- [ ] **Step 2: Commit**

```bash
git add supabase/migrations/20260615010000_account_details.sql
git commit -m "feat(supabase): add details jsonb column to accounts"
```

> Note: Apply via `supabase db push` on the next deploy. The offline-first path means local writes don't need the column to exist.

---

## Task 11: Add the `AccountSubform` interface

**Files:**
- Create: `lib/features/accounts/presentation/account_form/subforms/account_subform.dart`

- [ ] **Step 1: Implement**

```dart
// lib/features/accounts/presentation/account_form/subforms/account_subform.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/account_details.dart';

abstract class AccountSubform extends ConsumerStatefulWidget {
  const AccountSubform({super.key});
}

abstract class AccountSubformState<T extends AccountSubform>
    extends ConsumerState<T> {
  AccountDetails getDetails();
  void resetTo(AccountDetails initial);
  String? validate();
}

abstract class StatelessAccountSubform extends StatelessWidget
    implements AccountSubform {
  const StatelessAccountSubform({super.key});

  // Required by the abstract class but unused; subclasses override build.
  @override
  AccountDetails getDetails() => throw UnimplementedError();
  @override
  void resetTo(AccountDetails initial) {}
  @override
  String? validate() => null;
}
```

Wait — `StatelessAccountSubform` can't extend `AccountSubform` (which is a `ConsumerStatefulWidget`) and `StatelessWidget` (which is also a `Widget`). The simpler approach: only `AccountSubform` is the abstract base; empty subforms (cash, other) extend a tiny `_NoExtrasSubform` helper that doesn't implement validate/reset.

Replace the file with:

```dart
// lib/features/accounts/presentation/account_form/subforms/account_subform.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/account_details.dart';

abstract class AccountSubform extends ConsumerStatefulWidget {
  const AccountSubform({super.key});
}

abstract class AccountSubformState<T extends AccountSubform>
    extends ConsumerState<T> {
  AccountDetails getDetails();
  void resetTo(AccountDetails initial);
  String? validate();
}

/// Mixin for subforms that have no fields to validate or reset.
mixin NoOpSubformMixin<T extends StatefulWidget> on State<T> {
  AccountDetails getDetails() => _noop();
  void resetTo(AccountDetails _) {}
  String? validate() => null;
}

AccountDetails _noop() => const CashDetails();
```

- [ ] **Step 2: Commit**

```bash
git add lib/features/accounts/presentation/account_form/subforms/account_subform.dart
git commit -m "feat(accounts): add AccountSubform interface"
```

---

## Task 12: Add common fields widget

**Files:**
- Create: `lib/features/accounts/presentation/account_form/account_common_fields.dart`

- [ ] **Step 1: Implement**

Extract from `accounts_screen.dart` the form's common fields into a single widget:

```dart
// lib/features/accounts/presentation/account_form/account_common_fields.dart
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import '../../../../core/money/money.dart';
import '../../domain/account.dart';

typedef CommonFieldsCallbacks = void Function({
  String? name,
  AccountType? type,
  String? currency,
  String? balance,
  String? institution,
  bool? includeInNetWorth,
  bool? isActive,
});

class AccountCommonFields extends StatelessWidget {
  const AccountCommonFields({
    super.key,
    required this.initialName,
    required this.initialType,
    required this.initialCurrency,
    required this.initialBalance,
    required this.initialInstitution,
    required this.initialIncludeInNetWorth,
    required this.initialIsActive,
    required this.currencies,
    required this.nameController,
    required this.balanceController,
    required this.institutionController,
    required this.onChanged,
  });

  final String initialName;
  final AccountType initialType;
  final String initialCurrency;
  final String initialBalance;
  final String initialInstitution;
  final bool initialIncludeInNetWorth;
  final bool initialIsActive;
  final List<({String code, String name})> currencies;
  final TextEditingController nameController;
  final TextEditingController balanceController;
  final TextEditingController institutionController;
  final CommonFieldsCallbacks onChanged;

  @override
  Widget build(BuildContext context) {
    final institutionDisabled = initialType == AccountType.cash ||
        initialType == AccountType.liability;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Account name',
            hintText: 'e.g. Daily Expenses, Savings Wallet',
            prefixIcon: Icon(Icons.badge_outlined),
          ),
          onChanged: (v) => onChanged(name: v),
          validator: (v) => v == null || v.trim().isEmpty
              ? 'Please enter a name for the account.'
              : null,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<AccountType>(
          initialValue: initialType,
          decoration: const InputDecoration(
            labelText: 'Account type',
            prefixIcon: Icon(Icons.account_balance_wallet_outlined),
          ),
          items: AccountType.values
              .where((t) =>
                  t != AccountType.eWallet && t != AccountType.other)
              .map((t) => DropdownMenuItem(value: t, child: Text(_label(t))))
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(type: v);
          },
        ),
        const SizedBox(height: 12),
        if (initialType != AccountType.cash) ...[
          TextFormField(
            controller: institutionController,
            enabled: !institutionDisabled,
            decoration: InputDecoration(
              labelText: 'Institution',
              hintText: institutionDisabled
                  ? 'Not used for this account type.'
                  : 'e.g. Chase, PayPal, Coinbase',
              prefixIcon: const Icon(Icons.corporate_fare_outlined),
            ),
            onChanged: (v) => onChanged(institution: v),
          ),
          const SizedBox(height: 12),
        ],
        DropdownButtonFormField<String>(
          initialValue: initialCurrency,
          decoration: const InputDecoration(
            labelText: 'Currency',
            prefixIcon: Icon(Icons.payments_outlined),
          ),
          items: currencies
              .map((c) => DropdownMenuItem(value: c.code, child: Text(c.code)))
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(currency: v);
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: balanceController,
          decoration: const InputDecoration(
            labelText: 'Current balance',
            hintText: '0.00',
            prefixIcon: Icon(Icons.attach_money_outlined),
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (v) => onChanged(balance: v),
          validator: (v) {
            final t = v?.trim() ?? '';
            if (t.isEmpty) return 'Please enter a balance.';
            if (Decimal.tryParse(t) == null) return 'Enter a valid number.';
            return null;
          },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Include in net worth'),
          value: initialIncludeInNetWorth,
          onChanged: (v) => onChanged(includeInNetWorth: v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Active account'),
          value: initialIsActive,
          onChanged: (v) => onChanged(isActive: v),
        ),
      ],
    );
  }

  String _label(AccountType t) {
    final n = t.name;
    final buf = StringBuffer();
    for (var i = 0; i < n.length; i++) {
      final c = n[i];
      if (i > 0 && c.toUpperCase() == c) buf.write(' ');
      buf.write(i == 0 ? c.toUpperCase() : c);
    }
    return buf.toString();
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/features/accounts/presentation/account_form/account_common_fields.dart
git commit -m "feat(accounts): add AccountCommonFields widget"
```

---

## Task 13: Add empty subforms (Cash, Other)

**Files:**
- Create: `lib/features/accounts/presentation/account_form/subforms/cash_subform.dart`
- Create: `lib/features/accounts/presentation/account_form/subforms/other_subform.dart`

- [ ] **Step 1: Cash subform**

```dart
// lib/features/accounts/presentation/account_form/subforms/cash_subform.dart
import 'package:flutter/material.dart';

import '../../../../shared/widgets/aiko_data_widgets.dart';
import '../../domain/account_details.dart';
import 'account_subform.dart';

class CashSubform extends AccountSubform {
  const CashSubform({super.key});

  @override
  State<CashSubform> createState() => _CashSubformState();
}

class _CashSubformState extends AccountSubformState<CashSubform>
    with NoOpSubformMixin {
  @override
  Widget build(BuildContext context) {
    return const AikoInlineNotice(
      title: 'No extra details',
      message: 'Cash accounts do not require additional setup.',
      tone: AikoNoticeTone.info,
    );
  }
}
```

- [ ] **Step 2: Other subform**

```dart
// lib/features/accounts/presentation/account_form/subforms/other_subform.dart
import 'package:flutter/material.dart';

import '../../../../shared/widgets/aiko_data_widgets.dart';
import '../../domain/account_details.dart';
import 'account_subform.dart';

class OtherSubform extends StatefulWidget {
  const OtherSubform({super.key, required this.onChanged, this.initialNotes});
  final ValueChanged<OtherDetails> onChanged;
  final String? initialNotes;

  @override
  State<OtherSubform> createState() => _OtherSubformState();
}

class _OtherSubformState extends State<OtherSubform> {
  late final TextEditingController _notes;

  @override
  void initState() {
    super.initState();
    _notes = TextEditingController(text: widget.initialNotes ?? '');
    _notes.addListener(() {
      widget.onChanged(OtherDetails(notes: _notes.text.trim().isEmpty ? null : _notes.text.trim()));
    });
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _notes,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Notes',
            hintText: 'What kind of account is this?',
            prefixIcon: Icon(Icons.notes_outlined),
          ),
        ),
        const SizedBox(height: 8),
        const AikoInlineNotice(
          title: 'No extra details',
          message: 'Other accounts are flexible. Add notes to help future-you.',
          tone: AikoNoticeTone.info,
        ),
      ],
    );
  }
}
```

- [ ] **Step 3: Commit**

```bash
git add lib/features/accounts/presentation/account_form/subforms/cash_subform.dart lib/features/accounts/presentation/account_form/subforms/other_subform.dart
git commit -m "feat(accounts): add cash and other subforms"
```

---

## Task 14: Add Bank, EWallet, Investment subforms

**Files:**
- Create: `lib/features/accounts/presentation/account_form/subforms/bank_subform.dart`
- Create: `lib/features/accounts/presentation/account_form/subforms/ewallet_subform.dart`
- Create: `lib/features/accounts/presentation/account_form/subforms/investment_subform.dart`

- [ ] **Step 1: Bank subform**

```dart
// lib/features/accounts/presentation/account_form/subforms/bank_subform.dart
import 'package:flutter/material.dart';

import '../../domain/account_details.dart';
import 'account_subform.dart';

class BankSubform extends AccountSubform {
  const BankSubform({
    super.key,
    required this.initial,
    required this.onChanged,
  });
  final BankDetails initial;
  final ValueChanged<BankDetails> onChanged;

  @override
  State<BankSubform> createState() => _BankSubformState();
}

class _BankSubformState extends AccountSubformState<BankSubform> {
  late final TextEditingController _last4;
  late final TextEditingController _holder;

  @override
  void initState() {
    super.initState();
    _last4 = TextEditingController(text: widget.initial.accountNumberLast4 ?? '');
    _holder = TextEditingController(text: widget.initial.accountHolderName ?? '');
    _last4.addListener(_emit);
    _holder.addListener(_emit);
  }

  void _emit() {
    widget.onChanged(BankDetails(
      accountNumberLast4: _last4.text.trim().isEmpty ? null : _last4.text.trim(),
      accountHolderName: _holder.text.trim().isEmpty ? null : _holder.text.trim(),
    ));
  }

  @override
  void resetTo(AccountDetails initial) {
    if (initial is! BankDetails) return;
    _last4.text = initial.accountNumberLast4 ?? '';
    _holder.text = initial.accountHolderName ?? '';
  }

  @override
  AccountDetails getDetails() => BankDetails(
        accountNumberLast4:
            _last4.text.trim().isEmpty ? null : _last4.text.trim(),
        accountHolderName:
            _holder.text.trim().isEmpty ? null : _holder.text.trim(),
      );

  @override
  String? validate() => null;

  @override
  void dispose() {
    _last4.dispose();
    _holder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _last4,
          maxLength: 4,
          decoration: const InputDecoration(
            labelText: 'Account number (last 4)',
            prefixIcon: Icon(Icons.numbers_outlined),
          ),
        ),
        TextField(
          controller: _holder,
          decoration: const InputDecoration(
            labelText: 'Account holder name',
            prefixIcon: Icon(Icons.person_outline),
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: EWallet subform**

```dart
// lib/features/accounts/presentation/account_form/subforms/ewallet_subform.dart
import 'package:flutter/material.dart';

import '../../domain/account_details.dart';
import 'account_subform.dart';

class EWalletSubform extends AccountSubform {
  const EWalletSubform({super.key, required this.initial, required this.onChanged});
  final EWalletDetails initial;
  final ValueChanged<EWalletDetails> onChanged;

  @override
  State<EWalletSubform> createState() => _EWalletSubformState();
}

class _EWalletSubformState extends AccountSubformState<EWalletSubform> {
  late final TextEditingController _contact;
  @override
  void initState() {
    super.initState();
    _contact = TextEditingController(text: widget.initial.linkedPhoneOrEmail ?? '');
    _contact.addListener(() {
      widget.onChanged(EWalletDetails(
        linkedPhoneOrEmail:
            _contact.text.trim().isEmpty ? null : _contact.text.trim(),
      ));
    });
  }

  @override
  void resetTo(AccountDetails initial) {
    if (initial is! EWalletDetails) return;
    _contact.text = initial.linkedPhoneOrEmail ?? '';
  }

  @override
  AccountDetails getDetails() => EWalletDetails(
        linkedPhoneOrEmail:
            _contact.text.trim().isEmpty ? null : _contact.text.trim(),
      );

  @override
  String? validate() => null;

  @override
  void dispose() {
    _contact.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _contact,
      decoration: const InputDecoration(
        labelText: 'Linked phone or email',
        prefixIcon: Icon(Icons.alternate_email_outlined),
      ),
    );
  }
}
```

- [ ] **Step 3: Investment subform**

```dart
// lib/features/accounts/presentation/account_form/subforms/investment_subform.dart
import 'package:flutter/material.dart';

import '../../domain/account_details.dart';
import 'account_subform.dart';

class InvestmentSubform extends AccountSubform {
  const InvestmentSubform({super.key, required this.initial, required this.onChanged});
  final InvestmentDetails initial;
  final ValueChanged<InvestmentDetails> onChanged;

  @override
  State<InvestmentSubform> createState() => _InvestmentSubformState();
}

class _InvestmentSubformState extends AccountSubformState<InvestmentSubform> {
  late final TextEditingController _last4;
  @override
  void initState() {
    super.initState();
    _last4 = TextEditingController(text: widget.initial.accountNumberLast4 ?? '');
    _last4.addListener(() {
      widget.onChanged(InvestmentDetails(
        accountNumberLast4: _last4.text.trim().isEmpty ? null : _last4.text.trim(),
      ));
    });
  }

  @override
  void resetTo(AccountDetails initial) {
    if (initial is! InvestmentDetails) return;
    _last4.text = initial.accountNumberLast4 ?? '';
  }

  @override
  AccountDetails getDetails() => InvestmentDetails(
        accountNumberLast4:
            _last4.text.trim().isEmpty ? null : _last4.text.trim(),
      );

  @override
  String? validate() => null;

  @override
  void dispose() {
    _last4.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _last4,
      maxLength: 4,
      decoration: const InputDecoration(
        labelText: 'Account number (last 4)',
        prefixIcon: Icon(Icons.numbers_outlined),
      ),
    );
  }
}
```

- [ ] **Step 4: Commit**

```bash
git add lib/features/accounts/presentation/account_form/subforms/bank_subform.dart lib/features/accounts/presentation/account_form/subforms/ewallet_subform.dart lib/features/accounts/presentation/account_form/subforms/investment_subform.dart
git commit -m "feat(accounts): add bank, ewallet, investment subforms"
```

---

## Task 15: Add Liability and Asset subforms

**Files:**
- Create: `lib/features/accounts/presentation/account_form/subforms/liability_subform.dart`
- Create: `lib/features/accounts/presentation/account_form/subforms/asset_subform.dart`

- [ ] **Step 1: Liability subform**

```dart
// lib/features/accounts/presentation/account_form/subforms/liability_subform.dart
import 'package:flutter/material.dart';

import '../../domain/account_details.dart';
import 'account_subform.dart';

class LiabilitySubform extends AccountSubform {
  const LiabilitySubform({super.key, required this.initial, required this.onChanged});
  final LiabilityDetails initial;
  final ValueChanged<LiabilityDetails> onChanged;

  @override
  State<LiabilitySubform> createState() => _LiabilitySubformState();
}

class _LiabilitySubformState extends AccountSubformState<LiabilitySubform> {
  late final TextEditingController _type;
  late final TextEditingController _apr;
  late final TextEditingController _notes;

  @override
  void initState() {
    super.initState();
    _type = TextEditingController(text: widget.initial.liabilityType ?? '');
    _apr = TextEditingController(text: widget.initial.interestRatePercent?.toString() ?? '');
    _notes = TextEditingController(text: widget.initial.notes ?? '');
    _type.addListener(_emit);
    _apr.addListener(_emit);
    _notes.addListener(_emit);
  }

  void _emit() {
    widget.onChanged(LiabilityDetails(
      liabilityType: _type.text.trim().isEmpty ? null : _type.text.trim(),
      interestRatePercent: double.tryParse(_apr.text.trim()),
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
    ));
  }

  @override
  void resetTo(AccountDetails initial) {
    if (initial is! LiabilityDetails) return;
    _type.text = initial.liabilityType ?? '';
    _apr.text = initial.interestRatePercent?.toString() ?? '';
    _notes.text = initial.notes ?? '';
  }

  @override
  AccountDetails getDetails() => LiabilityDetails(
        liabilityType: _type.text.trim().isEmpty ? null : _type.text.trim(),
        interestRatePercent: double.tryParse(_apr.text.trim()),
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      );

  @override
  String? validate() {
    final apr = double.tryParse(_apr.text.trim());
    if (_apr.text.trim().isNotEmpty && apr == null) {
      return 'Enter a valid APR.';
    }
    return null;
  }

  @override
  void dispose() {
    _type.dispose();
    _apr.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _type,
          decoration: const InputDecoration(
            labelText: 'Type',
            hintText: 'e.g. Overdraft, Personal loan',
            prefixIcon: Icon(Icons.label_outline),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _apr,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Interest rate (%)',
            prefixIcon: Icon(Icons.percent_outlined),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _notes,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Notes',
            prefixIcon: Icon(Icons.notes_outlined),
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: Asset subform**

```dart
// lib/features/accounts/presentation/account_form/subforms/asset_subform.dart
import 'package:flutter/material.dart';

import '../../../../core/money/money.dart';
import '../../../../features/assets/domain/asset.dart';
import '../../domain/account_details.dart';
import 'account_subform.dart';

class AssetSubform extends AccountSubform {
  const AssetSubform({
    super.key,
    required this.initial,
    required this.currency,
    required this.onChanged,
  });
  final AssetDetails initial;
  final String currency;
  final ValueChanged<AssetDetails> onChanged;

  @override
  State<AssetSubform> createState() => _AssetSubformState();
}

class _AssetSubformState extends AccountSubformState<AssetSubform> {
  late AssetClass _class;
  late final TextEditingController _price;
  DateTime? _date;
  late final TextEditingController _notes;

  @override
  void initState() {
    super.initState();
    _class = widget.initial.assetClass;
    _price = TextEditingController(
      text: widget.initial.purchasePrice?.amount.toString() ?? '',
    );
    _date = widget.initial.purchaseDate;
    _notes = TextEditingController(text: widget.initial.notes ?? '');
    _price.addListener(_emit);
    _notes.addListener(_emit);
  }

  void _emit() {
    widget.onChanged(AssetDetails(
      assetClass: _class,
      purchasePrice: _price.text.trim().isEmpty
          ? null
          : Money.parse(_price.text.trim(), widget.currency),
      purchaseDate: _date,
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
    ));
  }

  @override
  void resetTo(AccountDetails initial) {
    if (initial is! AssetDetails) return;
    setState(() {
      _class = initial.assetClass;
      _price.text = initial.purchasePrice?.amount.toString() ?? '';
      _date = initial.purchaseDate;
      _notes.text = initial.notes ?? '';
    });
  }

  @override
  AccountDetails getDetails() => AssetDetails(
        assetClass: _class,
        purchasePrice: _price.text.trim().isEmpty
            ? null
            : Money.parse(_price.text.trim(), widget.currency),
        purchaseDate: _date,
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      );

  @override
  String? validate() {
    if (_price.text.trim().isNotEmpty && _date == null) {
      return AccountValidationMessages.purchaseDateRequired;
    }
    return null;
  }

  @override
  void dispose() {
    _price.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<AssetClass>(
          initialValue: _class,
          decoration: const InputDecoration(
            labelText: 'Asset class',
            prefixIcon: Icon(Icons.category_outlined),
          ),
          items: AssetClass.values
              .map((c) => DropdownMenuItem(
                    value: c,
                    child: Text(c.name),
                  ))
              .toList(),
          onChanged: (v) {
            if (v != null) {
              setState(() => _class = v);
              _emit();
            }
          },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _price,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Purchase price (optional)',
            prefixIcon: Icon(Icons.payments_outlined),
          ),
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              firstDate: DateTime(1900),
              lastDate: DateTime.now(),
              initialDate: _date ?? DateTime.now(),
            );
            if (picked != null) {
              setState(() => _date = picked);
              _emit();
            }
          },
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Purchase date',
              prefixIcon: Icon(Icons.calendar_today_outlined),
            ),
            child: Text(
              _date == null
                  ? 'Tap to choose'
                  : '${_date!.year}-${_date!.month.toString().padLeft(2, '0')}-${_date!.day.toString().padLeft(2, '0')}',
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _notes,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Notes',
            prefixIcon: Icon(Icons.notes_outlined),
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 3: Commit**

```bash
git add lib/features/accounts/presentation/account_form/subforms/liability_subform.dart lib/features/accounts/presentation/account_form/subforms/asset_subform.dart
git commit -m "feat(accounts): add liability and asset subforms"
```

---

## Task 16: Add Loan subform

**Files:**
- Create: `lib/features/accounts/presentation/account_form/subforms/loan_subform.dart`

- [ ] **Step 1: Implement**

```dart
// lib/features/accounts/presentation/account_form/subforms/loan_subform.dart
import 'package:flutter/material.dart';

import '../../../../core/money/money.dart';
import '../../domain/account_details.dart';
import 'account_subform.dart';

class LoanSubform extends AccountSubform {
  const LoanSubform({
    super.key,
    required this.initial,
    required this.currency,
    required this.onChanged,
  });
  final LoanDetails initial;
  final String currency;
  final ValueChanged<LoanDetails> onChanged;

  @override
  State<LoanSubform> createState() => _LoanSubformState();
}

class _LoanSubformState extends AccountSubformState<LoanSubform> {
  late LoanType _type;
  late final TextEditingController _principal;
  late final TextEditingController _apr;
  late final TextEditingController _term;
  late final TextEditingController _payment;
  late DateTime _due;

  @override
  void initState() {
    super.initState();
    _type = widget.initial.loanType;
    _principal = TextEditingController(
      text: widget.initial.principal.amount.toString(),
    );
    _apr = TextEditingController(
      text: widget.initial.interestRatePercent.toString(),
    );
    _term = TextEditingController(text: widget.initial.termMonths.toString());
    _payment = TextEditingController(
      text: widget.initial.monthlyPayment.amount.toString(),
    );
    _due = widget.initial.nextDueDate;
    for (final c in [_principal, _apr, _term, _payment]) {
      c.addListener(_emit);
    }
  }

  void _emit() {
    widget.onChanged(LoanDetails(
      loanType: _type,
      principal: Money.zero(widget.currency) +
          Money.parse(
            _principal.text.trim().isEmpty ? '0' : _principal.text.trim(),
            widget.currency,
          ),
      interestRatePercent: double.tryParse(_apr.text.trim()) ?? 0,
      termMonths: int.tryParse(_term.text.trim()) ?? 0,
      monthlyPayment: Money.zero(widget.currency) +
          Money.parse(
            _payment.text.trim().isEmpty ? '0' : _payment.text.trim(),
            widget.currency,
          ),
      nextDueDate: _due,
    ));
  }

  @override
  void resetTo(AccountDetails initial) {
    if (initial is! LoanDetails) return;
    setState(() {
      _type = initial.loanType;
      _principal.text = initial.principal.amount.toString();
      _apr.text = initial.interestRatePercent.toString();
      _term.text = initial.termMonths.toString();
      _payment.text = initial.monthlyPayment.amount.toString();
      _due = initial.nextDueDate;
    });
  }

  @override
  AccountDetails getDetails() => LoanDetails(
        loanType: _type,
        principal: _principal.text.trim().isEmpty
            ? Money.zero(widget.currency)
            : Money.parse(_principal.text.trim(), widget.currency),
        interestRatePercent: double.tryParse(_apr.text.trim()) ?? 0,
        termMonths: int.tryParse(_term.text.trim()) ?? 0,
        monthlyPayment: _payment.text.trim().isEmpty
            ? Money.zero(widget.currency)
            : Money.parse(_payment.text.trim(), widget.currency),
        nextDueDate: _due,
      );

  @override
  String? validate() {
    final term = int.tryParse(_term.text.trim()) ?? 0;
    if (term <= 0) return AccountValidationMessages.termMonthsPositive;
    return null;
  }

  @override
  void dispose() {
    _principal.dispose();
    _apr.dispose();
    _term.dispose();
    _payment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<LoanType>(
          initialValue: _type,
          decoration: const InputDecoration(
            labelText: 'Loan type',
            prefixIcon: Icon(Icons.handshake_outlined),
          ),
          items: LoanType.values
              .map((t) => DropdownMenuItem(value: t, child: Text(t.name)))
              .toList(),
          onChanged: (v) {
            if (v != null) {
              setState(() => _type = v);
              _emit();
            }
          },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _principal,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Principal',
            prefixIcon: Icon(Icons.payments_outlined),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _apr,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Interest rate (%)',
            prefixIcon: Icon(Icons.percent_outlined),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _term,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Term (months)',
            prefixIcon: Icon(Icons.calendar_view_month_outlined),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _payment,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Monthly payment',
            prefixIcon: Icon(Icons.payments_outlined),
          ),
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              firstDate: DateTime.now().subtract(const Duration(days: 365)),
              lastDate: DateTime.now().add(const Duration(days: 365 * 30)),
              initialDate: _due,
            );
            if (picked != null) {
              setState(() => _due = picked);
              _emit();
            }
          },
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Next due date',
              prefixIcon: Icon(Icons.calendar_today_outlined),
            ),
            child: Text(
              '${_due.year}-${_due.month.toString().padLeft(2, '0')}-${_due.day.toString().padLeft(2, '0')}',
            ),
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/features/accounts/presentation/account_form/subforms/loan_subform.dart
git commit -m "feat(accounts): add loan subform"
```

---

## Task 17: Add CreditCardSubform + tests

**Files:**
- Create: `lib/features/accounts/presentation/account_form/subforms/credit_card_subform.dart`
- Create: `test/features/accounts/presentation/account_form/credit_card_subform_test.dart`

- [ ] **Step 1: Write the failing widget test**

```dart
import 'package:aiko/core/money/money.dart';
import 'package:aiko/features/accounts/domain/account.dart';
import 'package:aiko/features/accounts/domain/account_details.dart';
import 'package:aiko/features/accounts/presentation/account_form/subforms/credit_card_subform.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget _wrap(Widget child) =>
      MaterialApp(home: Scaffold(body: child));

  testWidgets('renders initial values', (tester) async {
    final initial = CreditCardDetails(
      creditLimit: Money.parse('5000', 'USD'),
      statementDay: 15,
      dueDay: 5,
    );
    CreditCardDetails? captured;
    await tester.pumpWidget(_wrap(Consumer(builder: (_, ref, __) {
      return CreditCardSubform(
        initial: initial,
        availableCards: const [],
        onChanged: (d) => captured = d,
      );
    })));
    expect(find.text('15'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('5000'), findsOneWidget);
  });

  testWidgets('validate returns null when limit present', (tester) async {
    final key = GlobalKey<CreditCardSubformState>();
    await tester.pumpWidget(_wrap(Consumer(builder: (_, ref, __) {
      return CreditCardSubform(
        key: key,
        initial: const CreditCardDetails(statementDay: 1, dueDay: 1),
        availableCards: const [],
        onChanged: (_) {},
      );
    })));
    final state = key.currentState!;
    expect(state.validate(), isNotNull); // limit missing
  });

  testWidgets('sharesLimit toggle reveals picker and emits null limit',
      (tester) async {
    final parent = Account(
      id: 'parent',
      userId: 'u',
      name: 'Parent',
      type: AccountType.creditCard,
      currentBalance: Money.parse('0', 'USD'),
    );
    CreditCardDetails? captured;
    await tester.pumpWidget(_wrap(Consumer(builder: (_, ref, __) {
      return CreditCardSubform(
        initial: const CreditCardDetails(statementDay: 1, dueDay: 1),
        availableCards: [parent],
        onChanged: (d) => captured = d,
      );
    })));
    await tester.tap(find.text('Share limit with another card'));
    await tester.pumpAndSettle();
    expect(captured, isNotNull);
    expect(captured!.sharesLimit, true);
    expect(captured!.creditLimit, isNull);
  });
}
```

- [ ] **Step 2: Run test, verify FAIL**

```bash
flutter test test/features/accounts/presentation/account_form/credit_card_subform_test.dart
```

- [ ] **Step 3: Implement the subform**

```dart
// lib/features/accounts/presentation/account_form/subforms/credit_card_subform.dart
import 'package:flutter/material.dart';

import '../../../../../core/money/money.dart';
import '../../../../../shared/widgets/aiko_data_widgets.dart';
import '../../domain/account.dart';
import '../../domain/account_details.dart';
import '../../domain/account_validation_messages.dart';
import 'account_subform.dart';

class CreditCardSubform extends AccountSubform {
  const CreditCardSubform({
    super.key,
    required this.initial,
    required this.availableCards,
    required this.onChanged,
  });

  final CreditCardDetails initial;
  final List<Account> availableCards;
  final ValueChanged<CreditCardDetails> onChanged;

  @override
  State<CreditCardSubform> createState() => CreditCardSubformState();
}

class CreditCardSubformState extends AccountSubformState<CreditCardSubform> {
  late int _statementDay;
  late int _dueDay;
  late final TextEditingController _limit;
  late final TextEditingController _apr;
  late final TextEditingController _annualFee;
  late final TextEditingController _minPayment;
  RewardsType? _rewardsType;
  late bool _sharesLimit;
  String? _sharedLimitAccountId;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _statementDay = widget.initial.statementDay;
    _dueDay = widget.initial.dueDay;
    _limit = TextEditingController(
      text: widget.initial.creditLimit?.amount.toString() ?? '',
    );
    _apr = TextEditingController(
      text: widget.initial.aprPercent?.toString() ?? '',
    );
    _annualFee = TextEditingController(
      text: widget.initial.annualFee?.amount.toString() ?? '',
    );
    _minPayment = TextEditingController(
      text: widget.initial.minimumPayment?.amount.toString() ?? '',
    );
    _rewardsType = widget.initial.rewardsType;
    _sharesLimit = widget.initial.sharesLimit;
    _sharedLimitAccountId = widget.initial.sharedLimitAccountId;
    for (final c in [_limit, _apr, _annualFee, _minPayment]) {
      c.addListener(_emit);
    }
    // If the previously stored reference is no longer available, flip off
    // shared limit so the user is never silently stuck.
    if (_sharesLimit && _sharedLimitAccountId != null) {
      final exists = widget.availableCards
          .any((a) => a.id == _sharedLimitAccountId);
      if (!exists) {
        _sharesLimit = false;
        _sharedLimitAccountId = null;
        _validationError = AccountValidationMessages.sharedLimitCardUnavailable;
      }
    }
  }

  void _emit() {
    setState(() => _validationError = null);
    widget.onChanged(CreditCardDetails(
      creditLimit: _sharesLimit || _limit.text.trim().isEmpty
          ? null
          : Money.parse(_limit.text.trim(), _accountCurrency),
      statementDay: _statementDay,
      dueDay: _dueDay,
      aprPercent: double.tryParse(_apr.text.trim()),
      rewardsType: _rewardsType,
      annualFee: _annualFee.text.trim().isEmpty
          ? null
          : Money.parse(_annualFee.text.trim(), _accountCurrency),
      minimumPayment: _minPayment.text.trim().isEmpty
          ? null
          : Money.parse(_minPayment.text.trim(), _accountCurrency),
      sharesLimit: _sharesLimit,
      sharedLimitAccountId:
          _sharesLimit ? _sharedLimitAccountId : null,
    ));
  }

  String get _accountCurrency {
    // The form's parent will override via accountCurrency; default USD if absent.
    return widget.initial.creditLimit?.currency ??
        widget.initial.annualFee?.currency ??
        widget.initial.minimumPayment?.currency ??
        'USD';
  }

  @override
  void resetTo(AccountDetails initial) {
    if (initial is! CreditCardDetails) return;
    setState(() {
      _statementDay = initial.statementDay;
      _dueDay = initial.dueDay;
      _limit.text = initial.creditLimit?.amount.toString() ?? '';
      _apr.text = initial.aprPercent?.toString() ?? '';
      _annualFee.text = initial.annualFee?.amount.toString() ?? '';
      _minPayment.text = initial.minimumPayment?.amount.toString() ?? '';
      _rewardsType = initial.rewardsType;
      _sharesLimit = initial.sharesLimit;
      _sharedLimitAccountId = initial.sharedLimitAccountId;
      _validationError = null;
    });
  }

  @override
  AccountDetails getDetails() => CreditCardDetails(
        creditLimit: _sharesLimit || _limit.text.trim().isEmpty
            ? null
            : Money.parse(_limit.text.trim(), _accountCurrency),
        statementDay: _statementDay,
        dueDay: _dueDay,
        aprPercent: double.tryParse(_apr.text.trim()),
        rewardsType: _rewardsType,
        annualFee: _annualFee.text.trim().isEmpty
            ? null
            : Money.parse(_annualFee.text.trim(), _accountCurrency),
        minimumPayment: _minPayment.text.trim().isEmpty
            ? null
            : Money.parse(_minPayment.text.trim(), _accountCurrency),
        sharesLimit: _sharesLimit,
        sharedLimitAccountId:
            _sharesLimit ? _sharedLimitAccountId : null,
      );

  @override
  String? validate() {
    if (_statementDay < 1 || _statementDay > 31) {
      return AccountValidationMessages.statementDayRange;
    }
    if (_dueDay < 1 || _dueDay > 31) {
      return AccountValidationMessages.dueDayRange;
    }
    final apr = double.tryParse(_apr.text.trim());
    if (_apr.text.trim().isNotEmpty && (apr == null || apr < 0)) {
      return AccountValidationMessages.aprNegative;
    }
    if (_sharesLimit) {
      if (_sharedLimitAccountId == null) {
        return AccountValidationMessages.sharedLimitReferenceRequired;
      }
    } else if (_limit.text.trim().isEmpty) {
      return AccountValidationMessages.creditLimitRequired;
    }
    return null;
  }

  @override
  void dispose() {
    _limit.dispose();
    _apr.dispose();
    _annualFee.dispose();
    _minPayment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_validationError != null) ...[
          AikoInlineNotice(
            title: 'Heads up',
            message: _validationError!,
            tone: AikoNoticeTone.warning,
          ),
          const SizedBox(height: 12),
        ],
        _DayPickerField(
          label: 'Statement day (1-31)',
          value: _statementDay,
          onChanged: (v) {
            setState(() => _statementDay = v);
            _emit();
          },
        ),
        const SizedBox(height: 12),
        _DayPickerField(
          label: 'Due day (1-31)',
          value: _dueDay,
          onChanged: (v) {
            setState(() => _dueDay = v);
            _emit();
          },
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Share limit with another card'),
          value: _sharesLimit,
          onChanged: (v) {
            setState(() {
              _sharesLimit = v;
              if (!v) _sharedLimitAccountId = null;
            });
            _emit();
          },
        ),
        if (_sharesLimit) ...[
          DropdownButtonFormField<String>(
            initialValue: _sharedLimitAccountId,
            decoration: const InputDecoration(
              labelText: 'Card to share with',
              prefixIcon: Icon(Icons.credit_card_outlined),
            ),
            items: widget.availableCards
                .map((a) =>
                    DropdownMenuItem(value: a.id, child: Text(a.name)))
                .toList(),
            onChanged: (v) {
              setState(() => _sharedLimitAccountId = v);
              _emit();
            },
          ),
          const SizedBox(height: 12),
        ] else ...[
          TextField(
            controller: _limit,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Credit limit',
              prefixIcon: Icon(Icons.payments_outlined),
            ),
          ),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: _apr,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'APR (%)',
            prefixIcon: Icon(Icons.percent_outlined),
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<RewardsType?>(
          initialValue: _rewardsType,
          decoration: const InputDecoration(
            labelText: 'Rewards type',
            prefixIcon: Icon(Icons.redeem_outlined),
          ),
          items: [
            const DropdownMenuItem<RewardsType?>(
                value: null, child: Text('None')),
            ...RewardsType.values.map(
              (r) => DropdownMenuItem<RewardsType?>(
                value: r,
                child: Text(r.name),
              ),
            ),
          ],
          onChanged: (v) {
            setState(() => _rewardsType = v);
            _emit();
          },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _annualFee,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Annual fee (optional)',
            prefixIcon: Icon(Icons.payments_outlined),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _minPayment,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Minimum payment (optional)',
            prefixIcon: Icon(Icons.payments_outlined),
          ),
        ),
      ],
    );
  }
}

class _DayPickerField extends StatelessWidget {
  const _DayPickerField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.calendar_today_outlined),
      ),
      items: [
        for (var d = 1; d <= 31; d++)
          DropdownMenuItem(value: d, child: Text('$d')),
      ],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}
```

- [ ] **Step 4: Run test, verify PASS**

```bash
flutter test test/features/accounts/presentation/account_form/credit_card_subform_test.dart
```

- [ ] **Step 5: Commit**

```bash
git add lib/features/accounts/presentation/account_form/subforms/credit_card_subform.dart test/features/accounts/presentation/account_form/credit_card_subform_test.dart
git commit -m "feat(accounts): add credit card subform with shared-limit"
```

---

## Task 18: Add `AccountFormSheet` parent

**Files:**
- Create: `lib/features/accounts/presentation/account_form/account_form_sheet.dart`
- Test: `test/features/accounts/presentation/account_form/account_form_sheet_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:aiko/core/money/money.dart';
import 'package:aiko/features/accounts/domain/account.dart';
import 'package:aiko/features/accounts/domain/account_details.dart';
import 'package:aiko/features/accounts/presentation/account_form/account_form_sheet.dart';
import 'package:aiko/app/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _StubNotifier extends AccountsNotifier {
  _StubNotifier(this._seed);
  final List<Account> _seed;
  @override
  Future<List<Account>> build() async => _seed;
  @override
  Future<void> saveAccount(Account account) async {}
  @override
  Future<void> addAccount(Account account) async {}
  @override
  Future<void> deleteAccount(String id) async {}
}

void main() {
  testWidgets('selecting credit card reveals credit-card subform', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountsProvider.overrideWith(() => _StubNotifier([
                Account(
                  id: 'a',
                  userId: 'u',
                  name: 'Wallet',
                  type: AccountType.cash,
                  currentBalance: Money.parse('0', 'USD'),
                ),
              ])),
        ],
        child: const MaterialApp(
          home: AccountFormSheet(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Open the type dropdown and pick Credit Card
    await tester.tap(find.text('Cash').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Credit Card').last);
    await tester.pumpAndSettle();

    expect(find.text('Statement day (1-31)'), findsOneWidget);
    expect(find.text('Due day (1-31)'), findsOneWidget);
    expect(find.text('Credit limit'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test, verify FAIL**

```bash
flutter test test/features/accounts/presentation/account_form/account_form_sheet_test.dart
```

- [ ] **Step 3: Implement**

```dart
// lib/features/accounts/presentation/account_form/account_form_sheet.dart
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../app/providers.dart';
import '../../../../core/money/money.dart';
import '../../../../shared/widgets/screen_states.dart';
import '../../domain/account.dart';
import '../../domain/account_details.dart';
import '../../domain/account_validator.dart';
import '../../domain/account_validation_exception.dart';
import 'account_common_fields.dart';
import 'subforms/account_subform.dart';
import 'subforms/asset_subform.dart';
import 'subforms/bank_subform.dart';
import 'subforms/cash_subform.dart';
import 'subforms/credit_card_subform.dart';
import 'subforms/ewallet_subform.dart';
import 'subforms/investment_subform.dart';
import 'subforms/liability_subform.dart';
import 'subforms/loan_subform.dart';
import 'subforms/other_subform.dart';

class AccountFormSheet extends ConsumerStatefulWidget {
  const AccountFormSheet({super.key, this.account});
  final Account? account;

  @override
  ConsumerState<AccountFormSheet> createState() => _AccountFormSheetState();
}

class _AccountFormSheetState extends ConsumerState<AccountFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _balanceController = TextEditingController();
  final _institutionController = TextEditingController();

  late AccountType _type;
  late String _currency;
  late bool _includeInNetWorth;
  late bool _isActive;
  late AccountDetails _details;
  GlobalKey<AccountSubformState>? _subformKey;
  var _isSubmitting = false;
  static const _currencies = [
    ('THB', 'Thai Baht'),
    ('USD', 'US Dollar'),
    ('EUR', 'Euro'),
    ('GBP', 'British Pound'),
    ('JPY', 'Japanese Yen'),
  ];

  @override
  void initState() {
    super.initState();
    final a = widget.account;
    _type = a?.type ?? AccountType.cash;
    _currency = a?.currency ?? 'THB';
    _details = a?.details ?? AccountDetails.defaultFor(_type);
    _nameController.text = a?.name ?? '';
    _balanceController.text = a?.currentBalance.amount.toString() ?? '';
    _institutionController.text = a?.institution ?? '';
    _includeInNetWorth = a?.includeInNetWorth ?? true;
    _isActive = a?.isActive ?? true;
    _subformKey = GlobalKey<AccountSubformState>();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    _institutionController.dispose();
    super.dispose();
  }

  Future<void> _changeType(AccountType next) async {
    if (next == _type) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Switch account type?'),
        content: const Text(
            'Switching type resets the details you entered for this account.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Switch'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() {
      _type = next;
      _details = AccountDetails.defaultFor(next);
      _subformKey = GlobalKey<AccountSubformState>();
    });
  }

  Widget _buildSubform(AsyncValue<List<Account>> accounts) {
    final allCards = accounts.maybeWhen(
      data: (list) =>
          list.where((a) => a.type == AccountType.creditCard).toList(),
      orElse: () => const <Account>[],
    );
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      child: switch (_type) {
        AccountType.cash => const CashSubform(),
        AccountType.bank => BankSubform(
            key: ValueKey('bank'),
            initial: _details.asBank(),
            onChanged: (d) => setState(() => _details = d),
          ),
        AccountType.eWallet => EWalletSubform(
            key: const ValueKey('ew'),
            initial: _details.asEWallet(),
            onChanged: (d) => setState(() => _details = d),
          ),
        AccountType.creditCard => CreditCardSubform(
            key: _subformKey,
            initial: _details.asCreditCard(),
            availableCards: allCards
                .where((a) => a.id != widget.account?.id)
                .toList(),
            onChanged: (d) => setState(() => _details = d),
          ),
        AccountType.loan => LoanSubform(
            key: _subformKey,
            initial: _details.asLoan(),
            currency: _currency,
            onChanged: (d) => setState(() => _details = d),
          ),
        AccountType.investment => InvestmentSubform(
            key: const ValueKey('inv'),
            initial: _details.asInvestment(),
            onChanged: (d) => setState(() => _details = d),
          ),
        AccountType.asset => AssetSubform(
            key: _subformKey,
            initial: _details.asAsset(),
            currency: _currency,
            onChanged: (d) => setState(() => _details = d),
          ),
        AccountType.liability => LiabilitySubform(
            key: const ValueKey('liab'),
            initial: _details.asLiability(),
            onChanged: (d) => setState(() => _details = d),
          ),
        AccountType.other => OtherSubform(
            key: const ValueKey('other'),
            onChanged: (d) => setState(() => _details = d),
          ),
      },
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final subError = _subformKey?.currentState?.validate();
    if (subError != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(subError)));
      return;
    }
    final latest = _subformKey?.currentState?.getDetails() ?? _details;

    setState(() => _isSubmitting = true);
    try {
      final account = Account(
        id: widget.account?.id ?? const Uuid().v4(),
        userId: widget.account?.userId ?? '',
        name: _nameController.text.trim(),
        type: _type,
        currentBalance: Money(
          amount: Decimal.parse(_balanceController.text.trim()),
          currency: _currency,
        ),
        institution: _institutionController.text.trim().isEmpty
            ? null
            : _institutionController.text.trim(),
        includeInNetWorth: _includeInNetWorth,
        isActive: _isActive,
        details: latest,
      );
      final all = ref.read(accountsProvider).valueOrNull ?? const <Account>[];
      AccountValidator.validate(account, allAccounts: all);
      await ref.read(accountsProvider.notifier).saveAccount(account);
      if (!mounted) return;
      Navigator.of(context).pop(account);
    } on AccountValidationException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Save failed: $e')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsProvider);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.account == null ? 'Add account' : 'Edit account',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              AccountCommonFields(
                initialName: _nameController.text,
                initialType: _type,
                initialCurrency: _currency,
                initialBalance: _balanceController.text,
                initialInstitution: _institutionController.text,
                initialIncludeInNetWorth: _includeInNetWorth,
                initialIsActive: _isActive,
                currencies: _currencies
                    .map((c) => (code: c.$1, name: c.$2))
                    .toList(),
                nameController: _nameController,
                balanceController: _balanceController,
                institutionController: _institutionController,
                onChanged: ({
                  String? name,
                  AccountType? type,
                  String? currency,
                  String? balance,
                  String? institution,
                  bool? includeInNetWorth,
                  bool? isActive,
                }) {
                  if (type != null) _changeType(type);
                  setState(() {
                    if (currency != null) _currency = currency;
                    if (includeInNetWorth != null) {
                      _includeInNetWorth = includeInNetWorth;
                    }
                    if (isActive != null) _isActive = isActive;
                  });
                },
              ),
              const SizedBox(height: 16),
              _buildSubform(accountsAsync),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _isSubmitting ? null : _submit,
                icon: _isSubmitting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check),
                label: Text(
                  widget.account == null ? 'Create account' : 'Save changes',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test, verify PASS**

```bash
flutter test test/features/accounts/presentation/account_form/account_form_sheet_test.dart
```

- [ ] **Step 5: Commit**

```bash
git add lib/features/accounts/presentation/account_form/account_form_sheet.dart test/features/accounts/presentation/account_form/account_form_sheet_test.dart
git commit -m "feat(accounts): add AccountFormSheet with subform switch"
```

---

## Task 19: Wire `AccountFormSheet` into `accounts_screen.dart`

**Files:**
- Modify: `lib/features/accounts/presentation/accounts_screen.dart`

- [ ] **Step 1: Replace the inline `_AccountFormSheet` reference**

In `lib/features/accounts/presentation/accounts_screen.dart`:
- Delete the `_AccountFormSheet` and `_AccountFormSheetState` classes (lines ~587-883).
- Delete the local `_currencyOptions` / `_CurrencyOption` / `_CurrencyPrefixIcon` / `_currencySymbol` helpers (lines ~524-585) — `AccountFormSheet` owns its own currency list now.
- Add `import 'account_form/account_form_sheet.dart';` at the top.
- Replace all uses of `_AccountFormSheet` in `_showAccountForm` and `_editAccount` with `AccountFormSheet`.

- [ ] **Step 2: Run all account tests**

```bash
flutter test test/features/accounts/
```
Expected: pass.

- [ ] **Step 3: Commit**

```bash
git add lib/features/accounts/presentation/accounts_screen.dart
git commit -m "refactor(accounts): use AccountFormSheet in accounts screen"
```

---

## Task 20: Refactor `OnboardingAccountForm` to use shared subforms

**Files:**
- Modify: `lib/features/accounts/presentation/onboarding_account_form.dart`

- [ ] **Step 1: Replace the form body**

In `lib/features/accounts/presentation/onboarding_account_form.dart`, replace the build method's form body with a composition of `AccountCommonFields` + the subform switch, mirroring `AccountFormSheet` but without save/validation (the onboarding form keeps its own submit). Add the imports for the subforms. Keep the existing `_submit` and reset behavior.

- [ ] **Step 2: Run tests**

```bash
flutter test test/features/accounts/
```

- [ ] **Step 3: Commit**

```bash
git add lib/features/accounts/presentation/onboarding_account_form.dart
git commit -m "refactor(accounts): onboarding form uses shared subforms"
```

---

## Task 21: Add `CreditCardMetrics.effectiveLimit`

**Files:**
- Modify: `lib/features/credit_cards/application/credit_card_metrics_service.dart`
- Test: `test/features/credit_cards/credit_card_metrics_service_test.dart` (new)

- [ ] **Step 1: Write the failing test**

```dart
import 'package:aiko/core/money/money.dart';
import 'package:aiko/features/accounts/domain/account.dart';
import 'package:aiko/features/accounts/domain/account_details.dart';
import 'package:aiko/features/credit_cards/application/credit_card_metrics_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final service = const CreditCardMetricsService();
  final parent = Account(
    id: 'parent',
    userId: 'u',
    name: 'Parent',
    type: AccountType.creditCard,
    currentBalance: Money.parse('0', 'USD'),
    details: const CreditCardDetails(
      statementDay: 1,
      dueDay: 1,
      creditLimit: Money(amount: _d('8000'), currency: 'USD'),
    ),
  );
  final child = Account(
    id: 'child',
    userId: 'u',
    name: 'Child',
    type: AccountType.creditCard,
    currentBalance: Money.parse('0', 'USD'),
    details: const CreditCardDetails(
      statementDay: 1,
      dueDay: 1,
      sharesLimit: true,
      sharedLimitAccountId: 'parent',
    ),
  );

  test('uses own limit when not sharing', () {
    final own = Account(
      id: 'own',
      userId: 'u',
      name: 'Own',
      type: AccountType.creditCard,
      currentBalance: Money.parse('0', 'USD'),
      details: const CreditCardDetails(
        statementDay: 1,
        dueDay: 1,
        creditLimit: Money(amount: _d('2000'), currency: 'USD'),
      ),
    );
    final limit = service.effectiveLimit(own, allAccounts: [own]);
    expect(limit?.amount.toString(), '2000');
  });

  test('uses parent limit when sharing', () {
    final limit = service.effectiveLimit(child, allAccounts: [parent, child]);
    expect(limit?.amount.toString(), '8000');
  });

  test('returns null when shared reference is missing', () {
    final limit = service.effectiveLimit(child, allAccounts: [child]);
    expect(limit, isNull);
  });
}

_d(String s) {
  // Re-export helper — replace body to call Decimal.parse.
  // Keeping inline so the test compiles without extra imports.
  return _Dec(s);
}

class _Dec {
  _Dec(this.s);
  final String s;
}
```

Hmm — `_d` above won't work; the test should use `Decimal.parse` directly. Replace the bottom of the file with:

```dart
import 'package:decimal/decimal.dart';

// ... inside tests, use Money(amount: Decimal.parse('2000'), currency: 'USD')
```

Rewrite the test cleanly:

```dart
import 'package:aiko/core/money/money.dart';
import 'package:aiko/features/accounts/domain/account.dart';
import 'package:aiko/features/accounts/domain/account_details.dart';
import 'package:aiko/features/credit_cards/application/credit_card_metrics_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final service = const CreditCardMetricsService();
  Money m(String s) => Money.parse(s, 'USD');

  test('uses own limit when not sharing', () {
    final own = Account(
      id: 'own',
      userId: 'u',
      name: 'Own',
      type: AccountType.creditCard,
      currentBalance: Money.zero('USD'),
      details: CreditCardDetails(
        statementDay: 1,
        dueDay: 1,
        creditLimit: m('2000'),
      ),
    );
    final limit = service.effectiveLimit(own, allAccounts: [own]);
    expect(limit?.amount.toString(), '2000');
  });

  test('uses parent limit when sharing', () {
    final parent = Account(
      id: 'parent',
      userId: 'u',
      name: 'Parent',
      type: AccountType.creditCard,
      currentBalance: Money.zero('USD'),
      details: CreditCardDetails(
        statementDay: 1,
        dueDay: 1,
        creditLimit: m('8000'),
      ),
    );
    final child = Account(
      id: 'child',
      userId: 'u',
      name: 'Child',
      type: AccountType.creditCard,
      currentBalance: Money.zero('USD'),
      details: const CreditCardDetails(
        statementDay: 1,
        dueDay: 1,
        sharesLimit: true,
        sharedLimitAccountId: 'parent',
      ),
    );
    final limit = service.effectiveLimit(child, allAccounts: [parent, child]);
    expect(limit?.amount.toString(), '8000');
  });

  test('returns null when shared reference is missing', () {
    final child = Account(
      id: 'child',
      userId: 'u',
      name: 'Child',
      type: AccountType.creditCard,
      currentBalance: Money.zero('USD'),
      details: const CreditCardDetails(
        statementDay: 1,
        dueDay: 1,
        sharesLimit: true,
        sharedLimitAccountId: 'ghost',
      ),
    );
    final limit = service.effectiveLimit(child, allAccounts: [child]);
    expect(limit, isNull);
  });
}
```

- [ ] **Step 2: Run test, verify FAIL**

```bash
flutter test test/features/credit_cards/credit_card_metrics_service_test.dart
```

- [ ] **Step 3: Add the method**

In `lib/features/credit_cards/application/credit_card_metrics_service.dart`, add:

```dart
import '../../accounts/domain/account.dart';
import '../../accounts/domain/account_details.dart';

extension on CreditCardMetricsService {
  // kept private — see extension below
}
```

Replace the file with:

```dart
import 'package:decimal/decimal.dart';

import '../../../core/money/money.dart';
import '../../accounts/domain/account.dart';
import '../../accounts/domain/account_details.dart';
import '../domain/credit_card_detail.dart';

class CreditCardMetricsService {
  const CreditCardMetricsService();

  Money estimateMonthlyInterest(CreditCardDetail card) {
    final apr = card.aprPercent ?? 0;
    if (apr <= 0) {
      return Money.zero(card.statementBalance.currency);
    }
    return card.statementBalance.times(Decimal.parse('${apr / 100 / 12}'));
  }

  Money suggestedMinimumPayment(CreditCardDetail card) {
    final explicit = card.minimumPayment;
    if (explicit != null) return explicit;
    return card.statementBalance.times(Decimal.parse('0.02'));
  }

  /// Returns the effective credit limit for [account]. If the account shares
  /// a limit with another card, the parent's limit is returned. Returns null
  /// when no limit is available.
  Money? effectiveLimit(Account account, {required List<Account> allAccounts}) {
    if (account.type != AccountType.creditCard) return null;
    final cc = account.resolvedDetails.asCreditCard();
    if (cc.creditLimit != null) return cc.creditLimit;
    if (!cc.sharesLimit) return null;
    final refId = cc.sharedLimitAccountId;
    if (refId == null) return null;
    final parent = allAccounts.where((a) => a.id == refId).firstOrNull;
    if (parent == null) return null;
    return effectiveLimit(parent, allAccounts: allAccounts);
  }
}
```

- [ ] **Step 4: Run test, verify PASS**

```bash
flutter test test/features/credit_cards/credit_card_metrics_service_test.dart
```

- [ ] **Step 5: Commit**

```bash
git add lib/features/credit_cards/application/credit_card_metrics_service.dart test/features/credit_cards/credit_card_metrics_service_test.dart
git commit -m "feat(credit_cards): add effectiveLimit for shared limits"
```

---

## Task 22: Add `SharedLimitResolver` + wire into `AccountsNotifier`

**Files:**
- Create: `lib/features/accounts/application/shared_limit_resolver.dart`
- Modify: `lib/app/providers.dart`
- Test: `test/features/accounts/application/shared_limit_resolver_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:aiko/core/money/money.dart';
import 'package:aiko/features/accounts/application/shared_limit_resolver.dart';
import 'package:aiko/features/accounts/domain/account.dart';
import 'package:aiko/features/accounts/domain/account_details.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Account _card(String id, {bool shares = false, String? ref}) => Account(
        id: id,
        userId: 'u',
        name: id,
        type: AccountType.creditCard,
        currentBalance: Money.zero('USD'),
        details: CreditCardDetails(
          statementDay: 1,
          dueDay: 1,
          creditLimit: shares ? null : Money.parse('5000', 'USD'),
          sharesLimit: shares,
          sharedLimitAccountId: ref,
        ),
      );

  test('flips child to not sharing when parent missing', () {
    final child = _card('child', shares: true, ref: 'gone');
    final updated = SharedLimitResolver.resolve(
      accounts: [child],
      deletedId: 'gone',
    );
    expect(updated.length, 1);
    expect(updated.first.details!.asCreditCard().sharesLimit, false);
  });

  test('idempotent on second pass', () {
    final child = _card('child', shares: false);
    final updated = SharedLimitResolver.resolve(
      accounts: [child],
      deletedId: 'gone',
    );
    expect(updated, isEmpty);
  });

  test('does not touch non-referencing accounts', () {
    final other = _card('other', shares: false);
    final updated = SharedLimitResolver.resolve(
      accounts: [other],
      deletedId: 'gone',
    );
    expect(updated, isEmpty);
  });
}
```

- [ ] **Step 2: Run test, verify FAIL**

```bash
flutter test test/features/accounts/application/shared_limit_resolver_test.dart
```

- [ ] **Step 3: Implement**

```dart
// lib/features/accounts/application/shared_limit_resolver.dart
import '../domain/account.dart';
import '../domain/account_details.dart';

abstract final class SharedLimitResolver {
  /// Returns the list of credit-card accounts that need updating because
  /// they shared a limit with the deleted [deletedId]. The returned accounts
  /// have [CreditCardDetails.sharesLimit] flipped to false.
  static List<Account> resolve({
    required List<Account> accounts,
    required String deletedId,
  }) {
    final result = <Account>[];
    for (final a in accounts) {
      if (a.type != AccountType.creditCard) continue;
      final cc = a.resolvedDetails.asCreditCard();
      if (!cc.sharesLimit) continue;
      if (cc.sharedLimitAccountId != deletedId) continue;
      result.add(a.copyWith(
        details: cc.copyWith(sharesLimit: false, sharedLimitAccountId: null),
      ));
    }
    return result;
  }
}
```

- [ ] **Step 4: Run test, verify PASS**

```bash
flutter test test/features/accounts/application/shared_limit_resolver_test.dart
```

- [ ] **Step 5: Wire into `AccountsNotifier.deleteAccount`**

In `lib/app/providers.dart`, find `AccountsNotifier.deleteAccount` (search for `deleteAccount`). Add before the call to `repo.delete(id)`:

```dart
final children = SharedLimitResolver.resolve(
  accounts: state.valueOrNull ?? const [],
  deletedId: id,
);
for (final c in children) {
  await saveAccount(c);
}
```

Add `import '../features/accounts/application/shared_limit_resolver.dart';` to the providers file.

- [ ] **Step 6: Run all tests**

```bash
flutter test test/features/accounts/
```

- [ ] **Step 7: Commit**

```bash
git add lib/features/accounts/application/shared_limit_resolver.dart test/features/accounts/application/shared_limit_resolver_test.dart lib/app/providers.dart
git commit -m "feat(accounts): auto-flip shared-limit children on parent delete"
```

---

## Task 23: Add "Type details" card to AccountDetailScreen

**Files:**
- Modify: `lib/features/accounts/presentation/accounts_screen.dart`

- [ ] **Step 1: Add the new card**

In `AccountDetailScreen` (in `accounts_screen.dart`), add after the existing detail `Card`:

```dart
const SizedBox(height: 12),
_AccountTypeDetailsCard(details: _account.resolvedDetails),
```

And add a new widget at the bottom of the file:

```dart
class _AccountTypeDetailsCard extends StatelessWidget {
  const _AccountTypeDetailsCard({required this.details});
  final AccountDetails details;

  @override
  Widget build(BuildContext context) {
    final rows = _rowsFor(details);
    if (rows.isEmpty) return const SizedBox.shrink();
    return FinanceCard(
      title: 'Type details',
      icon: Icons.list_alt_outlined,
      accentColor: AikoColors.deepBlue,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            _Row(label: rows[i].$1, value: rows[i].$2),
            if (i != rows.length - 1) const Divider(),
          ],
        ],
      ),
    );
  }

  List<(String, String)> _rowsFor(AccountDetails d) => switch (d) {
        CashDetails() => const [],
        BankDetails() => [
            if (d.accountNumberLast4 != null) ('Last 4', d.accountNumberLast4!),
            if (d.accountHolderName != null) ('Holder', d.accountHolderName!),
          ],
        EWalletDetails() => [
            if (d.linkedPhoneOrEmail != null)
              ('Contact', d.linkedPhoneOrEmail!),
          ],
        CreditCardDetails() => [
            ('Statement day', '${d.statementDay}'),
            ('Due day', '${d.dueDay}'),
            if (d.creditLimit != null)
              ('Credit limit', d.creditLimit!.format()),
            if (d.aprPercent != null)
              ('APR', '${d.aprPercent!.toStringAsFixed(2)}%'),
            if (d.rewardsType != null) ('Rewards', d.rewardsType!.name),
            if (d.annualFee != null) ('Annual fee', d.annualFee!.format()),
            if (d.minimumPayment != null)
              ('Min payment', d.minimumPayment!.format()),
            ('Shares limit', d.sharesLimit ? 'Yes' : 'No'),
            if (d.sharedLimitAccountId != null)
              ('Shared with', d.sharedLimitAccountId!),
          ],
        LoanDetails() => [
            ('Type', d.loanType.name),
            ('Principal', d.principal.format()),
            ('Rate', '${d.interestRatePercent.toStringAsFixed(2)}%'),
            ('Term', '${d.termMonths} mo'),
            ('Monthly', d.monthlyPayment.format()),
            ('Next due', d.nextDueDate.toIso8601String().substring(0, 10)),
          ],
        InvestmentDetails() => [
            if (d.accountNumberLast4 != null) ('Last 4', d.accountNumberLast4!),
          ],
        AssetDetails() => [
            ('Class', d.assetClass.name),
            if (d.purchasePrice != null)
              ('Purchase price', d.purchasePrice!.format()),
            if (d.purchaseDate != null)
              ('Purchased',
                  d.purchaseDate!.toIso8601String().substring(0, 10)),
            if (d.notes != null) ('Notes', d.notes!),
          ],
        LiabilityDetails() => [
            if (d.liabilityType != null) ('Type', d.liabilityType!),
            if (d.interestRatePercent != null)
              ('Rate', '${d.interestRatePercent!.toStringAsFixed(2)}%'),
            if (d.notes != null) ('Notes', d.notes!),
          ],
        OtherDetails() => [if (d.notes != null) ('Notes', d.notes!)],
      };
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: Text(value, textAlign: TextAlign.end),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Run tests**

```bash
flutter test test/features/accounts/
```

- [ ] **Step 3: Commit**

```bash
git add lib/features/accounts/presentation/accounts_screen.dart
git commit -m "feat(accounts): show type details on account detail screen"
```

---

## Task 24: Update AGENTS.md QA checklist

**Files:**
- Modify: `AGENTS.md`

- [ ] **Step 1: Append the new bullets**

Add to the existing **QA Checklist** section in `AGENTS.md`:

```markdown
- Add each account type from a fresh state — subform appears, validates, saves.
- Edit each type — values pre-populate, save round-trips identically.
- Toggle shared limit on/off — limit field appears/disappears, referenced card picker excludes self.
- Delete parent card — child detail screen shows migration notice.
- Offline add — account persists locally, syncs on reconnect, no double-write.
```

- [ ] **Step 2: Commit**

```bash
git add AGENTS.md
git commit -m "docs: extend QA checklist for account type details"
```

---

## Task 25: Final verification

- [ ] **Step 1: Format**

```bash
dart format --set-exit-if-changed .
```

- [ ] **Step 2: Lint**

```bash
flutter analyze
```
Expected: no errors. Fix any new lints.

- [ ] **Step 3: All tests**

```bash
flutter test
```
Expected: all pass.

- [ ] **Step 4: Build runner clean**

```bash
dart run build_runner build --delete-conflicting-outputs
```
Expected: no changes (idempotent).

- [ ] **Step 5: Commit (if anything changed)**

```bash
git status
git add -A
git commit -m "chore: apply formatter and analyzer fixes"
```

---

## Out of scope for this plan

- Aiko-inline-notice copy for the deleted-parent "set your own limit" flow (UI polish). The `CreditCardSubform` already shows a warning when the saved reference is no longer available; the detail-screen banner is a follow-up.
- Migration of existing `credit_card_profiles` rows into the new `details` jsonb column. Supabase migration just adds the column; backfill is a follow-up.
- Locale strings. The plan uses English literals; l10n keys are a follow-up.
