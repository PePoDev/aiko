import 'package:decimal/decimal.dart';
import 'package:flutter/widgets.dart';

import '../../../core/money/money.dart';
import '../../../l10n/app_localizations.dart';
import '../../categories/domain/category.dart';
import '../../categories/presentation/category_names.dart';
import '../../transactions/domain/transaction.dart';
import '../domain/monthly_report.dart';

/// Builds the Monthly Report from real transactions — no mock data. Pure
/// function object: give it the user's transactions + categories and the month
/// to report on, get back aggregated figures.
class MonthlyReportService {
  const MonthlyReportService({this.maxSlices = 5});

  /// How many category slices to show before folding the rest into "Other".
  final int maxSlices;

  /// Slice names use [l10n]'s language (English when omitted).
  MonthlyReport build({
    required List<FinanceTransaction> transactions,
    required List<Category> categories,
    required DateTime asOf,
    AppLocalizations? l10n,
  }) {
    final strings = l10n ?? lookupAppLocalizations(const Locale('en'));
    final currency = _currency(transactions, categories);
    final thisMonth = _DateRange.ofMonth(asOf.year, asOf.month);
    final lastMonth = _DateRange.ofMonth(asOf.year, asOf.month - 1);

    final current = _totals(transactions, thisMonth, currency);
    final previous = _totals(transactions, lastMonth, currency);

    final net = current.income - current.expenses;
    final lastNet = previous.income - previous.expenses;
    final saved = net.isPositive ? net : Money.zero(currency);

    return MonthlyReport(
      income: current.income,
      expenses: current.expenses,
      netCashFlow: net,
      saved: saved,
      savingsRatePct: current.income.isPositive
          ? saved.ratio(current.income) * 100
          : 0,
      incomeChangePct: _changePct(current.income, previous.income),
      expensesChangePct: _changePct(current.expenses, previous.expenses),
      netChangePct: _changePct(net, lastNet),
      savedVsLastMonth: net - lastNet,
      slices: _slices(transactions, thisMonth, categories, currency, strings),
    );
  }

  _Totals _totals(
    List<FinanceTransaction> transactions,
    _DateRange range,
    String currency,
  ) {
    var income = Decimal.zero;
    var expenses = Decimal.zero;
    for (final t in transactions) {
      if (!range.contains(t.date)) continue;
      if (t.type == TransactionType.income) {
        income += t.amount.amount;
      } else if (t.type == TransactionType.expense) {
        expenses += t.amount.amount;
      }
    }
    return _Totals(
      income: Money(amount: income, currency: currency),
      expenses: Money(amount: expenses, currency: currency),
    );
  }

  List<MonthlyReportSlice> _slices(
    List<FinanceTransaction> transactions,
    _DateRange range,
    List<Category> categories,
    String currency,
    AppLocalizations l10n,
  ) {
    final byCategory = <String?, Decimal>{};
    for (final t in transactions) {
      if (t.type != TransactionType.expense) continue;
      if (!range.contains(t.date)) continue;
      byCategory[t.categoryId] =
          (byCategory[t.categoryId] ?? Decimal.zero) + t.amount.amount;
    }
    if (byCategory.isEmpty) return const [];

    final lookup = {for (final c in categories) c.id: c};
    final entries = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final slices = <MonthlyReportSlice>[];
    var otherTotal = Decimal.zero;
    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      if (i >= maxSlices) {
        otherTotal += entry.value;
        continue;
      }
      final category = lookup[entry.key];
      slices.add(
        MonthlyReportSlice(
          name: category?.displayName(l10n) ?? l10n.uncategorized,
          colorHex: category?.color ?? '#778196',
          amount: Money(amount: entry.value, currency: currency),
        ),
      );
    }
    if (otherTotal > Decimal.zero) {
      slices.add(
        MonthlyReportSlice(
          name: l10n.reportOtherSlice,
          colorHex: '#778196',
          amount: Money(amount: otherTotal, currency: currency),
        ),
      );
    }
    return slices;
  }

  /// Percent change of [current] vs [previous]; null when there is no prior
  /// value to compare against (avoids a meaningless "+100%" or divide-by-zero).
  static double? _changePct(Money current, Money previous) {
    if (previous.amount == Decimal.zero) return null;
    return (current.amount - previous.amount).toDouble() /
        previous.amount.abs().toDouble() *
        100;
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

class _Totals {
  const _Totals({required this.income, required this.expenses});
  final Money income;
  final Money expenses;
}

class _DateRange {
  _DateRange(this.start, this.end);

  factory _DateRange.ofMonth(int year, int month) {
    final start = DateTime(year, month);
    final end = DateTime(year, month + 1, 0, 23, 59, 59, 999);
    return _DateRange(start, end);
  }

  final DateTime start;
  final DateTime end;

  bool contains(DateTime date) => !date.isBefore(start) && !date.isAfter(end);
}
