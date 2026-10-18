import 'package:aiko/core/money/money.dart';
import 'package:aiko/features/investments/application/allocation_service.dart';
import 'package:aiko/features/investments/domain/allocation_target.dart';
import 'package:aiko/features/investments/domain/investment_holding.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('estimates capital gains for partial sale', () {
    final estimate = const AllocationService().capitalGainsOnSale(
      holding: InvestmentHolding(
        id: 'test-1',
        symbol: 'ABC',
        assetClass: 'Stocks',
        quantity: Decimal.fromInt(10),
        averageCost: Money.parse('5', 'USD'),
        currentPrice: Money.parse('8', 'USD'),
      ),
      quantitySold: Decimal.fromInt(2),
      salePrice: Money.parse('9', 'USD'),
    );

    expect(estimate.proceeds.amount.toString(), '18');
    expect(estimate.costBasis.amount.toString(), '10');
    expect(estimate.gainLoss.amount.toString(), '8');
  });

  test('returns rebalance alerts when allocations drift', () {
    final service = const AllocationService();
    final holdings = [
      InvestmentHolding(
        id: 'test-2',
        symbol: 'ABC',
        assetClass: 'Stocks',
        quantity: Decimal.fromInt(10),
        averageCost: Money.parse('10', 'USD'),
        currentPrice: Money.parse('10', 'USD'),
      ),
    ];

    final alerts = service.rebalanceAlerts(
      portfolio: holdings,
      targets: const [
        AllocationTarget(assetClass: 'Stocks', targetPercent: 50),
      ],
    );

    expect(alerts.single.driftPercent, greaterThan(0)); // overweight
  });
}
