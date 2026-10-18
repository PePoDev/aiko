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
  const CashFlowService();

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
