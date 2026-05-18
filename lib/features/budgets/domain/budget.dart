import '../../../core/money/money.dart';

enum BudgetPeriod { monthly, weekly, yearly, custom }

enum BudgetStatus { active, paused, archived }

class Budget {
  const Budget({
    required this.id,
    required this.userId,
    required this.name,
    required this.categoryId,
    required this.amount,
    required this.periodStart,
    required this.periodEnd,
    this.period = BudgetPeriod.monthly,
    this.alertThresholds = const [50, 75, 90, 100],
    this.status = BudgetStatus.active,
  });

  final String id;
  final String userId;
  final String name;
  final String categoryId;
  final Money amount;
  final DateTime periodStart;
  final DateTime periodEnd;
  final BudgetPeriod period;
  final List<int> alertThresholds;
  final BudgetStatus status;
}

class BudgetProgress {
  const BudgetProgress({required this.budget, required this.used});

  final Budget budget;
  final Money used;

  Money get remaining => budget.amount - used;

  double get percentUsed {
    if (budget.amount.amount == Money.zero(budget.amount.currency).amount) {
      return 0;
    }
    return used.amount.toDouble() / budget.amount.amount.toDouble() * 100;
  }

  bool get isOverBudget => percentUsed >= 100;
}
