import '../../../core/money/money.dart';

class DashboardSummary {
  const DashboardSummary({
    required this.netWorth,
    required this.totalCash,
    required this.monthlyIncome,
    required this.monthlySpending,
    required this.safeToSpend,
    required this.paceStatus,
  });

  final Money netWorth;
  final Money totalCash;
  final Money monthlyIncome;
  final Money monthlySpending;
  final Money safeToSpend;
  final PaceStatus paceStatus;
}

class PaceStatus {
  const PaceStatus({
    required this.percentOfBudgetUsed,
    required this.daysElapsedRatio,
  });

  final double percentOfBudgetUsed;
  final double daysElapsedRatio;

  bool get isFast => percentOfBudgetUsed > daysElapsedRatio * 100;
}

class LeftoverSummary {
  const LeftoverSummary({required this.safeToSpend});

  final Money safeToSpend;
}
