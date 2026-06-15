import 'package:flutter/foundation.dart';

import '../../brick/models/category.model.dart';
import '../../brick/models/transaction.model.dart';
import '../../brick/repository.dart';
import '../../features/categories/domain/category_defaults.dart';
import '../offline/offline_data_migrator.dart';
import '../offline/offline_store.dart';

/// Encapsulates the offline-data preparation that runs immediately after a
/// user signs in. Split out of `AuthRepository` so the auth layer
/// doesn't reach across into brick models, the queue, and the migrator.
///
/// Steps:
/// 1. Remap transactions whose `category_id` is a legacy `default-*` slug to
///    the corresponding fixed UUID from [CategoryDefaults.legacySlugToUuid].
/// 2. Delete stale `default-*` OfflineCategory rows that were never valid UUIDs
///    and therefore could never sync to Supabase (local-only — they never
///    existed remotely).
/// 3. Flush the offline queue entries whose body contains the old slugs so
///    those poisoned requests stop retrying.
/// 4. Reassign data created while signed out (`local:` prefix) to [userId].
class PostSigninDataPreparer {
  const PostSigninDataPreparer();

  Future<void> prepareForSync(String userId) async {
    try {
      final store = OfflineStore();

      await _remapLegacyCategoryTransactions(store, userId);
      await _deleteLegacyCategoryRows(store, userId);
      await _flushPoisonedQueueEntries();
      await OfflineDataMigrator().claimAnonymousData(userId);
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[aiko-sync] offline data prepare skipped: $error');
      }
    }
  }

  Future<void> _remapLegacyCategoryTransactions(
    OfflineStore store,
    String userId,
  ) async {
    final transactions = await store.get<OfflineTransaction>(
      query: Query(where: [Where.exact('userId', userId)]),
      policy: OfflineFirstGetPolicy.localOnly,
    );
    for (final tx in transactions) {
      final catId = tx.categoryId;
      if (catId == null || !catId.startsWith('default-')) continue;
      final newId = CategoryDefaults.legacySlugToUuid[catId];
      if (newId == null) continue;
      await store.upsert(
        OfflineTransaction(
          id: tx.id,
          userId: tx.userId,
          accountId: tx.accountId,
          type: tx.type,
          amount: tx.amount,
          currency: tx.currency,
          date: tx.date,
          categoryId: newId,
          merchant: tx.merchant,
          note: tx.note,
          tags: tx.tags,
          status: tx.status,
        ),
      );
      if (kDebugMode) {
        debugPrint('[aiko-sync] remapped tx ${tx.id} category $catId → $newId');
      }
    }
  }

  Future<void> _deleteLegacyCategoryRows(
    OfflineStore store,
    String userId,
  ) async {
    final legacyCategories = await store.get<OfflineCategory>(
      query: Query(where: [Where.exact('userId', userId)]),
      policy: OfflineFirstGetPolicy.localOnly,
    );
    for (final cat in legacyCategories) {
      if (!cat.id.startsWith('default-')) continue;
      await store.delete(cat, localOnly: true);
      if (kDebugMode) {
        debugPrint('[aiko-sync] deleted stale local category ${cat.id}');
      }
    }
  }

  Future<void> _flushPoisonedQueueEntries() async {
    final flushed = await AikoBrickRepository.flushQueueEntriesContaining(
      '%"default-%',
      urlPattern: '%default-%',
    );
    if (kDebugMode && flushed > 0) {
      debugPrint(
        '[aiko-sync] flushed $flushed stale queue entries with legacy category ids',
      );
    }
  }
}
