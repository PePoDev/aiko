import 'package:aiko/core/money/money.dart';
import 'package:aiko/features/assets/application/net_worth_service.dart';
import 'package:aiko/features/assets/domain/asset.dart';
import 'package:aiko/features/tax_center/application/tax_center_service.dart';
import 'package:aiko/features/tax_center/domain/tax_record.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('portfolio allocation and tax review flow', (tester) async {
    final netWorth = const NetWorthService().calculate([
      Asset(
        name: 'Cash',
        assetClass: AssetClass.cash,
        value: Money.parse('500', 'USD'),
      ),
    ], 'USD');
    final deductible = const TaxCenterService().deductibleTotal([
      TaxRecord(
        taxYear: 2026,
        amount: Money.parse('50', 'USD'),
        deductionType: 'business',
      ),
    ], 'USD');

    expect(netWorth.amount.toString(), '500');
    expect(deductible.amount.toString(), '50');
  });
}
