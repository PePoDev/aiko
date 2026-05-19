import 'package:decimal/decimal.dart';

import '../../../core/money/money.dart';
import '../domain/allocation_target.dart';
import '../domain/investment_holding.dart';

class PortfolioAllocationService {
  const PortfolioAllocationService();

  Money marketValue(InvestmentHolding holding) {
    return holding.currentPrice.times(Decimal.parse('${holding.quantity}'));
  }

  double allocationPercent(
    InvestmentHolding holding,
    List<InvestmentHolding> portfolio,
  ) {
    final total = portfolio.fold<double>(
      0,
      (sum, item) => sum + marketValue(item).amount.toDouble(),
    );
    if (total == 0) {
      return 0;
    }
    return marketValue(holding).amount.toDouble() / total * 100;
  }

  bool isDrifted({
    required InvestmentHolding holding,
    required List<InvestmentHolding> portfolio,
    required AllocationTarget target,
    double tolerancePercent = 5,
  }) {
    final actual = allocationPercent(holding, portfolio);
    return (actual - target.targetPercent).abs() > tolerancePercent;
  }
}
