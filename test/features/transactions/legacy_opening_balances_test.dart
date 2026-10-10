import 'package:aiko/core/money/money.dart';
import 'package:aiko/features/transactions/application/legacy_opening_balances.dart';
import 'package:aiko/features/transactions/domain/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  FinanceTransaction tx(
    String id,
    TransactionType type,
    String amount, {
    String? merchant,
    String? note,
  }) => FinanceTransaction(
    id: id,
    userId: 'u',
    accountId: 'a',
    type: type,
    amount: Money.parse(amount, 'THB'),
    date: DateTime(2026, 5, 1),
    merchant: merchant,
    note: note,
  );

  test('opening-balance rows become signed adjustments', () {
    final fixes = legacyOpeningBalanceFixes([
      tx(
        'en',
        TransactionType.income,
        '50000',
        merchant: 'Initial balance',
        note: 'Created from account starting balance',
      ),
      tx(
        'th',
        TransactionType.expense,
        '20000',
        merchant: 'ยอดยกมา',
        note: 'สร้างจากยอดเงินเริ่มต้นของบัญชี',
      ),
      tx('coffee', TransactionType.expense, '80', merchant: 'Café'),
      tx(
        'renamed',
        TransactionType.income,
        '10',
        merchant: 'Initial balance',
        note: 'my own note',
      ),
    ]);

    expect(fixes.map((t) => t.id), ['en', 'th']);
    expect(fixes.every((t) => t.type == TransactionType.adjustment), isTrue);
    expect(fixes.first.amount, Money.parse('50000', 'THB'));
    expect(fixes.last.amount, Money.parse('-20000', 'THB'));
  });

  test('the balance effect is unchanged', () {
    final before = [
      tx(
        'en',
        TransactionType.expense,
        '300',
        merchant: 'Initial balance',
        note: 'Created from account starting balance',
      ),
    ];
    final after = legacyOpeningBalanceFixes(before);
    final zero = Money.zero('THB');
    expect(
      after.single.applyToAccountBalance(zero),
      before.single.applyToAccountBalance(zero),
    );
  });
}
