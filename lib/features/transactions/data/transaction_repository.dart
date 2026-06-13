import 'package:flutter/foundation.dart';

import '../../../core/money/money.dart';
import '../../../brick/offline_model_mappers.dart';
import '../../../brick/repository.dart';
import '../../../brick/models/transaction.model.dart';
import '../../../core/offline/offline_store.dart';
import '../../../core/offline/offline_user_context.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../domain/transaction.dart';

class TransactionRepository {
  const TransactionRepository();

  Future<List<FinanceTransaction>> list() async {
    final userId = await OfflineUserContext().resolveUserId();
    await _debugDumpSyncState(userId);
    final transactions = await OfflineStore().get<OfflineTransaction>(
      query: Query(
        where: [Where.exact('userId', userId)],
        orderBy: const [OrderBy.desc('date')],
      ),
    );

    if (kDebugMode) {
      debugPrint(
        '[aiko-sync] store returned ${transactions.length} '
        'transactions for userId=$userId',
      );
    }

    return transactions
        .map((transaction) => transaction.toDomain())
        .toList(growable: false);
  }

  /// TEMPORARY diagnostic: compares the app's resolved user id with what is
  /// actually stored in Supabase. Remove once the sync issue is resolved.
  Future<void> _debugDumpSyncState(String userId) async {
    if (!kDebugMode) {
      return;
    }
    final store = OfflineStore();
    debugPrint(
      '[aiko-sync] resolvedUserId=$userId canSyncRemote=${store.canSyncRemote}',
    );
    final client = AikoSupabase.tryClient();
    if (client == null) {
      debugPrint(
        '[aiko-sync] Supabase client is null (offline/not configured)',
      );
      return;
    }
    debugPrint('[aiko-sync] authUser=${client.auth.currentUser?.id}');
    try {
      final rows = await client
          .from('transactions')
          .select('id,user_id,merchant,date');
      debugPrint('[aiko-sync] Supabase transactions visible=${rows.length}');
      final byUser = <String, int>{};
      for (final row in rows) {
        final uid = '${row['user_id']}';
        byUser[uid] = (byUser[uid] ?? 0) + 1;
      }
      debugPrint('[aiko-sync] Supabase rows grouped by user_id=$byUser');
      for (final row in rows.take(10)) {
        debugPrint(
          '[aiko-sync]   row user_id=${row['user_id']} '
          'merchant=${row['merchant']} date=${row['date']}',
        );
      }
    } catch (error) {
      debugPrint('[aiko-sync] Supabase transactions query failed: $error');
    }
  }

  Future<FinanceTransaction> save(FinanceTransaction transaction) async {
    _validate(transaction);

    final userId = await OfflineUserContext().resolveUserId();
    final saved = await OfflineStore().upsert(
      transaction.toOffline(userId: userId),
    );
    return saved.toDomain();
  }

  Future<void> delete(String id) async {
    final userId = await OfflineUserContext().resolveUserId();
    final transactions = await OfflineStore().get<OfflineTransaction>(
      query: Query(
        where: [Where.exact('userId', userId), Where.exact('id', id)],
        limit: 1,
      ),
    );

    if (transactions.isEmpty) {
      return;
    }

    await OfflineStore().delete(transactions.first);
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
}
