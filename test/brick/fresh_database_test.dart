import 'dart:io';
import 'package:aiko/brick/repository.dart';
import 'package:aiko/brick/models/category.model.dart';
import 'package:aiko/core/config/app_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart' as sqlite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  test('fresh local database applies migrations in version order', () async {
    sqfliteFfiInit();
    final dir = await Directory.systemTemp.createTemp('aiko-fresh-');
    sqlite.databaseFactory = databaseFactoryFfi;
    await databaseFactoryFfi.setDatabasesPath(dir.path);
    try {
      await AikoBrickRepository.configure(const AppConfig());
      expect(await AikoBrickRepository().get<OfflineCategory>(), isEmpty);
      await AikoBrickRepository.resetLocalData();
      expect(await AikoBrickRepository().get<OfflineCategory>(), isEmpty);
    } finally {
      // The provider has no public close API; this test owns the isolated DB.
      // ignore: invalid_use_of_protected_member
      await (await AikoBrickRepository().sqliteProvider.getDb()).close();
      await dir.delete(recursive: true);
    }
  });
}
