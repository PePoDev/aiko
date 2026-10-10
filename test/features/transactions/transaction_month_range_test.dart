import 'package:aiko/core/money/money.dart';
import 'package:aiko/features/transactions/application/transaction_month_range.dart';
import 'package:aiko/features/transactions/domain/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

FinanceTransaction _transaction(String id, DateTime date) {
  return FinanceTransaction(
    id: id,
    userId: 'user',
    accountId: 'account',
    type: TransactionType.expense,
    amount: Money.parse('10', 'USD'),
    date: date,
  );
}

void main() {
  const service = TransactionMonthRangeService();
  final currentDate = DateTime(2026, 7, 15);

  test('empty history includes current month and twelve future months', () {
    final months = service.monthsFor(
      transactions: const <FinanceTransaction>[],
      currentDate: currentDate,
    );

    expect(months, hasLength(13));
    expect(months.first, const TransactionMonth(2026, 7));
    expect(months.last, const TransactionMonth(2027, 7));
  });

  test('history starts at the oldest saved transaction month', () {
    final months = service.monthsFor(
      transactions: [
        _transaction('newer', DateTime(2026, 5, 20)),
        _transaction('oldest', DateTime(2024, 3, 8)),
      ],
      currentDate: currentDate,
    );

    expect(months.first, const TransactionMonth(2024, 3));
    expect(months.last, const TransactionMonth(2027, 7));
    expect(months, contains(const TransactionMonth(2026, 7)));
    expect(months, hasLength(41));
  });

  test('future-only data still starts at the current month', () {
    final months = service.monthsFor(
      transactions: [_transaction('future', DateTime(2027, 1, 3))],
      currentDate: currentDate,
    );

    expect(months.first, const TransactionMonth(2026, 7));
    expect(months.last, const TransactionMonth(2027, 7));
  });

  test('saved transaction beyond one year extends the future boundary', () {
    final months = service.monthsFor(
      transactions: [_transaction('far-future', DateTime(2028, 9, 2))],
      currentDate: currentDate,
    );

    expect(months.first, const TransactionMonth(2026, 7));
    expect(months.last, const TransactionMonth(2028, 9));
    for (var index = 1; index < months.length; index++) {
      expect(months[index], months[index - 1].addMonths(1));
    }
  });

  test('month arithmetic crosses year boundaries in both directions', () {
    expect(
      const TransactionMonth(2026, 12).addMonths(1),
      const TransactionMonth(2027, 1),
    );
    expect(
      const TransactionMonth(2027, 1).addMonths(-1),
      const TransactionMonth(2026, 12),
    );
  });

  test('month query value round-trips YYYY-MM', () {
    const month = TransactionMonth(2026, 3);
    expect(month.queryValue, '2026-03');
    expect(TransactionMonth.tryParseQuery('2026-03'), month);
  });

  test('malformed month queries are ignored', () {
    expect(TransactionMonth.tryParseQuery(null), isNull);
    expect(TransactionMonth.tryParseQuery(''), isNull);
    expect(TransactionMonth.tryParseQuery('2026-13'), isNull);
    expect(TransactionMonth.tryParseQuery('2026-3'), isNull);
    expect(TransactionMonth.tryParseQuery('March'), isNull);
  });
}
