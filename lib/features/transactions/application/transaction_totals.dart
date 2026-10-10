import 'package:decimal/decimal.dart';

import '../../../core/money/money.dart';
import '../domain/transaction.dart';

/// Whether [transaction] counts toward income/spending totals. Transfer legs
/// only move money between the user's own accounts and adjustments correct a
/// balance, so neither is money earned or spent.
bool countsTowardNetTotal(FinanceTransaction transaction) =>
    !transaction.type.isTransfer &&
    transaction.type != TransactionType.adjustment;

/// Money in minus money out across [transactions] (see
/// [FinanceTransaction.isInflow]), skipping transfers and adjustments.
///
/// Totals use one currency: the first counted row's, or [fallbackCurrency]
/// when nothing counts. Rows in any other currency are left out (no rate to
/// convert with).
Money netTransactionTotal(
  Iterable<FinanceTransaction> transactions, {
  required String fallbackCurrency,
}) {
  String? currency;
  var total = Decimal.zero;
  for (final transaction in transactions) {
    if (!countsTowardNetTotal(transaction)) continue;
    currency ??= transaction.amount.currency;
    if (transaction.amount.currency != currency) continue;
    total += transaction.signedAmount.amount;
  }
  return Money(amount: total, currency: currency ?? fallbackCurrency);
}

/// [current] with [saved] inserted or replaced (matched by id), keeping the
/// list newest first like the repository returns it. Other rows keep their
/// order.
List<FinanceTransaction> upsertTransactionsByDate(
  List<FinanceTransaction> current,
  Iterable<FinanceTransaction> saved,
) {
  final savedIds = {for (final transaction in saved) transaction.id};
  final result = [
    for (final transaction in current)
      if (!savedIds.contains(transaction.id)) transaction,
  ];
  for (final transaction in saved) {
    var index = result.indexWhere(
      (other) => other.date.isBefore(transaction.date),
    );
    if (index == -1) index = result.length;
    result.insert(index, transaction);
  }
  return result;
}
