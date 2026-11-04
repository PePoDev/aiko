import 'package:aiko/core/money/money.dart';
import 'package:aiko/features/transactions/application/duplicate_detection.dart';
import 'package:aiko/features/transactions/domain/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  FinanceTransaction tx(
    String id, {
    String amount = '120',
    DateTime? date,
    String account = 'cash',
    TransactionType type = TransactionType.expense,
    String? merchant = 'Coffee Shop',
    String? categoryId = 'coffee',
    TransactionStatus status = TransactionStatus.posted,
  }) => FinanceTransaction(
    id: id,
    userId: 'u',
    accountId: account,
    type: type,
    amount: Money.parse(amount, 'THB'),
    date: date ?? DateTime(2026, 10, 19, 9),
    merchant: merchant,
    categoryId: categoryId,
    status: status,
  );

  test('a same-amount entry for the same item a day apart is a duplicate', () {
    final saved = tx('a', date: DateTime(2026, 10, 18, 22));
    final candidate = tx('new', merchant: ' coffee shop ', categoryId: null);
    expect(findLikelyDuplicate(candidate, [saved])?.id, 'a');
  });

  test('the same category matches when the item name differs or is empty', () {
    final saved = tx('a', merchant: 'Cafe');
    expect(findLikelyDuplicate(tx('new', merchant: null), [saved])?.id, 'a');
  });

  test('a different amount, account, type or date is not a duplicate', () {
    final candidate = tx('new');
    expect(findLikelyDuplicate(candidate, [tx('a', amount: '121')]), isNull);
    expect(findLikelyDuplicate(candidate, [tx('a', account: 'bank')]), isNull);
    expect(
      findLikelyDuplicate(candidate, [tx('a', type: TransactionType.income)]),
      isNull,
    );
    expect(
      findLikelyDuplicate(candidate, [
        tx('a', date: DateTime(2026, 10, 17, 23)),
      ]),
      isNull,
    );
  });

  test('neither the same item nor the same category is not a duplicate', () {
    final saved = tx('a', merchant: 'Bakery', categoryId: 'food');
    expect(findLikelyDuplicate(tx('new'), [saved]), isNull);
  });

  test('voided, archived and the entry itself are ignored', () {
    final candidate = tx('a');
    expect(
      findLikelyDuplicate(candidate, [
        tx('v', status: TransactionStatus.voided),
        tx('x', status: TransactionStatus.archived),
        tx('a'),
      ]),
      isNull,
    );
  });
}
