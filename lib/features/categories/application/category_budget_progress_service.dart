import 'package:decimal/decimal.dart';

import '../../../core/money/money.dart';
import '../../../l10n/app_localizations.dart';
import '../../categories/domain/category.dart';
import '../../transactions/domain/transaction.dart';

/// The budget period that contains [asOf]: [start] inclusive, [end]
/// exclusive. Weeks start on Monday.
({DateTime start, DateTime end}) budgetPeriodWindow(
  CategoryBudgetPeriod period,
  DateTime asOf,
) {
  switch (period) {
    case CategoryBudgetPeriod.daily:
      return (
        start: DateTime(asOf.year, asOf.month, asOf.day),
        end: DateTime(asOf.year, asOf.month, asOf.day + 1),
      );
    case CategoryBudgetPeriod.weekly:
      final monday = asOf.day - (asOf.weekday - DateTime.monday);
      return (
        start: DateTime(asOf.year, asOf.month, monday),
        end: DateTime(asOf.year, asOf.month, monday + 7),
      );
    case CategoryBudgetPeriod.monthly:
      return (
        start: DateTime(asOf.year, asOf.month),
        end: DateTime(asOf.year, asOf.month + 1),
      );
    case CategoryBudgetPeriod.yearly:
      return (start: DateTime(asOf.year), end: DateTime(asOf.year + 1));
  }
}

/// Result of computing spend vs. a [Category]'s budget over a period.
class CategoryBudgetProgress {
  const CategoryBudgetProgress({
    required this.category,
    required this.used,
    this.carriedOver,
  });

  final Category category;
  final Money used;

  /// Unspent budget from the previous period, when the category rolls over
  /// unused budget; already included in [limit].
  final Money? carriedOver;

  /// The period's limit, plus [carriedOver].
  Money? get limit {
    final base = category.monthlyLimit;
    final carried = carriedOver;
    if (base == null || carried == null) return base;
    return Money(amount: base.amount + carried.amount, currency: base.currency);
  }

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

  /// Spend for [category] across [transactions] in its budget period at
  /// [asOf] (default now), or in an explicit window ([periodStart] to
  /// [periodEnd], both inclusive).
  ///
  /// With `rolloverUnused`, what was left of the previous period's limit is
  /// added to this period's limit (one period back; overspending doesn't
  /// reduce it). Nothing carries over into the category's first period.
  CategoryBudgetProgress progressFor(
    Category category,
    List<FinanceTransaction> transactions, {
    DateTime? asOf,
    DateTime? periodStart,
    DateTime? periodEnd,
  }) {
    final window = budgetPeriodWindow(
      category.budgetPeriod,
      asOf ?? DateTime.now(),
    );
    final start = periodStart ?? window.start;
    // Inclusive end for the sum below.
    final end =
        periodEnd ?? window.end.subtract(const Duration(microseconds: 1));
    final used = _sumExpenses(transactions, category, start, end);
    return CategoryBudgetProgress(
      category: category,
      used: used,
      carriedOver: periodStart == null && periodEnd == null
          ? _carriedOver(category, transactions, window.start)
          : null,
    );
  }

  Money? _carriedOver(
    Category category,
    List<FinanceTransaction> transactions,
    DateTime periodStart,
  ) {
    final limit = category.monthlyLimit;
    if (!category.rolloverUnused || !category.hasBudget || limit == null) {
      return null;
    }
    final createdAt = category.createdAt;
    final existedBefore = createdAt != null
        ? createdAt.isBefore(periodStart)
        : transactions.any(
            (t) => t.categoryId == category.id && t.date.isBefore(periodStart),
          );
    if (!existedBefore) return null;
    final previous = budgetPeriodWindow(
      category.budgetPeriod,
      periodStart.subtract(const Duration(days: 1)),
    );
    final spent = _sumExpenses(
      transactions,
      category,
      previous.start,
      previous.end.subtract(const Duration(microseconds: 1)),
    );
    final unused = limit.amount - spent.amount;
    if (unused <= Decimal.zero) return null;
    return Money(amount: unused, currency: limit.currency);
  }

  /// A warm tone message in [l10n]'s language. Non-judgmental (per
  /// AGENTS.md brand voice).
  String recommendation(
    CategoryBudgetProgress progress,
    int daysLeft,
    AppLocalizations l10n,
  ) {
    if (!progress.category.hasBudget) {
      return l10n.budgetAdviceNone;
    }
    if (progress.isOverBudget) {
      return l10n.budgetAdviceOver;
    }
    final limit = progress.limit;
    final remaining = progress.remaining;
    if (limit == null || remaining == null || daysLeft <= 0) {
      return l10n.budgetAdviceMindful;
    }
    final daily = remaining.amount.toDouble() / daysLeft.clamp(1, 31);
    return l10n.budgetAdviceDaily(daily.toStringAsFixed(0), limit.currency);
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
