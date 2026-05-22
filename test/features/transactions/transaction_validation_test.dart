import 'package:aiko/core/money/money.dart';
import 'package:aiko/features/transactions/data/transaction_repository.dart';
import 'package:aiko/features/transactions/domain/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('transaction repository rejects non-positive expense', () async {
    const repository = TransactionRepository();

    await expectLater(
      repository.save(
        FinanceTransaction(
          id: 'bad',
          userId: 'user',
          accountId: 'cash',
          type: TransactionType.expense,
          amount: Money.zero('USD'),
          date: DateTime(2026),
        ),
      ),
      throwsArgumentError,
    );
  });

  test('split total must equal transaction amount', () async {
    const repository = TransactionRepository();

    await expectLater(
      repository.save(
        FinanceTransaction(
          id: 'split',
          userId: 'user',
          accountId: 'cash',
          type: TransactionType.expense,
          amount: Money.parse('10', 'USD'),
          date: DateTime(2026),
          splits: [
            TransactionSplit(
              categoryId: 'food',
              amount: Money.parse('8', 'USD'),
            ),
          ],
        ),
      ),
      throwsArgumentError,
    );
  });
}
