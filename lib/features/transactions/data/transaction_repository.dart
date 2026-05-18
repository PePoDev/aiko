import '../../../core/money/money.dart';
import '../domain/transaction.dart';

class TransactionRepository {
  TransactionRepository({List<FinanceTransaction>? transactions})
    : _transactions =
          transactions ??
          [
            FinanceTransaction(
              id: 'coffee',
              userId: 'demo-user',
              accountId: 'cash',
              type: TransactionType.expense,
              amount: Money.parse('4.50', 'USD'),
              date: DateTime(2026, 5, 18),
              categoryId: 'food',
              merchant: 'Coffee Shop',
            ),
          ];

  final List<FinanceTransaction> _transactions;

  Future<List<FinanceTransaction>> list() async =>
      List.unmodifiable(_transactions);

  Future<FinanceTransaction> save(FinanceTransaction transaction) async {
    _validate(transaction);
    final index = _transactions.indexWhere((item) => item.id == transaction.id);
    if (index == -1) {
      _transactions.add(transaction);
    } else {
      _transactions[index] = transaction;
    }
    return transaction;
  }

  Future<List<FinanceTransaction>> search(String query) async {
    final lower = query.toLowerCase();
    return _transactions
        .where(
          (item) =>
              (item.merchant ?? '').toLowerCase().contains(lower) ||
              (item.categoryId ?? '').toLowerCase().contains(lower),
        )
        .toList(growable: false);
  }

  Future<FinanceTransaction> duplicate(String id, String newId) async {
    final original = _transactions.firstWhere((item) => item.id == id);
    final copy = FinanceTransaction(
      id: newId,
      userId: original.userId,
      accountId: original.accountId,
      type: original.type,
      amount: original.amount,
      date: DateTime.now(),
      categoryId: original.categoryId,
      merchant: original.merchant,
      note: original.note,
      tags: original.tags,
      splits: original.splits,
    );
    _transactions.add(copy);
    return copy;
  }

  void _validate(FinanceTransaction transaction) {
    if (transaction.amount.amount <=
            Money.zero(transaction.amount.currency).amount &&
        transaction.type != TransactionType.adjustment) {
      throw ArgumentError('Transaction amount must be positive.');
    }
    if (transaction.splits.isNotEmpty) {
      final total = transaction.splits
          .map((split) => split.amount)
          .reduce((value, element) => value + element);
      if (total != transaction.amount) {
        throw ArgumentError('Split total must equal transaction amount.');
      }
    }
  }
}
