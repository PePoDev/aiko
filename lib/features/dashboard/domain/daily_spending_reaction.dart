enum DailySpendingReaction {
  comfortable,
  caution,
  exceeded;

  static DailySpendingReaction fromRatio(double ratio) {
    if (ratio >= 1) return DailySpendingReaction.exceeded;
    if (ratio >= 0.75) return DailySpendingReaction.caution;
    return DailySpendingReaction.comfortable;
  }
}
