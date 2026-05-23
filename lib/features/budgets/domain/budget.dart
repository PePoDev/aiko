import '../../../core/money/money.dart';

enum BudgetPeriod { daily, monthly, weekly, yearly, custom }

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
    this.includedCategoryIds = const [],
    this.isAppDefined = false,
  });

  static const dailySpendingId = 'app-defined-daily-spending';
  static const dailySpendingCategoryId = 'app-defined-daily-spending';

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
  final List<String> includedCategoryIds;
  final bool isAppDefined;

  bool get isDailySpending =>
      id == dailySpendingId || (isAppDefined && name == 'Daily Spending');
  bool get canDelete => !isAppDefined;

  bool includesCategory(String? transactionCategoryId) {
    if (transactionCategoryId == null) {
      return false;
    }
    if (includedCategoryIds.isNotEmpty) {
      return includedCategoryIds.contains(transactionCategoryId);
    }
    return categoryId == transactionCategoryId;
  }

  Budget copyWith({
    String? name,
    String? categoryId,
    Money? amount,
    DateTime? periodStart,
    DateTime? periodEnd,
    BudgetPeriod? period,
    List<int>? alertThresholds,
    BudgetStatus? status,
    List<String>? includedCategoryIds,
    bool? isAppDefined,
  }) {
    return Budget(
      id: id,
      userId: userId,
      name: name ?? this.name,
      categoryId: categoryId ?? this.categoryId,
      amount: amount ?? this.amount,
      periodStart: periodStart ?? this.periodStart,
      periodEnd: periodEnd ?? this.periodEnd,
      period: period ?? this.period,
      alertThresholds: alertThresholds ?? this.alertThresholds,
      status: status ?? this.status,
      includedCategoryIds: includedCategoryIds ?? this.includedCategoryIds,
      isAppDefined: isAppDefined ?? this.isAppDefined,
    );
  }
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
