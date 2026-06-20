import 'package:decimal/decimal.dart';

import '../../../core/money/money.dart';
import '../../investments/domain/investment_holding.dart';

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
  });

  final Money total;
  final int holdingCount;

  /// Allocation by asset class, largest first.
  final List<AllocationSlice> slices;

  bool get hasHoldings => holdingCount > 0;
}

/// Derives portfolio allocation from real investment holdings. Pure function
/// object.
class AllocationService {
  const AllocationService();

  PortfolioAllocation build(List<InvestmentHolding> holdings) {
    final currency = holdings.isNotEmpty ? holdings.first.currency : 'USD';

    final byClass = <String, Decimal>{};
    var total = Decimal.zero;
    for (final h in holdings) {
      final value = h.marketValue.amount;
      total += value;
      final label = h.assetClass.isEmpty ? 'Other' : h.assetClass;
      byClass[label] = (byClass[label] ?? Decimal.zero) + value;
    }

    final totalDouble = total.toDouble();
    final slices =
        byClass.entries
            .map(
              (e) => AllocationSlice(
                assetClass: e.key,
                value: Money(amount: e.value, currency: currency),
                percent: totalDouble == 0
                    ? 0
                    : e.value.toDouble() / totalDouble * 100,
              ),
            )
            .toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    return PortfolioAllocation(
      total: Money(amount: total, currency: currency),
      holdingCount: holdings.length,
      slices: slices,
    );
  }
}
