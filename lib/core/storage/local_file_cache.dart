import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart'
    show
        ConflictAlgorithm,
        Database,
        DatabaseExecutor,
        DatabaseFactory,
        OpenDatabaseOptions;

import 'database_factory.dart' as platform;

/// Durable bytes on mobile SQLite and browser IndexedDB-backed SQLite.
/// Picker paths on the web are temporary blob URLs, so never persist those.
///
/// The same database also keeps the device's attachment metadata
/// (`attachments`) and the files waiting to be uploaded to or deleted from
/// Firebase Storage (`file_jobs`, see `FileSyncQueue`).
class LocalFileCache {
  /// The database file (native) or IndexedDB entry (web).
  static const fileName = 'aiko_files.sqlite';

  /// Bump it and extend [_upgrade] when the table layout changes.
  static const schemaVersion = 3;

  /// Prefix of every path [write] returns.
  static const pathPrefix = 'aiko-cache:';

  /// How much room copies of cloud files may take ([trim]). The web keeps
  /// the whole database in memory, so it keeps fewer.
  static const cloudCopiesBytes = kIsWeb ? 30 << 20 : 100 << 20;

  static Future<Database>? _database;

  /// The app's file database, opened on first use.
  static Future<Database> database() => _database ??= openAt(fileName).then(
    (db) => db,
    // A failed open (no storage) is tried again next time.
    onError: (Object error, StackTrace stackTrace) {
      _database = null;
      Error.throwWithStackTrace(error, stackTrace);
    },
  );

  /// Opens (creating or upgrading) a file database at [path] without making
  /// it the app's. Tests pass an in-memory path and an FFI [factory].
  @visibleForTesting
  static Future<Database> openAt(String path, {DatabaseFactory? factory}) {
    return (factory ?? platform.databaseFactory).openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onCreate: (db, version) => _upgrade(db, 0, version),
        onUpgrade: _upgrade,
      ),
    );
  }

  /// Tests: makes [database] the one every call uses (null forgets it).
  @visibleForTesting
  static void useDatabase(Database? database) =>
      _database = database == null ? null : Future.value(database);

  static Future<void> _upgrade(Database db, int from, int to) async {
    if (from < 1) {
      await db.execute(
        'CREATE TABLE files (path TEXT PRIMARY KEY, bytes BLOB NOT NULL)',
      );
    }
    if (from < 2) {
      // Attachment metadata kept on this device: every attachment of a guest
      // or local-only owner, and a signed-in owner's attachments until their
      // upload finishes. `data` is the Firestore document row as JSON.
      await db.execute('''
        CREATE TABLE attachments (
          id TEXT PRIMARY KEY,
          owner_id TEXT NOT NULL,
          transaction_id TEXT NOT NULL,
          data TEXT NOT NULL,
          created_at TEXT NOT NULL
        )''');
      await db.execute(
        'CREATE INDEX attachments_owner ON attachments '
        '(owner_id, transaction_id)',
      );
      // Uploads and deletes waiting for Firebase Storage, in `seq` order.
      await db.execute('''
        CREATE TABLE file_jobs (
          id TEXT PRIMARY KEY,
          owner_id TEXT NOT NULL,
          kind TEXT NOT NULL,
          data TEXT NOT NULL,
          seq INTEGER NOT NULL,
          attempts INTEGER NOT NULL DEFAULT 0
        )''');
      await db.execute(
        'CREATE INDEX file_jobs_owner ON file_jobs (owner_id, seq)',
      );
    }
    if (from < 3) {
      // Size and write time of each file, so [trim] can let the oldest
      // copies of cloud files go without reading their bytes.
      await db.execute(
        'ALTER TABLE files ADD COLUMN size INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE files ADD COLUMN cached_at INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute('UPDATE files SET size = length(bytes)');
    }
  }

  /// Whether [path] points at bytes on this device (a cache path, a picker
  /// file or a web blob) rather than a Firebase Storage object.
  static bool isDevicePath(String path) =>
      path.startsWith(pathPrefix) ||
      path.startsWith('/') ||
      path.startsWith('blob:') ||
      path.startsWith('file:') ||
      RegExp(r'^[A-Za-z]:[\\/]').hasMatch(path);

  /// Stores [bytes] under [key] and returns their path. Pass [txn] to write
  /// inside a transaction on [database].
  static Future<String> write(
    String key,
    List<int> bytes, {
    DatabaseExecutor? txn,
  }) async {
    final path = '$pathPrefix$key';
    await (txn ?? await database()).insert('files', {
      'path': path,
      'bytes': Uint8List.fromList(bytes),
      'size': bytes.length,
      'cached_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    return path;
  }

  static Future<Uint8List> read(String path) async {
    if (!path.startsWith(pathPrefix)) return XFile(path).readAsBytes();
    final rows = await (await database()).query(
      'files',
      where: 'path = ?',
      whereArgs: [path],
    );
    if (rows.isEmpty) {
      throw StateError('This file is not cached on this device.');
    }
    return Uint8List.fromList(rows.first['bytes'] as List<int>);
  }

  /// Whether the cache holds bytes at [path].
  static Future<bool> contains(String path) async =>
      path.startsWith(pathPrefix) && await _exists(await database(), path);

  static Future<void> remove(String path, {DatabaseExecutor? txn}) async {
    if (!path.startsWith(pathPrefix)) return;
    await (txn ?? await database()).delete(
      'files',
      where: 'path = ?',
      whereArgs: [path],
    );
  }

  /// Moves the cached bytes at [path] to [key] (replacing what is there)
  /// without reading them, and returns the new path. Nothing moves when
  /// [path] is not cached.
  static Future<String> move(
    String path,
    String key, {
    DatabaseExecutor? txn,
  }) async {
    final target = '$pathPrefix$key';
    if (target == path || !path.startsWith(pathPrefix)) return target;
    final executor = txn ?? await database();
    if (!await _exists(executor, path)) return target;
    await executor.delete('files', where: 'path = ?', whereArgs: [target]);
    await executor.update(
      'files',
      {'path': target, 'cached_at': DateTime.now().millisecondsSinceEpoch},
      where: 'path = ?',
      whereArgs: [path],
    );
    return target;
  }

  /// Deletes every cached file whose key starts with [keyPrefix].
  static Future<void> removeUnder(
    String keyPrefix, {
    DatabaseExecutor? txn,
  }) async {
    final prefix = '$pathPrefix$keyPrefix';
    await (txn ?? await database()).delete(
      'files',
      where: 'substr(path, 1, ?) = ?',
      whereArgs: [prefix.length, prefix],
    );
  }

  /// Lets the oldest files whose key starts with [keyPrefix] go until those
  /// left take at most [maxBytes]. Only for copies that can be fetched again
  /// (downloads and uploaded files), never for bytes that exist only here.
  static Future<void> trim(
    String keyPrefix, {
    int maxBytes = cloudCopiesBytes,
    DatabaseExecutor? txn,
  }) async {
    final executor = txn ?? await database();
    final prefix = '$pathPrefix$keyPrefix';
    final rows = await executor.query(
      'files',
      columns: const ['path', 'size'],
      where: 'substr(path, 1, ?) = ?',
      whereArgs: [prefix.length, prefix],
      orderBy: 'cached_at DESC, path',
    );
    var kept = 0;
    final drop = <String>[];
    for (final row in rows) {
      kept += row['size']! as int;
      if (kept > maxBytes) drop.add(row['path']! as String);
    }
    for (final path in drop) {
      await executor.delete('files', where: 'path = ?', whereArgs: [path]);
    }
  }

  static Future<bool> _exists(DatabaseExecutor executor, String path) async {
    final rows = await executor.query(
      'files',
      columns: const ['path'],
      where: 'path = ?',
      whereArgs: [path],
    );
    return rows.isNotEmpty;
  }
}
