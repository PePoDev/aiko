import 'package:brick_offline_first_with_supabase/brick_offline_first_with_supabase.dart';
import 'package:brick_sqlite/brick_sqlite.dart';
import 'package:brick_sqlite/memory_cache_provider.dart';
import 'package:brick_supabase/brick_supabase.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart' show databaseFactory;

import '../core/config/app_config.dart';
import '../core/supabase/supabase_client_provider.dart';
import '../core/supabase/supabase_session_http_client.dart';
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
  static const _templateIdMigrationVersion = 20260725185723;
  static const _templateIdMigrationPredecessor = 20260620095103;

  AikoBrickRepository._({
    required super.supabaseProvider,
    required super.sqliteProvider,
    required super.migrations,
    required super.offlineRequestQueue,
    super.memoryCacheProvider,
  }) : super(autoHydrate: true);

  static AikoBrickRepository? _singleton;

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
      innerClient: SupabaseSessionHttpClient(),
      onReattempt: (request, statusCode) {
        // Surfaces the HTTP status Supabase returned for a queued write that is
        // being retried (e.g. 409 foreign key, 403 RLS), which is otherwise
        // swallowed by the optimistic-local upsert policy.
        if (kDebugMode) {
          debugPrint(
            '[aiko-sync] queue reattempt ${request.method} '
            '${request.url.path} -> HTTP $statusCode',
          );
        }
      },
    );

    // Supabase is required; this throws via requireClient() if creds are absent.
    await AikoSupabase.initialize(config, httpClient: client);

    _singleton = AikoBrickRepository._(
      supabaseProvider: SupabaseProvider(
        AikoSupabase.requireClient(),
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
    );

    await _repairInterruptedTemplateIdMigration(_singleton!.sqliteProvider);
    await _singleton!.initialize();
  }

  static Future<void> _repairInterruptedTemplateIdMigration(
    SqliteProvider provider,
  ) async {
    if (await provider.lastMigrationVersion() !=
        _templateIdMigrationPredecessor) {
      return;
    }

    await provider.transaction((transaction) async {
      const tables = ['OfflineCategory', 'OfflineCategoryGroup'];
      final existingTables = await transaction.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table' "
        'AND name IN (?, ?)',
        tables,
      );
      if (existingTables.length != tables.length) {
        return;
      }

      for (final table in tables) {
        final columns = await transaction.rawQuery(
          'PRAGMA table_info(`$table`)',
        );
        if (!columns.any((column) => column['name'] == 'template_id')) {
          await transaction.execute(
            'ALTER TABLE `$table` ADD `template_id` VARCHAR NULL',
          );
        }
      }

      await transaction.rawInsert(
        'INSERT OR IGNORE INTO MigrationVersions(version) VALUES(?)',
        [_templateIdMigrationVersion],
      );
    });
  }

  @visibleForTesting
  static Future<void> repairInterruptedTemplateIdMigrationForTesting(
    SqliteProvider provider,
  ) => _repairInterruptedTemplateIdMigration(provider);

  static Future<void> resetLocalData() async {
    final repository = _singleton;
    if (repository == null) {
      return;
    }

    await repository.reset();

    final queueManager = repository.offlineRequestQueue.client.requestManager;
    final queueDb = await queueManager.getDb();
    await queueDb.delete(queueManager.tableName);
  }
}
