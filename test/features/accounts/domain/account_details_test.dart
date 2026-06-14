import 'package:aiko/core/money/money.dart';
import 'package:aiko/features/accounts/domain/account_details.dart';
import 'package:aiko/features/accounts/domain/account_type.dart';
import 'package:aiko/features/assets/domain/asset.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every AccountType maps to a non-null default', () {
    for (final type in AccountType.values) {
      expect(
        AccountDetails.defaultFor(type),
        isNotNull,
        reason: 'Missing default for $type',
      );
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
