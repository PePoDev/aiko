enum DailySpendingReaction {
  comfortable,
  caution,
  exceeded,

  /// Nothing is safe to spend today, but nothing has been spent either.
  idle,

  /// No income is logged this month, so there is no safe amount to measure
  /// against yet.
  needsIncome;

  static DailySpendingReaction fromRatio(double ratio) {
    if (ratio >= 1) return DailySpendingReaction.exceeded;
    if (ratio >= 0.75) return DailySpendingReaction.caution;
    return DailySpendingReaction.comfortable;
  }
}

/// Aiko's reaction to today's spending and how full the Daily spending gauge
/// is (0 to 1 and beyond; 1 means today's safe amount is used up).
typedef DailySpendingAssessment = ({
  DailySpendingReaction reaction,
  double ratio,
});

/// Measures [spentToday] against [dailySafe] (weekly safe-to-spend ÷ 7).
///
/// With nothing safe to spend (`dailySafe ≤ 0`) there is no ratio: without
/// income logged this month Aiko asks for it ([DailySpendingReaction.
/// needsIncome]); otherwise any spending today exceeds the safe amount and no
/// spending is [DailySpendingReaction.idle].
DailySpendingAssessment assessDailySpending({
  required double spentToday,
  required double dailySafe,
  required bool hasIncomeThisMonth,
}) {
  if (dailySafe > 0) {
    final ratio = spentToday / dailySafe;
    return (reaction: DailySpendingReaction.fromRatio(ratio), ratio: ratio);
  }
  if (!hasIncomeThisMonth) {
    return (reaction: DailySpendingReaction.needsIncome, ratio: 0);
  }
  if (spentToday > 0) {
    return (reaction: DailySpendingReaction.exceeded, ratio: 1);
  }
  return (reaction: DailySpendingReaction.idle, ratio: 0);
}
