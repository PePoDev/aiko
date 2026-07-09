import '../../../core/money/money.dart';
import '../../categories/domain/category.dart';
import '../../transactions/domain/transaction.dart';

/// Result of computing spend vs. a [Category]'s budget over a period.
class CategoryBudgetProgress {
  const CategoryBudgetProgress({required this.category, required this.used});

  final Category category;
  final Money used;

  Money? get limit => category.monthlyLimit;
  Money? get remaining {
    final limit = this.limit;
    if (limit == null) return null;
    final diff = limit - used;
    if (diff.amount <= Money.zero(diff.currency).amount) {
      return Money.zero(diff.currency);
    }
    return diff;
  }

  /// 0..1 (or >1 if over-budget).
  double get ratio {
    final limit = this.limit;
    if (limit == null || limit.amount <= Money.zero(limit.currency).amount) {
      return 0;
    }
    final r = used.amount.toDouble() / limit.amount.toDouble();
    if (r.isNaN || r.isInfinite) return 0;
    return r.clamp(0.0, double.infinity).toDouble();
  }

  bool get isOverBudget {
    final limit = this.limit;
    if (limit == null) return false;
    return used.amount > limit.amount;
  }

  /// True when one of the configured alert thresholds (0..100) has been
  /// crossed by [ratio].
  bool get crossesAlertThreshold {
    final thresholds = category.alertThresholds;
    if (thresholds.isEmpty) return false;
    final percent = ratio * 100;
    return thresholds.any((t) => percent >= t);
  }
}

/// Operates on categories directly so the dashboard and detail screens can
/// derive budget progress from the current budget fields.
class CategoryBudgetProgressService {
  const CategoryBudgetProgressService();

  /// Computes spend for [category] across [transactions] for the
  /// [periodStart, periodEnd] window. The window is inclusive on both ends.
  CategoryBudgetProgress progressFor(
    Category category,
    List<FinanceTransaction> transactions, {
    DateTime? periodStart,
    DateTime? periodEnd,
  }) {
    final start = periodStart ?? _defaultStart(category);
    final end = periodEnd ?? _defaultEnd(category);
    final used = _sumExpenses(transactions, category, start, end);
    return CategoryBudgetProgress(category: category, used: used);
  }

  /// A warm tone message. Non-judgmental (per AGENTS.md brand voice).
  String recommendation(CategoryBudgetProgress progress, int daysLeft) {
    if (!progress.category.hasBudget) {
      return 'No budget set for this category yet.';
    }
    if (progress.isOverBudget) {
      return 'You are above target. Let us adjust together for the next period.';
    }
    final limit = progress.limit;
    final remaining = progress.remaining;
    if (limit == null || remaining == null || daysLeft <= 0) {
      return 'Stay mindful of this category for the rest of the period.';
    }
    final daily = remaining.amount.toDouble() / daysLeft.clamp(1, 31);
    return 'Keep this category under ${daily.toStringAsFixed(0)} ${limit.currency}/day to stay on track.';
  }

  DateTime _defaultStart(Category category) {
    final now = DateTime.now();
    return switch (category.budgetPeriod) {
      CategoryBudgetPeriod.daily => DateTime(now.year, now.month, now.day),
      CategoryBudgetPeriod.weekly => now.subtract(
        Duration(days: now.weekday - 1),
      ),
      CategoryBudgetPeriod.monthly => DateTime(now.year, now.month),
      CategoryBudgetPeriod.yearly => DateTime(now.year),
    };
  }

  DateTime _defaultEnd(Category category) {
    final now = DateTime.now();
    return switch (category.budgetPeriod) {
      CategoryBudgetPeriod.daily => DateTime(
        now.year,
        now.month,
        now.day,
        23,
        59,
        59,
      ),
      CategoryBudgetPeriod.weekly => now.add(
        Duration(days: DateTime.daysPerWeek - now.weekday),
      ),
      CategoryBudgetPeriod.monthly => DateTime(now.year, now.month + 1, 0),
      CategoryBudgetPeriod.yearly => DateTime(
        now.year + 1,
        1,
        1,
      ).subtract(const Duration(seconds: 1)),
    };
  }

  Money _sumExpenses(
    List<FinanceTransaction> transactions,
    Category category,
    DateTime start,
    DateTime end,
  ) {
    final categoryId = category.id;
    // ponytail: sum only the budget's currency; no FX rates here to convert.
    // Add currency conversion when Travel Mode rates reach this path.
    final target =
        category.monthlyLimit?.currency ??
        _defaultCurrency(transactions, categoryId);
    Money running = Money.zero(target);
    for (final t in transactions) {
      if (t.type != TransactionType.expense) continue;
      if (t.categoryId != categoryId) continue;
      if (t.status != TransactionStatus.posted) continue;
      if (t.amount.currency != target) continue;
      if (t.date.isBefore(start) || t.date.isAfter(end)) continue;
      running += t.amount;
    }
    return running;
  }

  String _defaultCurrency(
    List<FinanceTransaction> transactions,
    String categoryId,
  ) {
    for (final t in transactions) {
      if (t.categoryId == categoryId) return t.amount.currency;
    }
    return 'USD';
  }
}
