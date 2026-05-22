import 'package:aiko/core/money/money.dart';
import 'package:aiko/features/portfolio/application/portfolio_allocation_service.dart';
import 'package:aiko/features/portfolio/domain/allocation_target.dart';
import 'package:aiko/features/portfolio/domain/investment_holding.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('estimates capital gains for partial sale', () {
    final estimate = const PortfolioAllocationService().capitalGainsOnSale(
      holding: InvestmentHolding(
        symbol: 'ABC',
        assetClass: 'Stocks',
        quantity: 10,
        averageCost: Money.parse('5', 'USD'),
        currentPrice: Money.parse('8', 'USD'),
      ),
      quantitySold: 2,
      salePrice: Money.parse('9', 'USD'),
    );

    expect(estimate.proceeds.amount.toString(), '18');
    expect(estimate.costBasis.amount.toString(), '10');
    expect(estimate.gainLoss.amount.toString(), '8');
  });

  test('returns rebalance alerts when allocations drift', () {
    final service = const PortfolioAllocationService();
    final holdings = [
      InvestmentHolding(
        symbol: 'ABC',
        assetClass: 'Stocks',
        quantity: 10,
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

    expect(alerts.single.direction, 'overweight');
  });
}
