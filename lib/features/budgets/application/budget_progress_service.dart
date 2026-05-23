import '../../../core/money/money.dart';
import '../../transactions/domain/transaction.dart';
import '../domain/budget.dart';

class BudgetProgressService {
  const BudgetProgressService();

  BudgetProgress progressFor(
    Budget budget,
    List<FinanceTransaction> transactions,
  ) {
    final matching = transactions.where(
      (transaction) =>
          budget.includesCategory(transaction.categoryId) &&
          transaction.date.compareTo(budget.periodStart) >= 0 &&
          transaction.date.compareTo(budget.periodEnd) <= 0 &&
          transaction.type == TransactionType.expense,
    );
    final used = matching.fold<Money>(
      Money.zero(budget.amount.currency),
      (total, transaction) => total + transaction.amount,
    );
    return BudgetProgress(budget: budget, used: used);
  }

  String recommendation(BudgetProgress progress, int daysLeft) {
    if (progress.isOverBudget) {
      return 'You are above target. Let us adjust together for next month.';
    }
    final daily = progress.remaining.amount.toDouble() / daysLeft.clamp(1, 31);
    return 'Keep this category under ${daily.toStringAsFixed(0)} ${progress.budget.amount.currency}/day to stay on track.';
  }
}
