import 'package:brick_offline_first_with_supabase/brick_offline_first_with_supabase.dart';
import 'package:flutter/foundation.dart';

import '../../brick/models/account.model.dart';
import '../../brick/models/budget.model.dart';
import '../../brick/models/category.model.dart';
import '../../brick/models/goal.model.dart';
import '../../brick/models/transaction.model.dart';
import '../../brick/offline_model_mappers.dart';
import '../../brick/repository.dart' show OfflineFirstGetPolicy;
import 'offline_store.dart';

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
  OfflineDataMigrator({OfflineStore? store})
    : _store = store ?? OfflineStore();

  final OfflineStore _store;

  static const _localPrefix = 'local:';

  /// Claims every locally-created row for [realUserId]. Returns the number of
  /// rows reassigned. Safe to call repeatedly: it is a no-op once nothing is
  /// orphaned, and it never throws (failures are logged in debug only).
  Future<int> claimAnonymousData(String realUserId) async {
    if (realUserId.isEmpty || realUserId.startsWith(_localPrefix)) {
      return 0;
    }

    // Order matters: parents (accounts, categories) are reassigned and queued
    // to Supabase before the rows that reference them (transactions, budgets,
    // goals) so foreign-key constraints are satisfied as the writes sync.
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
    migrated += await _claim<OfflineBudget>(
      realUserId,
      (row) => row.userId,
      (row) => row.toDomain().toOffline(userId: realUserId),
    );
    migrated += await _claim<OfflineGoal>(
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
          .where((row) => userIdOf(row).startsWith(_localPrefix))
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
