import 'package:decimal/decimal.dart';

import '../../../core/money/money.dart';
import '../../categories/domain/category.dart';
import '../../transactions/domain/transaction.dart';

class SafeToSpend {
  const SafeToSpend({
    required this.income,
    required this.spent,
    required this.reserved,
    required this.leftover,
    required this.daysRemaining,
  });

  final Money income;
  final Money spent;

  /// Budgeted-but-unspent money set aside for the rest of the month.
  final Money reserved;
  final Money leftover;
  final int daysRemaining;

  Money get perDay =>
      daysRemaining <= 0 ? leftover : leftover.dividedByInt(daysRemaining);
}

/// Budget pace + safe-to-spend, both derived from real transactions and the
/// budget limits that live on categories. Pure function object.
class BudgetInsightsService {
  const BudgetInsightsService();

  SafeToSpend safeToSpend({
    required List<FinanceTransaction> transactions,
    required List<Category> categories,
    required DateTime asOf,
  }) {
    final currency = _currency(transactions, categories);
    final spentByCategory = _spentByCategory(transactions, asOf);
    final start = DateTime(asOf.year, asOf.month);
    final end = DateTime(asOf.year, asOf.month + 1, 0, 23, 59, 59, 999);

    var income = Decimal.zero;
    var spent = Decimal.zero;
    for (final t in transactions) {
      if (t.date.isBefore(start) || t.date.isAfter(end)) continue;
      if (t.type == TransactionType.income) income += t.amount.amount;
      if (t.type == TransactionType.expense) spent += t.amount.amount;
    }

    // Money still earmarked by budgets the user hasn't spent yet.
    var reserved = Decimal.zero;
    for (final category in categories) {
      if (!category.hasBudget) continue;
      final remaining =
          category.monthlyLimit!.amount -
          (spentByCategory[category.id] ?? Decimal.zero);
      if (remaining > Decimal.zero) reserved += remaining;
    }

    final leftover = income - spent - reserved;
    final periodEnd = DateTime(asOf.year, asOf.month + 1, 0).day;

    return SafeToSpend(
      income: Money(amount: income, currency: currency),
      spent: Money(amount: spent, currency: currency),
      reserved: Money(amount: reserved, currency: currency),
      leftover: Money(amount: leftover, currency: currency),
      daysRemaining: (periodEnd - asOf.day) + 1,
    );
  }

  Map<String?, Decimal> _spentByCategory(
    List<FinanceTransaction> transactions,
    DateTime asOf,
  ) {
    final start = DateTime(asOf.year, asOf.month);
    final end = DateTime(asOf.year, asOf.month + 1, 0, 23, 59, 59, 999);
    final byCategory = <String?, Decimal>{};
    for (final t in transactions) {
      if (t.type != TransactionType.expense) continue;
      if (t.date.isBefore(start) || t.date.isAfter(end)) continue;
      byCategory[t.categoryId] =
          (byCategory[t.categoryId] ?? Decimal.zero) + t.amount.amount;
    }
    return byCategory;
  }

  static String _currency(
    List<FinanceTransaction> transactions,
    List<Category> categories,
  ) {
    for (final t in transactions) {
      if (t.amount.currency.isNotEmpty) return t.amount.currency;
    }
    for (final c in categories) {
      final limit = c.monthlyLimit;
      if (limit != null && limit.currency.isNotEmpty) return limit.currency;
    }
    return 'USD';
  }
}
