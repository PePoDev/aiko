import 'package:brick_offline_first_with_supabase/brick_offline_first_with_supabase.dart';

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
      ? OfflineFirstGetPolicy.alwaysHydrate
      : OfflineFirstGetPolicy.localOnly;

  Future<List<TModel>> get<TModel extends OfflineFirstWithSupabaseModel>({
    Query? query,
    OfflineFirstGetPolicy? policy,
  }) {
    return _repository.get<TModel>(query: query, policy: policy ?? readPolicy);
  }

  Future<TModel> upsert<TModel extends OfflineFirstWithSupabaseModel>(
    TModel model, {
    Query? query,
  }) async {
    if (_canSyncRemote) {
      return _repository.upsert<TModel>(
        model,
        query: query,
        policy: OfflineFirstUpsertPolicy.optimisticLocal,
      );
    }

    model.primaryKey = await _repository.sqliteProvider.upsert<TModel>(
      model,
      query: query,
      repository: _repository,
    );
    return model;
  }

  Future<bool> delete<TModel extends OfflineFirstWithSupabaseModel>(
    TModel model, {
    Query? query,
  }) async {
    if (_canSyncRemote) {
      return _repository.delete<TModel>(
        model,
        query: query,
        policy: OfflineFirstDeletePolicy.optimisticLocal,
      );
    }

    final rowsDeleted = await _repository.sqliteProvider.delete<TModel>(
      model,
      query: query,
      repository: _repository,
    );
    return rowsDeleted > 0;
  }
}
