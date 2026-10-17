import 'package:flutter/foundation.dart';

import '../../../core/money/money.dart';
import '../../../core/offline/offline_store.dart';
import '../../../core/offline/offline_user_context.dart';
import '../../../core/offline/records/records.dart';
import '../../categories/domain/category_defaults.dart';
import '../domain/transaction.dart';

class TransactionRepository {
  const TransactionRepository({
    OfflineStore? store,
    OfflineUserContext? userContext,
  }) : _storeOverride = store,
       _userContextOverride = userContext;

  final OfflineStore? _storeOverride;
  final OfflineUserContext? _userContextOverride;

  OfflineStore get _store => _storeOverride ?? OfflineStore();
  OfflineUserContext get _userContext =>
      _userContextOverride ?? OfflineUserContext();

  Future<List<FinanceTransaction>> list() async {
    final userId = await _userContext.resolveUserId();
    final transactions = await _store.get<OfflineTransaction>(
      query: RecordQuery(ownerId: userId, orderBy: 'date', descending: true),
    );

    if (kDebugMode) {
      debugPrint(
        '[aiko-sync] store returned ${transactions.length} '
        'transactions for userId=$userId',
      );
    }

    return transactions
        .map((transaction) => transaction.toDomain())
        .map((transaction) => _normalizeCategory(transaction, userId))
        .toList(growable: false);
  }

  /// Validates and saves [transaction] for the current user. With a [batch],
  /// the write is staged there for the caller to commit instead.
  Future<FinanceTransaction> save(
    FinanceTransaction transaction, {
    RecordBatch? batch,
  }) async {
    _validate(transaction);

    final userId = await _userContext.resolveUserId();
    final normalized = _normalizeCategory(transaction, userId);
    final record = normalized.toOffline(userId: userId);
    if (batch != null) {
      batch.upsert(record);
    } else {
      await _store.upsert(record);
    }
    return record.toDomain();
  }

  /// Deletes the current user's transaction [id]. With a [batch], the delete
  /// is staged there for the caller to commit instead.
  Future<void> delete(String id, {RecordBatch? batch}) async {
    final userId = await _userContext.resolveUserId();
    final target = batch ?? RecordBatch();
    target.deleteById<OfflineTransaction>(id, ownerId: userId);
    if (batch == null) await _store.commit(target);
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
      isRecurring: original.isRecurring,
      recurringFrequency: original.recurringFrequency,
      recurringSettings: original.recurringSettings,
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

  FinanceTransaction _normalizeCategory(
    FinanceTransaction transaction,
    String userId,
  ) {
    if (userId.startsWith(OfflineUserContext.localUserIdPrefix)) {
      return transaction;
    }
    final categoryId = CategoryDefaults.categoryIdForUser(
      userId: userId,
      categoryId: transaction.categoryId,
    );
    return categoryId == transaction.categoryId
        ? transaction
        : transaction.copyWith(categoryId: categoryId);
  }
}
