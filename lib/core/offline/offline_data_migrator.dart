import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../features/categories/domain/category_defaults.dart';
import '../../features/transactions/data/transaction_attachment_repository.dart';
import 'offline_store.dart';
import 'offline_user_context.dart';
import 'records/records.dart';

/// Reassigns rows that were created while signed out (under an anonymous
/// `local:<uuid>` user id) to the real Firebase user id after sign-in.
///
/// Without this, data captured before signing in is orphaned: every repository
/// query filters by the currently resolved user id, so once that id flips from
/// `local:<uuid>` to the real UUID the earlier rows silently disappear from the
/// UI even though they are still in the local database.
///
/// Each reclaimed row is re-upserted under the real user id. Signed in, rows go
/// to Firestore in batches of [OfflineStore.maxBatchWrites] (handed to the SDK,
/// which uploads them when online) and the local copies are deleted; a batch
/// the server rejects is put back locally so the next claim retries it.
/// Signed out, rows are updated in the local store in place.
///
/// Guest attachments are handed over too ([claimFiles]) and their uploads
/// queued.
class OfflineDataMigrator {
  OfflineDataMigrator({
    OfflineStore? store,
    Future<int> Function(String realUserId)? claimFiles,
  }) : _store = store ?? OfflineStore(),
       _claimFiles =
           claimFiles ??
           TransactionAttachmentRepository().claimGuestAttachments;

  final OfflineStore _store;
  final Future<int> Function(String realUserId) _claimFiles;

  /// Claims every locally-created row for [realUserId]. Returns the number of
  /// rows reassigned. Safe to call repeatedly: it is a no-op once nothing is
  /// orphaned, and it never throws (failures are logged in debug only).
  Future<int> claimAnonymousData(String realUserId) async {
    if (realUserId.isEmpty ||
        realUserId.startsWith(OfflineUserContext.localUserIdPrefix)) {
      return 0;
    }

    // Order matters: parents are queued before rows that reference them.
    var migrated = 0;
    migrated += await _claim<OfflineAccount>(
      (row) => row.toDomain().toOffline(userId: realUserId),
    );
    migrated += await _claim<OfflineCategoryGroup>(
      (row) => CategoryGroupDefaults.normalizeForUser(
        row.toDomain(),
        userId: realUserId,
      ).toOffline(userId: realUserId),
    );
    migrated += await _claim<OfflineCategory>(
      (row) => CategoryDefaults.normalizeForUser(
        row.toDomain(),
        userId: realUserId,
      ).toOffline(userId: realUserId),
    );
    migrated += await _claim<OfflineTransaction>((row) {
      final transaction = row.toDomain();
      final categoryId = CategoryDefaults.categoryIdForUser(
        userId: realUserId,
        categoryId: transaction.categoryId,
      );
      return transaction
          .copyWith(categoryId: categoryId)
          .toOffline(userId: realUserId);
    });

    migrated += await _claim<OfflineInvestmentHolding>(
      (row) => row.toDomain().toOffline(userId: realUserId),
    );
    // Attachment metadata and bytes live in the file cache, not the record
    // store; this never throws.
    migrated += await _claimFiles(realUserId);

    if (kDebugMode) {
      debugPrint(
        '[aiko-sync] claimAnonymousData reassigned $migrated rows to '
        '$realUserId',
      );
    }
    return migrated;
  }

  Future<int> _claim<TModel extends OfflineRecord>(
    TModel Function(TModel row) reassign,
  ) async {
    try {
      final rows = await _store.get<TModel>(localOnly: true);
      final orphans = rows
          .where(
            (row) => (row.ownerId ?? '').startsWith(
              OfflineUserContext.localUserIdPrefix,
            ),
          )
          .toList(growable: false);
      // One batch (one server acknowledgement) per chunk, not one per row.
      for (
        var start = 0;
        start < orphans.length;
        start += OfflineStore.maxBatchWrites
      ) {
        final chunk = orphans.sublist(
          start,
          min(start + OfflineStore.maxBatchWrites, orphans.length),
        );
        final claimed = chunk.map(reassign).toList(growable: false);
        final staleRemoved = Completer<void>();
        await _store.upsertBatch<TModel>(
          claimed,
          // Put the guest rows back once their local copies are gone.
          onRejected: (_) => unawaited(
            staleRemoved.future.whenComplete(() => _restore(chunk)),
          ),
        );
        final stale = RecordBatch();
        for (var i = 0; i < chunk.length; i++) {
          if (_store.canSyncRemote || claimed[i].id != chunk[i].id) {
            stale.delete(chunk[i]);
          }
        }
        try {
          await _store.commit(stale, localOnly: true);
        } finally {
          staleRemoved.complete();
        }
      }
      return orphans.length;
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[aiko-sync] claim $TModel failed: $error');
      }
      return 0;
    }
  }

  /// The server rejected a claimed chunk: put the guest rows back so the next
  /// claim tries again instead of losing them.
  Future<void> _restore(List<OfflineRecord> rows) async {
    final batch = RecordBatch();
    for (final row in rows) {
      batch.upsert(row);
    }
    try {
      await _store.commit(batch, localOnly: true);
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[aiko-sync] restoring rejected claim failed: $error');
      }
    }
  }
}
