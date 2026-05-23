import '../../../core/money/money.dart';
import '../../../brick/offline_model_mappers.dart';
import '../../../brick/repository.dart';
import '../../../brick/models/transaction.model.dart';
import '../../../core/offline/offline_store.dart';
import '../../../core/offline/offline_user_context.dart';
import '../domain/transaction.dart';

class TransactionRepository {
  const TransactionRepository();

  Future<List<FinanceTransaction>> list() async {
    final userId = await OfflineUserContext().resolveUserId();
    final transactions = await OfflineStore().get<OfflineTransaction>(
      query: Query(
        where: [Where.exact('userId', userId)],
        orderBy: const [OrderBy.desc('date')],
      ),
    );

    return transactions
        .map((transaction) => transaction.toDomain())
        .toList(growable: false);
  }

  Future<FinanceTransaction> save(FinanceTransaction transaction) async {
    _validate(transaction);

    final userId = await OfflineUserContext().resolveUserId();
    final saved = await OfflineStore().upsert(
      transaction.toOffline(userId: userId),
    );
    return saved.toDomain();
  }

  Future<List<FinanceTransaction>> search(String query) async {
    final currentList = await list();
    final lower = query.toLowerCase();
    return currentList
        .where(
          (item) =>
              (item.merchant ?? '').toLowerCase().contains(lower) ||
              (item.categoryId ?? '').toLowerCase().contains(lower),
        )
        .toList(growable: false);
  }

  Future<FinanceTransaction> duplicate(String id, String newId) async {
    final currentList = await list();
    final original = currentList.firstWhere((item) => item.id == id);
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
    return save(copy);
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
