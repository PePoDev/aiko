import '../domain/optimization_suggestion.dart';

class AikoOptimizeService {
  const AikoOptimizeService();

  List<OptimizationSuggestion> rank(List<OptimizationSuggestion> suggestions) {
    final sorted = [...suggestions];
    sorted.sort((a, b) => b.score.compareTo(a.score));
    return sorted;
  }

  List<OptimizationSuggestion> generate({
    required double budgetUtilizationPercent,
    required double safeToSpendAmount,
    required int upcomingBillsCount,
    required int driftedAllocationsCount,
  }) {
    final suggestions = <OptimizationSuggestion>[];
    if (budgetUtilizationPercent >= 75) {
      suggestions.add(
        OptimizationSuggestion(
          title: 'Tighten flexible spending this week',
          score: budgetUtilizationPercent / 100,
          reason:
              'Budget usage is ${budgetUtilizationPercent.toStringAsFixed(0)}%, so small category limits can prevent overspend.',
          actionLabel: 'Review budgets',
          sourceData: const ['budgets', 'transactions'],
        ),
      );
    }
    if (safeToSpendAmount < 100) {
      suggestions.add(
        const OptimizationSuggestion(
          title: 'Protect your safe-to-spend cushion',
          score: 0.82,
          reason:
              'Safe-to-spend is low after bills, goals, and posted transactions.',
          actionLabel: 'View cash flow',
          sourceData: ['dashboard', 'bills', 'goals'],
        ),
      );
    }
    if (upcomingBillsCount > 0) {
      suggestions.add(
        OptimizationSuggestion(
          title: 'Review $upcomingBillsCount upcoming bill renewals',
          score: 0.7 + upcomingBillsCount.clamp(0, 3) * 0.05,
          reason: 'Upcoming renewals are good candidates for price checks.',
          actionLabel: 'Open subscriptions',
          sourceData: const ['bills', 'subscriptions'],
        ),
      );
    }
    if (driftedAllocationsCount > 0) {
      suggestions.add(
        OptimizationSuggestion(
          title: 'Rebalance $driftedAllocationsCount portfolio allocation',
          score: 0.76,
          reason: 'One or more asset classes are outside target tolerance.',
          actionLabel: 'Open portfolio',
          sourceData: const ['portfolio', 'allocation_targets'],
        ),
      );
    }
    return rank(suggestions);
  }
}
