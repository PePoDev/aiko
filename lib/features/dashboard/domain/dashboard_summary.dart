import '../../../core/money/money.dart';

class DashboardSummary {
  const DashboardSummary({
    required this.netWorth,
    required this.totalCash,
    required this.monthlyIncome,
    required this.monthlySpending,
    required this.safeToSpend,
  });

  final Money netWorth;
  final Money totalCash;
  final Money monthlyIncome;
  final Money monthlySpending;
  final Money safeToSpend;
}
