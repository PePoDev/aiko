import 'package:aiko/brick/offline_model_mappers.dart';
import 'package:aiko/core/money/money.dart';
import 'package:aiko/features/accounts/domain/account_details.dart';
import 'package:aiko/features/assets/domain/asset.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('round-trips every variant', () {
    final samples = <AccountDetails>[
      const CashDetails(),
      const BankDetails(),
      const EWalletDetails(),
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
      const AssetDetails(assetClass: AssetClass.realEstate, notes: 'condo'),
      const LiabilityDetails(liabilityType: 'overdraft'),
      const OtherDetails(notes: 'misc'),
    ];
    for (final s in samples) {
      final json = accountDetailsToJson(s);
      final restored = accountDetailsFromJson(json);
      expect(
        restored,
        equals(s),
        reason: 'round-trip failed for ${s.variantName}',
      );
    }
  });

  test('unknown variant returns CashDetails', () {
    final restored = accountDetailsFromJson({'_type': 'mystery'});
    expect(restored, isA<CashDetails>());
  });

  test('null json returns CashDetails', () {
    expect(accountDetailsFromJson(null), isA<CashDetails>());
  });
}
