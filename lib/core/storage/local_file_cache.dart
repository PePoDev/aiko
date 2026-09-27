import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:sqflite/sqflite.dart'
    show Database, OpenDatabaseOptions, ConflictAlgorithm;

import 'database_factory.dart';

/// Durable bytes on mobile SQLite and browser IndexedDB-backed SQLite.
/// Picker paths on the web are temporary blob URLs, so never persist those.
class LocalFileCache {
  static Future<Database>? _database;

  static Future<Database> _open() => _database ??= databaseFactory.openDatabase(
    'aiko_files.sqlite',
    options: OpenDatabaseOptions(
      version: 1,
      onCreate: (db, _) => db.execute(
        'CREATE TABLE files (path TEXT PRIMARY KEY, bytes BLOB NOT NULL)',
      ),
    ),
  );

  static Future<String> write(String key, List<int> bytes) async {
    final path = 'aiko-cache:$key';
    await (await _open()).insert('files', {
      'path': path,
      'bytes': Uint8List.fromList(bytes),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    return path;
  }

  static Future<Uint8List> read(String path) async {
    if (!path.startsWith('aiko-cache:')) return XFile(path).readAsBytes();
    final rows = await (await _open()).query(
      'files',
      where: 'path = ?',
      whereArgs: [path],
    );
    if (rows.isEmpty) {
      throw StateError('This file is not cached on this device.');
    }
    return Uint8List.fromList(rows.first['bytes'] as List<int>);
  }

  static Future<void> remove(String path) async {
    if (!path.startsWith('aiko-cache:')) return;
    await (await _open()).delete('files', where: 'path = ?', whereArgs: [path]);
  }
}
