import 'package:aiko/core/money/money.dart';
import 'package:aiko/features/dashboard/application/daily_activity_index.dart';
import 'package:aiko/features/transactions/domain/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  var seq = 0;
  FinanceTransaction tx(TransactionType type, String amount, DateTime date) =>
      FinanceTransaction(
        id: 't${seq++}',
        userId: 'u',
        accountId: 'a',
        type: type,
        amount: Money.parse(amount, 'THB'),
        date: date,
      );

  final ledger = [
    tx(TransactionType.expense, '100', DateTime(2026, 3, 10, 8)),
    tx(TransactionType.expense, '50.5', DateTime(2026, 3, 10, 23, 59)),
    tx(TransactionType.income, '1000', DateTime(2026, 3, 10, 12)),
    tx(TransactionType.expense, '30', DateTime(2026, 3, 9)),
    tx(TransactionType.expense, '70', DateTime(2026, 2, 28)),
    tx(TransactionType.transferOut, '999', DateTime(2026, 3, 10)),
    tx(TransactionType.fee, '999', DateTime(2026, 3, 10)),
  ];

  test('dayKey is yyyymmdd', () {
    expect(dayKey(2026, 3, 9), 20260309);
    expect(dayKey(2025, 12, 31), 20251231);
  });

  test('buckets income and expense by calendar day, any time of day', () {
    final index = DailyActivityIndex.build(ledger);
    expect(index.expenseOn(DateTime(2026, 3, 10)), closeTo(150.5, 1e-9));
    expect(index.incomeOn(DateTime(2026, 3, 10)), 1000);
    expect(index.expenseOn(DateTime(2026, 3, 9)), 30);
    expect(index.expenseOn(DateTime(2026, 3, 11)), 0);
    // Only income and expense count, as in the Daily summary chart.
    expect(index.incomeOn(DateTime(2026, 3, 9)), 0);
  });

  test('average daily expense covers the days ending on the given day', () {
    final index = DailyActivityIndex.build(ledger);
    // 10 Mar back to 1 Mar: 150.5 + 30 over 10 days.
    expect(
      index.averageDailyExpense(DateTime(2026, 3, 10), 10),
      closeTo(18.05, 1e-9),
    );
    // Crosses into February: 28 Feb – 10 Mar is 11 days.
    expect(
      index.averageDailyExpense(DateTime(2026, 3, 10), 11),
      closeTo((150.5 + 30 + 70) / 11, 1e-9),
    );
    expect(index.averageDailyExpense(DateTime(2026, 3, 10), 0), 0);
  });

  test('matches a per-day rescan of the ledger', () {
    final index = DailyActivityIndex.build(ledger);
    for (var d = 0; d < 20; d++) {
      final day = DateTime(2026, 2, 20 + d);
      double rescan(TransactionType type) => ledger
          .where(
            (t) =>
                t.type == type &&
                t.date.year == day.year &&
                t.date.month == day.month &&
                t.date.day == day.day,
          )
          .fold(0.0, (sum, t) => sum + t.amount.amount.toDouble());
      expect(index.expenseOn(day), rescan(TransactionType.expense));
      expect(index.incomeOn(day), rescan(TransactionType.income));
    }
  });
}
