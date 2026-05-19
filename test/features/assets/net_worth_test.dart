import 'package:aiko/core/money/money.dart';
import 'package:aiko/features/assets/application/net_worth_service.dart';
import 'package:aiko/features/assets/domain/asset.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('net worth subtracts liabilities from assets', () {
    final total = const NetWorthService().calculate([
      Asset(
        name: 'Cash',
        assetClass: AssetClass.cash,
        value: Money.parse('1000', 'USD'),
      ),
      Asset(
        name: 'Loan',
        assetClass: AssetClass.other,
        value: Money.parse('400', 'USD'),
        isLiability: true,
      ),
    ], 'USD');

    expect(total.amount.toString(), '600');
  });
}
