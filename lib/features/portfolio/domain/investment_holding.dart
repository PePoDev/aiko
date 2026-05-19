import '../../../core/money/money.dart';

class InvestmentHolding {
  const InvestmentHolding({
    required this.symbol,
    required this.assetClass,
    required this.quantity,
    required this.averageCost,
    required this.currentPrice,
  });

  final String symbol;
  final String assetClass;
  final double quantity;
  final Money averageCost;
  final Money currentPrice;

  Money get marketValue => currentPrice.times(
    // Quantity is intentionally decimal-friendly for fractional shares.
    decimalFromDouble(quantity),
  );

  Money get unrealizedGainLoss =>
      marketValue - averageCost.times(decimalFromDouble(quantity));
}

dynamic decimalFromDouble(double value) =>
    throw UnsupportedError('Use PortfolioAllocationService.marketValue.');
