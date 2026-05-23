import 'package:brick_offline_first_with_supabase/brick_offline_first_with_supabase.dart';
import 'package:brick_sqlite/brick_sqlite.dart';
import 'package:brick_sqlite/memory_cache_provider.dart';
import 'package:brick_supabase/brick_supabase.dart';
import 'package:sqflite/sqflite.dart' show databaseFactory;
import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

import '../core/config/app_config.dart';
import '../core/supabase/supabase_client_provider.dart';
import 'brick.g.dart';
import 'db/schema.g.dart';

export 'package:brick_core/query.dart'
    show Compare, OrderBy, Query, Where, WhereCondition, WherePhrase;
export 'package:brick_offline_first/brick_offline_first.dart'
    show
        OfflineFirstDeletePolicy,
        OfflineFirstGetPolicy,
        OfflineFirstUpsertPolicy;

class AikoBrickRepository extends OfflineFirstWithSupabaseRepository {
  AikoBrickRepository._({
    required super.supabaseProvider,
    required super.sqliteProvider,
    required super.migrations,
    required super.offlineRequestQueue,
    required this.remoteSyncEnabled,
    super.memoryCacheProvider,
  }) : super(autoHydrate: true);

  static AikoBrickRepository? _singleton;

  final bool remoteSyncEnabled;

  factory AikoBrickRepository() {
    final instance = _singleton;
    if (instance == null) {
      throw StateError('AikoBrickRepository has not been initialized.');
    }
    return instance;
  }

  static Future<void> configure(AppConfig config) async {
    if (_singleton != null) {
      return;
    }

    final (client, queue) = OfflineFirstWithSupabaseRepository.clientQueue(
      databaseFactory: databaseFactory,
      databasePath: 'aiko_offline_queue.sqlite',
      ignorePaths: const {'/auth/v1', '/storage/v1', '/functions/v1'},
    );

    if (config.enableSupabase) {
      await AikoSupabase.initialize(config, httpClient: client);
    }

    final supabaseClient =
        AikoSupabase.tryClient() ??
        SupabaseClient(
          'https://offline.aiko.local',
          'offline-anon-key',
          httpClient: client,
        );

    _singleton = AikoBrickRepository._(
      supabaseProvider: SupabaseProvider(
        supabaseClient,
        modelDictionary: supabaseModelDictionary,
      ),
      sqliteProvider: SqliteProvider(
        'aiko_offline.sqlite',
        databaseFactory: databaseFactory,
        modelDictionary: sqliteModelDictionary,
      ),
      migrations: migrations,
      offlineRequestQueue: queue,
      memoryCacheProvider: MemoryCacheProvider(),
      remoteSyncEnabled: config.enableSupabase,
    );

    await _singleton!.initialize();
  }
}
