import 'package:aiko/brick/model_dictionary.dart';
import 'package:aiko/brick/db/schema.g.dart';
import 'package:aiko/brick/repository.dart';
import 'package:brick_sqlite/brick_sqlite.dart';
import 'package:brick_sqlite/db.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  test('repairs an interrupted template_id migration', () async {
    final provider = SqliteProvider(
      inMemoryDatabasePath,
      databaseFactory: databaseFactoryFfi,
      modelDictionary: sqliteModelDictionary,
    );
    await provider.rawExecute(
      'CREATE TABLE MigrationVersions(version INTEGER PRIMARY KEY)',
    );
    await provider.rawInsert(
      'INSERT INTO MigrationVersions(version) VALUES(?)',
      [20260620095103],
    );
    await provider.rawExecute(
      'CREATE TABLE OfflineCategory('
      '_brick_id INTEGER PRIMARY KEY, template_id VARCHAR NULL)',
    );
    await provider.rawExecute(
      'CREATE TABLE OfflineCategoryGroup('
      '_brick_id INTEGER PRIMARY KEY, template_id VARCHAR NULL)',
    );

    await AikoBrickRepository.repairInterruptedTemplateIdMigrationForTesting(
      provider,
    );
    final pending = MigrationManager(
      migrations,
    ).migrationsSince(await provider.lastMigrationVersion());
    await provider.migrate(pending);

    expect(await provider.lastMigrationVersion(), 20260725185723);
    expect(
      await provider.rawQuery(
        "SELECT name FROM pragma_table_info('OfflineCategory') "
        "WHERE name = 'template_id'",
      ),
      hasLength(1),
    );
    expect(
      await provider.rawQuery(
        "SELECT name FROM pragma_table_info('OfflineCategoryGroup') "
        "WHERE name = 'template_id'",
      ),
      hasLength(1),
    );
  });
}
