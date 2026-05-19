import 'package:aiko/core/money/money.dart';
import 'package:aiko/features/portfolio/application/portfolio_allocation_service.dart';
import 'package:aiko/features/portfolio/domain/allocation_target.dart';
import 'package:aiko/features/portfolio/domain/investment_holding.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('detects allocation drift', () {
    final holdings = [
      InvestmentHolding(
        symbol: 'AAA',
        assetClass: 'stocks',
        quantity: 10,
        averageCost: Money.parse('8', 'USD'),
        currentPrice: Money.parse('10', 'USD'),
      ),
      InvestmentHolding(
        symbol: 'BBB',
        assetClass: 'bonds',
        quantity: 10,
        averageCost: Money.parse('10', 'USD'),
        currentPrice: Money.parse('10', 'USD'),
      ),
    ];

    expect(
      const PortfolioAllocationService().isDrifted(
        holding: holdings.first,
        portfolio: holdings,
        target: const AllocationTarget(assetClass: 'stocks', targetPercent: 40),
      ),
      isTrue,
    );
  });
}
