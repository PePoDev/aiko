import 'package:brick_offline_first_with_supabase/brick_offline_first_with_supabase.dart';
import 'package:flutter/foundation.dart';

import '../../brick/models/account.model.dart';
import '../../brick/models/category.model.dart';
import '../../brick/models/transaction.model.dart';
import '../../brick/offline_model_mappers.dart';
import '../../brick/repository.dart' show OfflineFirstGetPolicy;
import 'offline_store.dart';
import 'offline_user_context.dart';

/// Reassigns rows that were created while signed out (under an anonymous
/// `local:<uuid>` user id) to the real Supabase user id after sign-in.
///
/// Without this, data captured before signing in is orphaned: every repository
/// query filters by the currently resolved user id, so once that id flips from
/// `local:<uuid>` to the real UUID the earlier rows silently disappear from the
/// UI even though they are still in the local database.
///
/// Each reclaimed row is re-upserted, which updates its local `user_id` in place
/// (matched by its unique `id`) and queues it to sync up to Supabase.
class OfflineDataMigrator {
  OfflineDataMigrator() : _store = OfflineStore();

  final OfflineStore _store;

  /// Claims every locally-created row for [realUserId]. Returns the number of
  /// rows reassigned. Safe to call repeatedly: it is a no-op once nothing is
  /// orphaned, and it never throws (failures are logged in debug only).
  Future<int> claimAnonymousData(String realUserId) async {
    if (realUserId.isEmpty ||
        realUserId.startsWith(OfflineUserContext.localUserIdPrefix)) {
      return 0;
    }

    // Order matters: parents (accounts, categories) are reassigned and queued
    // to Supabase before the rows that reference them (transactions) so
    // foreign-key constraints are satisfied as the writes sync. Budget and
    // goal rows are gone (PR5 of the merge plan).
    var migrated = 0;
    migrated += await _claim<OfflineAccount>(
      realUserId,
      (row) => row.userId,
      (row) => row.toDomain().toOffline(userId: realUserId),
    );
    migrated += await _claim<OfflineCategory>(
      realUserId,
      (row) => row.userId,
      (row) => row.toDomain().toOffline(userId: realUserId),
    );
    migrated += await _claim<OfflineTransaction>(
      realUserId,
      (row) => row.userId,
      (row) => row.toDomain().toOffline(userId: realUserId),
    );

    if (kDebugMode) {
      debugPrint(
        '[aiko-sync] claimAnonymousData reassigned $migrated rows to '
        '$realUserId',
      );
    }
    return migrated;
  }

  Future<int> _claim<TModel extends OfflineFirstWithSupabaseModel>(
    String realUserId,
    String Function(TModel row) userIdOf,
    TModel Function(TModel row) reassign,
  ) async {
    try {
      final rows = await _store.get<TModel>(
        policy: OfflineFirstGetPolicy.localOnly,
      );
      final orphans = rows
          .where(
            (row) =>
                userIdOf(row).startsWith(OfflineUserContext.localUserIdPrefix),
          )
          .toList(growable: false);
      for (final row in orphans) {
        await _store.upsert<TModel>(reassign(row));
      }
      return orphans.length;
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[aiko-sync] claim $TModel failed: $error');
      }
      return 0;
    }
  }
}
