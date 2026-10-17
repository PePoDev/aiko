import 'package:decimal/decimal.dart';

import '../../../core/money/money.dart';
import '../domain/allocation_target.dart';
import '../domain/investment_holding.dart';

class AllocationService {
  const AllocationService();

  /// Allocation of [holdings] (all in one currency). [leftOut] are holdings
  /// that could not be converted (no exchange rate), listed so the screen can
  /// say so; [ratesAsOf] is when saved rates were used.
  PortfolioAllocation build(
    List<InvestmentHolding> holdings, {
    List<InvestmentHolding> leftOut = const [],
    DateTime? ratesAsOf,
  }) {
    final currency = holdings.isNotEmpty ? holdings.first.currency : 'USD';

    final byClass = <String, Decimal>{};
    var total = Decimal.zero;
    for (final holding in holdings) {
      final value = holding.marketValue.amount;
      total += value;
      final label = holding.assetClass.isEmpty ? 'Other' : holding.assetClass;
      byClass[label] = (byClass[label] ?? Decimal.zero) + value;
    }

    final totalDouble = total.toDouble();
    final slices =
        byClass.entries
            .map(
              (entry) => AllocationSlice(
                assetClass: entry.key,
                value: Money(amount: entry.value, currency: currency),
                percent: totalDouble == 0
                    ? 0
                    : entry.value.toDouble() / totalDouble * 100,
              ),
            )
            .toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    return PortfolioAllocation(
      total: Money(amount: total, currency: currency),
      holdingCount: holdings.length,
      slices: slices,
      leftOut: leftOut,
      ratesAsOf: ratesAsOf,
    );
  }

  double allocationPercent(
    InvestmentHolding holding,
    List<InvestmentHolding> portfolio,
  ) {
    final total = portfolio.fold<double>(
      0,
      (sum, item) => sum + item.marketValue.amount.toDouble(),
    );
    if (total == 0) {
      return 0;
    }
    return holding.marketValue.amount.toDouble() / total * 100;
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
    required Decimal quantitySold,
    required Money salePrice,
  }) {
    if (quantitySold <= Decimal.zero || quantitySold > holding.quantity) {
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
      (sum, item) => sum + item.marketValue.amount.toDouble(),
    );
    if (total == 0) {
      return 0;
    }
    final classTotal = holdings.fold<double>(
      0,
      (sum, item) => sum + item.marketValue.amount.toDouble(),
    );
    return classTotal / total * 100;
  }
}

class AllocationSlice {
  const AllocationSlice({
    required this.assetClass,
    required this.value,
    required this.percent,
  });

  final String assetClass;
  final Money value;
  final double percent;
}

class PortfolioAllocation {
  const PortfolioAllocation({
    required this.total,
    required this.holdingCount,
    required this.slices,
    this.leftOut = const [],
    this.ratesAsOf,
  });

  final Money total;

  /// Holdings counted in [total] and [slices].
  final int holdingCount;

  /// Allocation by asset class, largest first.
  final List<AllocationSlice> slices;

  /// Holdings left out because no exchange rate was available for them.
  final List<InvestmentHolding> leftOut;

  /// When holdings were converted with the rates saved on the device, the
  /// time those were fetched.
  final DateTime? ratesAsOf;

  /// Whether there are holdings at all, counted or left out.
  bool get hasHoldings => holdingCount > 0 || leftOut.isNotEmpty;
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
