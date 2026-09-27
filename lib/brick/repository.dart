import 'package:brick_core/core.dart';
import 'package:brick_sqlite/brick_sqlite.dart';
import 'package:flutter/foundation.dart';

import '../core/storage/database_factory.dart';
import '../core/config/app_config.dart';
import 'model_dictionary.dart';
import 'db/schema.g.dart';

export 'package:brick_core/query.dart'
    show Compare, OrderBy, Query, Where, WhereCondition, WherePhrase;

enum OfflineReadPolicy {
  localOnly,
  awaitRemoteWhenNoneExist,
  awaitRemote,
  alwaysHydrate,
}

/// SQLite retains existing mobile data and supports local-only installations.
/// Signed-in data and its offline write queue are owned by the Firebase SDK.
class AikoBrickRepository extends ModelRepository<SqliteModel> {
  static const _templateIdMigrationVersion = 20260725185723;
  static const _templateIdMigrationPredecessor = 20260620095103;
  AikoBrickRepository._(this.sqliteProvider);
  final SqliteProvider sqliteProvider;
  static AikoBrickRepository? _singleton;

  factory AikoBrickRepository() =>
      _singleton ??
      (throw StateError('Local data store has not been initialized.'));

  static Future<void> configure(AppConfig config) async {
    if (_singleton != null) return;
    final provider = SqliteProvider(
      'aiko_offline.sqlite',
      databaseFactory: databaseFactory,
      modelDictionary: sqliteModelDictionary,
    );
    await _repairInterruptedTemplateIdMigration(provider);
    await provider.migrate(
      migrations.toList()..sort((a, b) => a.version.compareTo(b.version)),
    );
    _singleton = AikoBrickRepository._(provider);
  }

  @override
  Future<List<T>> get<T extends SqliteModel>({Query? query}) =>
      sqliteProvider.get<T>(query: query, repository: this);

  @override
  Future<T> upsert<T extends SqliteModel>(T model, {Query? query}) async {
    model.primaryKey = await sqliteProvider.upsert<T>(
      model,
      query: query,
      repository: this,
    );
    return model;
  }

  @override
  Future<bool> delete<T extends SqliteModel>(T model, {Query? query}) async =>
      await sqliteProvider.delete<T>(model, query: query, repository: this) > 0;

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
    final instance = _singleton;
    if (instance == null) return;
    await instance.sqliteProvider.resetDb();
    await instance.sqliteProvider.migrate(
      migrations.toList()..sort((a, b) => a.version.compareTo(b.version)),
    );
  }
}
