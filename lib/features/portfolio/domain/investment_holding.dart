import '../../../core/money/money.dart';
import 'package:decimal/decimal.dart';

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

  Money get marketValue => currentPrice.times(Decimal.parse('$quantity'));

  Money get unrealizedGainLoss =>
      marketValue - averageCost.times(Decimal.parse('$quantity'));
}
