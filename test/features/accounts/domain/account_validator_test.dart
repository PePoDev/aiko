import 'package:aiko/core/money/money.dart';
import 'package:aiko/features/accounts/domain/account.dart';
import 'package:aiko/features/accounts/domain/account_details.dart';
import 'package:aiko/features/accounts/domain/account_type.dart';
import 'package:aiko/features/accounts/domain/account_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Account acct(AccountDetails d, {String currency = 'USD'}) => Account(
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
    expect(
      () => AccountValidator.validate(a, allAccounts: const []),
      returnsNormally,
    );
  });

  test('credit card missing limit and not sharing fails', () {
    const d = CreditCardDetails(statementDay: 1, dueDay: 1);
    expect(
      () => AccountValidator.validate(acct(d), allAccounts: const []),
      throwsA(isA<Exception>()),
    );
  });

  test('credit card with limit validates', () {
    final d = CreditCardDetails(
      statementDay: 1,
      dueDay: 1,
      creditLimit: Money.parse('5000', 'USD'),
    );
    expect(
      () => AccountValidator.validate(acct(d), allAccounts: const []),
      returnsNormally,
    );
  });

  test('credit card day out of range fails', () {
    final d = CreditCardDetails(
      statementDay: 0,
      dueDay: 1,
      creditLimit: Money.parse('5000', 'USD'),
    );
    expect(
      () => AccountValidator.validate(acct(d), allAccounts: const []),
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
      () => AccountValidator.validate(
        acct(d, currency: 'USD'),
        allAccounts: const [],
      ),
      throwsA(isA<Exception>()),
    );
  });

  test('credit card shares limit requires reference', () {
    const d = CreditCardDetails(statementDay: 1, dueDay: 1, sharesLimit: true);
    expect(
      () => AccountValidator.validate(acct(d), allAccounts: const []),
      throwsA(isA<Exception>()),
    );
  });

  test('credit card cannot share with self', () {
    const d = CreditCardDetails(
      statementDay: 1,
      dueDay: 1,
      sharesLimit: true,
      sharedLimitAccountId: 'a',
    );
    expect(
      () => AccountValidator.validate(acct(d), allAccounts: const []),
      throwsA(isA<Exception>()),
    );
  });

  test('credit card shared reference must exist', () {
    const d = CreditCardDetails(
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
      () => AccountValidator.validate(acct(d), allAccounts: [parent]),
      throwsA(isA<Exception>()),
    );
  });

  test('credit card shared reference OK with valid parent', () {
    const d = CreditCardDetails(
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
    expect(
      () => AccountValidator.validate(acct(d), allAccounts: [parent]),
      returnsNormally,
    );
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
      () => AccountValidator.validate(acct(d), allAccounts: const []),
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
    expect(
      () => AccountValidator.validate(acct(d), allAccounts: const []),
      returnsNormally,
    );
  });
}
