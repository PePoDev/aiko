import 'package:aiko/core/money/money.dart';
import 'package:aiko/features/investments/domain/investment_holding.dart';
import 'package:aiko/features/investments/application/allocation_service.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = AllocationService();

  InvestmentHolding holding(
    String symbol,
    String assetClass,
    String price,
    String qty,
  ) => InvestmentHolding(
    id: symbol,
    symbol: symbol,
    assetClass: assetClass,
    quantity: Decimal.parse(qty),
    averageCost: Money.parse('1', 'USD'),
    currentPrice: Money.parse(price, 'USD'),
  );

  test('aggregates market value by asset class with percentages', () {
    final allocation = service.build([
      holding('AAPL', 'Stocks', '100', '6'), // 600
      holding('VOO', 'Stocks', '100', '2'), // 200 -> Stocks 800
      holding('BND', 'Bonds', '100', '2'), // 200
    ], baseCurrency: 'USD');

    expect(allocation.total, Money.parse('1000', 'USD'));
    expect(allocation.holdingCount, 3);
    expect(allocation.slices.first.assetClass, 'Stocks');
    expect(allocation.slices.first.value, Money.parse('800', 'USD'));
    expect(allocation.slices.first.percent, closeTo(80, 0.001));
    expect(allocation.slices.last.percent, closeTo(20, 0.001));
  });

  test('empty portfolio reports no holdings', () {
    final allocation = service.build([], baseCurrency: 'thb');
    expect(allocation.hasHoldings, isFalse);
    expect(allocation.nothingCounted, isFalse);
    expect(allocation.total, Money.zero('THB'));
    expect(allocation.slices, isEmpty);
  });

  test('every holding left out: nothing counted, base-currency total', () {
    final allocation = service.build(
      [],
      baseCurrency: 'THB',
      leftOut: [holding('AAPL', 'Stocks', '100', '1')],
    );
    expect(allocation.hasHoldings, isTrue);
    expect(allocation.nothingCounted, isTrue);
    expect(allocation.total, Money.zero('THB'));
  });
}
