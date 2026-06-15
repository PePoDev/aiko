import 'package:brick_offline_first_with_supabase/brick_offline_first_with_supabase.dart';
import 'package:flutter/foundation.dart';

import '../../brick/repository.dart';
import '../supabase/supabase_client_provider.dart';

class OfflineStore {
  OfflineStore({AikoBrickRepository? repository})
    : _repository = repository ?? AikoBrickRepository();

  final AikoBrickRepository _repository;

  bool get _canSyncRemote =>
      _repository.remoteSyncEnabled &&
      AikoSupabase.tryClient()?.auth.currentUser != null;

  bool get canSyncRemote => _canSyncRemote;

  OfflineFirstGetPolicy get readPolicy => _canSyncRemote
      ? OfflineFirstGetPolicy.awaitRemoteWhenNoneExist
      : OfflineFirstGetPolicy.localOnly;

  Future<List<TModel>> get<TModel extends OfflineFirstWithSupabaseModel>({
    Query? query,
    OfflineFirstGetPolicy? policy,
  }) async {
    // Honor an explicit policy, and stay local-only when there is no signed-in
    // Supabase session to sync against.
    if (policy != null || !_canSyncRemote) {
      return _repository.get<TModel>(
        query: query,
        policy: policy ?? OfflineFirstGetPolicy.localOnly,
      );
    }

    // Signed in: when nothing is cached locally for this query (e.g. a fresh
    // install signing back into an existing account), await the Supabase fetch
    // so existing rows are returned on the first read instead of an empty list.
    // `alwaysHydrate` alone would return the empty local result immediately and
    // only hydrate in an unawaited background pass, which is why a reinstall
    // previously showed nothing but locally-seeded data.
    final hasLocalData = (await _repository.get<TModel>(
      query: query,
      policy: OfflineFirstGetPolicy.localOnly,
    )).isNotEmpty;

    // Once local data exists, return it immediately but keep refreshing from
    // Supabase in the background so later reads stay in sync across devices.
    return _repository.get<TModel>(
      query: query,
      policy: hasLocalData
          ? OfflineFirstGetPolicy.alwaysHydrate
          : OfflineFirstGetPolicy.awaitRemoteWhenNoneExist,
    );
  }

  Future<TModel> upsert<TModel extends OfflineFirstWithSupabaseModel>(
    TModel model, {
    Query? query,
  }) async {
    if (_canSyncRemote) {
      try {
        final saved = await _repository.upsert<TModel>(
          model,
          query: query,
          policy: OfflineFirstUpsertPolicy.optimisticLocal,
        );
        if (kDebugMode) {
          debugPrint('[aiko-sync] upsert $TModel pushed to Supabase');
        }
        return saved;
      } catch (error) {
        // Brick queues network failures internally; anything surfacing here is
        // a real rejection (RLS, foreign key, schema) worth seeing.
        if (kDebugMode) {
          debugPrint('[aiko-sync] upsert $TModel remote push FAILED: $error');
        }
        rethrow;
      }
    }

    model.primaryKey = await _repository.sqliteProvider.upsert<TModel>(
      model,
      query: query,
      repository: _repository,
    );
    if (kDebugMode) {
      debugPrint(
        '[aiko-sync] upsert $TModel saved LOCAL-ONLY '
        '(remoteSyncEnabled=${_repository.remoteSyncEnabled}, '
        'signedIn=${AikoSupabase.tryClient()?.auth.currentUser != null}) — '
        'will not reach Supabase until sign-in',
      );
    }
    return model;
  }

  /// Hard-deletes [model]: removes the row from SQLite and, when signed in,
  /// queues a remote `DELETE` so the row is removed from Supabase too. Brick's
  /// offline queue retries the remote delete when connectivity returns.
  ///
  /// When [localOnly] is true (or there is no Supabase session) the row is
  /// removed from SQLite only — no remote request is queued. Used both for
  /// local-only mode and to purge rows that never existed in Supabase (e.g.
  /// legacy `default-*` slug categories) so the queue is not poisoned with a
  /// request the server will reject forever.
  Future<bool> delete<TModel extends OfflineFirstWithSupabaseModel>(
    TModel model, {
    Query? query,
    bool localOnly = false,
  }) async {
    if (localOnly || !_canSyncRemote) {
      final rowsDeleted = await _repository.sqliteProvider.delete<TModel>(
        model,
        query: query,
        repository: _repository,
      );
      return rowsDeleted > 0;
    }

    return _repository.delete<TModel>(model, query: query);
  }
}
