import 'package:decimal/decimal.dart';

import '../../../core/money/money.dart';
import '../../categories/domain/category.dart';
import '../../transactions/domain/transaction.dart';

/// Transaction types that bring money into the household. Transfers between the
/// user's own accounts are intentionally excluded — they net to zero and would
/// distort cash flow.
const _inflowTypes = {
  TransactionType.income,
  TransactionType.refund,
  TransactionType.dividend,
  TransactionType.interest,
  TransactionType.investmentSell,
};

const _outflowTypes = {
  TransactionType.expense,
  TransactionType.investmentBuy,
  TransactionType.loanPayment,
  TransactionType.creditCardPayment,
  TransactionType.taxPayment,
  TransactionType.fee,
};

class CashFlowOverview {
  const CashFlowOverview({
    required this.income,
    required this.expenses,
    required this.net,
    required this.monthlyNet,
  });

  final Money income;
  final Money expenses;
  final Money net;

  /// Net cash flow per month, oldest first, for the trend bar chart.
  final List<double> monthlyNet;

  bool get hasActivity => !income.isZero || !expenses.isZero;
}

class CashFlowGroupSlice {
  const CashFlowGroupSlice({required this.group, required this.amount});
  final CategoryBudgetGroup group;
  final Money amount;
}

class CashFlowSankey {
  const CashFlowSankey({required this.income, required this.outflowByGroup});
  final Money income;

  /// Outflows bucketed by the spending category's [CategoryBudgetGroup],
  /// largest first.
  final List<CashFlowGroupSlice> outflowByGroup;

  bool get hasActivity => !income.isZero || outflowByGroup.isNotEmpty;
}

/// Derives cash-flow views from real transactions. Pure function object.
class CashFlowService {
  const CashFlowService({this.trendMonths = 12});

  final int trendMonths;

  CashFlowOverview overview({
    required List<FinanceTransaction> transactions,
    required DateTime asOf,
  }) {
    final currency = _currency(transactions);
    final start = DateTime(asOf.year, asOf.month);
    final end = DateTime(asOf.year, asOf.month + 1, 0, 23, 59, 59, 999);

    var income = Decimal.zero;
    var expenses = Decimal.zero;
    for (final t in transactions) {
      if (t.date.isBefore(start) || t.date.isAfter(end)) continue;
      if (t.type == TransactionType.income) income += t.amount.amount;
      if (t.type == TransactionType.expense) expenses += t.amount.amount;
    }

    final monthlyNet = <double>[];
    for (var i = trendMonths - 1; i >= 0; i--) {
      final mStart = DateTime(asOf.year, asOf.month - i);
      final mEnd = DateTime(asOf.year, asOf.month - i + 1, 0, 23, 59, 59, 999);
      var net = Decimal.zero;
      for (final t in transactions) {
        if (t.date.isBefore(mStart) || t.date.isAfter(mEnd)) continue;
        if (_inflowTypes.contains(t.type)) net += t.amount.amount;
        if (_outflowTypes.contains(t.type)) net -= t.amount.amount;
      }
      monthlyNet.add(net.toDouble());
    }

    return CashFlowOverview(
      income: Money(amount: income, currency: currency),
      expenses: Money(amount: expenses, currency: currency),
      net: Money(amount: income - expenses, currency: currency),
      monthlyNet: monthlyNet,
    );
  }

  CashFlowSankey sankey({
    required List<FinanceTransaction> transactions,
    required List<Category> categories,
    required DateTime asOf,
  }) {
    final currency = _currency(transactions);
    final start = DateTime(asOf.year, asOf.month);
    final end = DateTime(asOf.year, asOf.month + 1, 0, 23, 59, 59, 999);
    final groupOf = {for (final c in categories) c.id: c.group};

    var income = Decimal.zero;
    final byGroup = <CategoryBudgetGroup, Decimal>{};
    for (final t in transactions) {
      if (t.date.isBefore(start) || t.date.isAfter(end)) continue;
      if (_inflowTypes.contains(t.type)) {
        income += t.amount.amount;
      } else if (_outflowTypes.contains(t.type)) {
        final group = groupOf[t.categoryId] ?? CategoryBudgetGroup.custom;
        byGroup[group] = (byGroup[group] ?? Decimal.zero) + t.amount.amount;
      }
    }

    final slices =
        byGroup.entries
            .map(
              (e) => CashFlowGroupSlice(
                group: e.key,
                amount: Money(amount: e.value, currency: currency),
              ),
            )
            .toList()
          ..sort((a, b) => b.amount.compareTo(a.amount));

    return CashFlowSankey(
      income: Money(amount: income, currency: currency),
      outflowByGroup: slices,
    );
  }

  static String _currency(List<FinanceTransaction> transactions) {
    for (final t in transactions) {
      if (t.amount.currency.isNotEmpty) return t.amount.currency;
    }
    return 'USD';
  }
}
