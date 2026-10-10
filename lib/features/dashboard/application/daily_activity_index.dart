import '../../transactions/domain/transaction.dart';

/// Integer key for a calendar date (`yyyymmdd`), so transactions can be
/// bucketed by day without building a `DateTime` for each one.
int dayKey(int year, int month, int day) => year * 10000 + month * 100 + day;

/// Income and expense totals per calendar day, built in one pass over the
/// ledger. Charts then look days up instead of rescanning every transaction
/// for every day they draw.
class DailyActivityIndex {
  DailyActivityIndex._(this._income, this._expense);

  /// Buckets [transactions] by date. Only `income` and `expense` count, as in
  /// the Daily summary chart (other types are transfers, investments and so
  /// on).
  factory DailyActivityIndex.build(List<FinanceTransaction> transactions) {
    final income = <int, double>{};
    final expense = <int, double>{};
    for (final tx in transactions) {
      final bucket = switch (tx.type) {
        TransactionType.income => income,
        TransactionType.expense => expense,
        _ => null,
      };
      if (bucket == null) continue;
      final date = tx.date;
      final key = dayKey(date.year, date.month, date.day);
      bucket[key] = (bucket[key] ?? 0) + tx.amount.amount.toDouble();
    }
    return DailyActivityIndex._(income, expense);
  }

  final Map<int, double> _income;
  final Map<int, double> _expense;

  double incomeOn(DateTime day) =>
      _income[dayKey(day.year, day.month, day.day)] ?? 0;

  double expenseOn(DateTime day) =>
      _expense[dayKey(day.year, day.month, day.day)] ?? 0;

  /// Average daily expense over the [dayCount] days ending on [endDay]
  /// (inclusive).
  double averageDailyExpense(DateTime endDay, int dayCount) {
    if (dayCount <= 0) return 0;
    var total = 0.0;
    for (var offset = 0; offset < dayCount; offset++) {
      // Calendar arithmetic (not Duration) so daylight-saving changes can't
      // skip or repeat a day.
      total += expenseOn(
        DateTime(endDay.year, endDay.month, endDay.day - offset),
      );
    }
    return total / dayCount;
  }
}
