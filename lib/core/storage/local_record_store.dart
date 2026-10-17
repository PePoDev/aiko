import 'dart:convert';

import 'package:sqflite/sqflite.dart'
    show
        ConflictAlgorithm,
        Database,
        DatabaseFactory,
        OpenDatabaseOptions,
        Transaction;

import '../offline/record_batch.dart';
import 'database_factory.dart' as platform;

/// The device copy of records that are not synced to Firestore (signed out or
/// local-only builds): one SQLite database (native, or IndexedDB on web via
/// [platform.databaseFactory]) with a single `records` table that keeps each
/// record as its document row in JSON.
class LocalRecordStore {
  LocalRecordStore._(this._db);

  /// The database file (native) or IndexedDB entry (web).
  static const fileName = 'aiko_local.sqlite';

  /// Stored as `PRAGMA user_version`; bump it and extend [_upgrade] when the
  /// table layout changes.
  static const schemaVersion = 1;

  static LocalRecordStore? _instance;
  static Future<LocalRecordStore>? _opening;

  /// The store opened by [open]. Throws before the app has opened it.
  static LocalRecordStore get instance =>
      _instance ??
      (throw StateError('Local data store has not been initialized.'));

  static bool get isOpen => _instance != null;

  final Database _db;

  /// Opens the app's store once and makes it [instance]; later calls return
  /// the same store.
  static Future<LocalRecordStore> open() {
    final instance = _instance;
    if (instance != null) return Future.value(instance);
    return _opening ??= openAt(
      fileName,
    ).then((store) => _instance = store).whenComplete(() => _opening = null);
  }

  /// Opens (creating or upgrading) a store at [path] without registering it
  /// as [instance]. Tests pass an in-memory path and an FFI [factory].
  static Future<LocalRecordStore> openAt(
    String path, {
    DatabaseFactory? factory,
  }) async {
    final db = await (factory ?? platform.databaseFactory).openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onCreate: (db, version) => _upgrade(db, 0, version),
        onUpgrade: _upgrade,
      ),
    );
    return LocalRecordStore._(db);
  }

  static Future<void> _upgrade(Database db, int from, int to) async {
    if (from < 1) {
      await db.execute('''
        CREATE TABLE records (
          collection TEXT NOT NULL,
          id TEXT NOT NULL,
          owner_id TEXT,
          data TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          PRIMARY KEY (collection, id)
        )''');
      await db.execute(
        'CREATE INDEX records_owner ON records (collection, owner_id)',
      );
      await db.execute(
        'CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
      );
    }
  }

  /// Rows of [collection], optionally only [ownerId]'s and/or the one with
  /// [id], in no particular order.
  Future<List<Map<String, dynamic>>> rows(
    String collection, {
    String? ownerId,
    String? id,
  }) async {
    final where = StringBuffer('collection = ?');
    final args = <Object?>[collection];
    if (ownerId != null) {
      where.write(' AND owner_id = ?');
      args.add(ownerId);
    }
    if (id != null) {
      where.write(' AND id = ?');
      args.add(id);
    }
    final result = await _db.query(
      'records',
      columns: const ['data'],
      where: where.toString(),
      whereArgs: args,
    );
    return [
      for (final row in result)
        (jsonDecode(row['data']! as String) as Map).cast<String, dynamic>(),
    ];
  }

  /// Applies [writes] in order in one transaction: all or nothing.
  Future<void> apply(Iterable<RecordWrite> writes) => transaction((txn) async {
    for (final write in writes) {
      await txn.write(write);
    }
  });

  /// Runs [action] in one SQLite transaction; nothing it wrote is kept if it
  /// throws.
  Future<T> transaction<T>(
    Future<T> Function(LocalRecordTransaction txn) action,
  ) => _db.transaction((txn) => action(LocalRecordTransaction._(txn)));

  /// A value of the store's own key-value table (bookkeeping such as
  /// one-time imports), or null.
  Future<String?> meta(String key) async {
    final result = await _db.query(
      'meta',
      columns: const ['value'],
      where: 'key = ?',
      whereArgs: [key],
    );
    return result.isEmpty ? null : result.single['value'] as String?;
  }

  /// Closes the database. Tests use this; the app keeps it open.
  Future<void> close() async {
    if (identical(_instance, this)) _instance = null;
    await _db.close();
  }
}

/// Writes inside one [LocalRecordStore.transaction].
class LocalRecordTransaction {
  LocalRecordTransaction._(this._txn);

  final Transaction _txn;

  /// Applies one put or delete.
  Future<void> write(RecordWrite write) async {
    final row = write.row;
    if (row == null) {
      await remove(write.collection, write.id, ownerId: write.ownerId);
    } else {
      await put(write.collection, write.id, write.ownerId, row);
    }
  }

  /// Stores [row] as the record [collection]/[id]. With [replace] false an
  /// existing record is kept as it is.
  Future<void> put(
    String collection,
    String id,
    String? ownerId,
    Map<String, dynamic> row, {
    bool replace = true,
  }) async {
    await _txn.insert(
      'records',
      {
        'collection': collection,
        'id': id,
        'owner_id': ownerId,
        'data': jsonEncode(row),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      conflictAlgorithm: replace
          ? ConflictAlgorithm.replace
          : ConflictAlgorithm.ignore,
    );
  }

  /// Deletes the record [collection]/[id]; only [ownerId]'s when given.
  Future<void> remove(String collection, String id, {String? ownerId}) async {
    await _txn.delete(
      'records',
      where: ownerId == null
          ? 'collection = ? AND id = ?'
          : 'collection = ? AND id = ? AND owner_id = ?',
      whereArgs: [collection, id, ?ownerId],
    );
  }

  Future<void> setMeta(String key, String value) async {
    await _txn.insert('meta', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
