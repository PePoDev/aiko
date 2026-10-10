import 'package:aiko/core/money/money.dart';
import 'package:aiko/features/transactions/application/transaction_totals.dart';
import 'package:aiko/features/transactions/domain/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

FinanceTransaction _tx(
  TransactionType type,
  String amount, {
  String id = 'tx',
  String currency = 'THB',
  DateTime? date,
}) => FinanceTransaction(
  id: id,
  userId: 'user',
  accountId: 'acct',
  type: type,
  amount: Money.parse(amount, currency),
  date: date ?? DateTime(2026, 10, 1),
);

void main() {
  group('netTransactionTotal', () {
    test('a 1,000 transfer between own accounts nets to zero', () {
      final total = netTransactionTotal([
        _tx(TransactionType.transferOut, '1000', id: 'out'),
        _tx(TransactionType.transferIn, '1000', id: 'in'),
      ], fallbackCurrency: 'THB');
      expect(total, Money.zero('THB'));
    });

    test('income minus spending, ignoring transfers and adjustments', () {
      final total = netTransactionTotal([
        _tx(TransactionType.income, '30000', id: 'salary'),
        _tx(TransactionType.expense, '1200', id: 'food'),
        _tx(TransactionType.refund, '200', id: 'refund'),
        _tx(TransactionType.fee, '50', id: 'fee'),
        _tx(TransactionType.transferOut, '5000', id: 'out'),
        _tx(TransactionType.adjustment, '10000', id: 'opening'),
      ], fallbackCurrency: 'THB');
      expect(total, Money.parse('28950', 'THB'));
    });

    test('a spending-only day is negative', () {
      final total = netTransactionTotal([
        _tx(TransactionType.expense, '80'),
      ], fallbackCurrency: 'THB');
      expect(total, Money.parse('-80', 'THB'));
    });

    test('uses the first counted currency and skips others', () {
      final total = netTransactionTotal([
        _tx(TransactionType.transferIn, '10', currency: 'USD', id: 'in'),
        _tx(TransactionType.expense, '100', id: 'thb'),
        _tx(TransactionType.expense, '5', currency: 'USD', id: 'usd'),
      ], fallbackCurrency: 'EUR');
      expect(total, Money.parse('-100', 'THB'));
    });

    test('falls back to the given currency when nothing counts', () {
      expect(
        netTransactionTotal(const [], fallbackCurrency: 'THB'),
        Money.zero('THB'),
      );
      expect(
        netTransactionTotal([
          _tx(TransactionType.adjustment, '500'),
        ], fallbackCurrency: 'JPY'),
        Money.zero('JPY'),
      );
    });
  });

  group('upsertTransactionsByDate', () {
    final newest = _tx(
      TransactionType.expense,
      '1',
      id: 'a',
      date: DateTime(2026, 10, 9),
    );
    final middle = _tx(
      TransactionType.expense,
      '2',
      id: 'b',
      date: DateTime(2026, 10, 5),
    );
    final oldest = _tx(
      TransactionType.expense,
      '3',
      id: 'c',
      date: DateTime(2026, 10, 1),
    );

    test('inserts a new row in date-descending position', () {
      final added = _tx(
        TransactionType.expense,
        '4',
        id: 'd',
        date: DateTime(2026, 10, 7),
      );
      final result = upsertTransactionsByDate(
        [newest, middle, oldest],
        [added],
      );
      expect(result.map((t) => t.id), ['a', 'd', 'b', 'c']);
    });

    test('replaces an edited row and moves it when its date changes', () {
      final edited = oldest.copyWith(date: DateTime(2026, 10, 10));
      final result = upsertTransactionsByDate(
        [newest, middle, oldest],
        [edited],
      );
      expect(result.map((t) => t.id), ['c', 'a', 'b']);
      expect(result.first.date, DateTime(2026, 10, 10));
    });

    test('adds both legs of a transfer and leaves the input untouched', () {
      final input = [newest, oldest];
      final result = upsertTransactionsByDate(input, [
        _tx(TransactionType.transferOut, '9', id: 'out', date: middle.date),
        _tx(TransactionType.transferIn, '9', id: 'in', date: middle.date),
      ]);
      expect(result.map((t) => t.id), ['a', 'out', 'in', 'c']);
      expect(input.map((t) => t.id), ['a', 'c']);
    });
  });
}
