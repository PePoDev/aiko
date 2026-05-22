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

  List<RebalanceAlert> rebalanceAlerts({
    required List<InvestmentHolding> portfolio,
    required List<AllocationTarget> targets,
    double tolerancePercent = 5,
  }) {
    final alerts = <RebalanceAlert>[];
    for (final target in targets) {
      final holdings = portfolio
          .where((holding) => holding.assetClass == target.assetClass)
          .toList(growable: false);
      final actual = _assetClassPercent(holdings, portfolio);
      final drift = actual - target.targetPercent;
      if (drift.abs() > tolerancePercent) {
        alerts.add(
          RebalanceAlert(
            assetClass: target.assetClass,
            targetPercent: target.targetPercent,
            actualPercent: actual,
            driftPercent: drift,
          ),
        );
      }
    }
    return alerts;
  }

  CapitalGainsEstimate capitalGainsOnSale({
    required InvestmentHolding holding,
    required double quantitySold,
    required Money salePrice,
  }) {
    if (quantitySold <= 0 || quantitySold > holding.quantity) {
      throw ArgumentError('Quantity sold must be within the holding quantity.');
    }
    final quantity = Decimal.parse('$quantitySold');
    final proceeds = salePrice.times(quantity);
    final costBasis = holding.averageCost.times(quantity);
    return CapitalGainsEstimate(
      symbol: holding.symbol,
      proceeds: proceeds,
      costBasis: costBasis,
      gainLoss: proceeds - costBasis,
    );
  }

  double _assetClassPercent(
    List<InvestmentHolding> holdings,
    List<InvestmentHolding> portfolio,
  ) {
    final total = portfolio.fold<double>(
      0,
      (sum, item) => sum + marketValue(item).amount.toDouble(),
    );
    if (total == 0) {
      return 0;
    }
    final classTotal = holdings.fold<double>(
      0,
      (sum, item) => sum + marketValue(item).amount.toDouble(),
    );
    return classTotal / total * 100;
  }
}

class RebalanceAlert {
  const RebalanceAlert({
    required this.assetClass,
    required this.targetPercent,
    required this.actualPercent,
    required this.driftPercent,
  });

  final String assetClass;
  final double targetPercent;
  final double actualPercent;
  final double driftPercent;

  String get direction => driftPercent > 0 ? 'overweight' : 'underweight';
}

class CapitalGainsEstimate {
  const CapitalGainsEstimate({
    required this.symbol,
    required this.proceeds,
    required this.costBasis,
    required this.gainLoss,
  });

  final String symbol;
  final Money proceeds;
  final Money costBasis;
  final Money gainLoss;
}
