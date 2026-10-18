import 'dart:typed_data';

import 'dart:io';

import 'package:aiko/core/storage/local_file_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'file_store_harness.dart';

void main() {
  late Database db;

  setUp(() async => db = await openMemoryFileCache());
  tearDown(() => closeMemoryFileCache(db));

  test(
    'cached bytes can be reopened and replaced by their durable path',
    () async {
      final path = await LocalFileCache.write('test/receipt', [0, 128, 255]);
      expect(path, 'aiko-cache:test/receipt');
      expect(await LocalFileCache.read(path), [0, 128, 255]);
      expect(await LocalFileCache.write('test/receipt', [12, 34]), path);
      expect(await LocalFileCache.read(path), [12, 34]);
      await LocalFileCache.remove(path);
      await expectLater(LocalFileCache.read(path), throwsStateError);
    },
  );

  test('move renames cached bytes, replacing the target', () async {
    final from = await LocalFileCache.write('attachments/a', [1]);
    await LocalFileCache.write('receipts/b', [9]);

    final to = await LocalFileCache.move(from, 'receipts/b');

    expect(to, 'aiko-cache:receipts/b');
    expect(await LocalFileCache.read(to), [1]);
    expect(await LocalFileCache.contains(from), isFalse);
    // Nothing to move: the target stays as it is.
    expect(await LocalFileCache.move('aiko-cache:missing', 'receipts/b'), to);
    expect(await LocalFileCache.read(to), [1]);
  });

  test('device paths are told apart from Storage paths', () {
    expect(LocalFileCache.isDevicePath('aiko-cache:attachments/a'), isTrue);
    expect(LocalFileCache.isDevicePath('/data/user/0/cache/a.jpg'), isTrue);
    expect(LocalFileCache.isDevicePath('blob:https://app/1234'), isTrue);
    expect(LocalFileCache.isDevicePath(r'C:\Users\a.jpg'), isTrue);
    expect(LocalFileCache.isDevicePath('users/u/receipts/r/a.jpg'), isFalse);
  });

  test(
    'a version 1 database keeps its files and gains the new tables',
    () async {
      sqfliteFfiInit();
      final dir = Directory.systemTemp.createTempSync('aiko_files');
      addTearDown(() => dir.deleteSync(recursive: true));
      final path = '${dir.path}/${LocalFileCache.fileName}';
      final v1 = await databaseFactoryFfiNoIsolate.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, _) => db.execute(
            'CREATE TABLE files (path TEXT PRIMARY KEY, bytes BLOB NOT NULL)',
          ),
        ),
      );
      await v1.insert('files', {
        'path': 'aiko-cache:avatars/u.jpg',
        'bytes': Uint8List.fromList([5]),
      });
      await v1.close();

      final upgraded = await LocalFileCache.openAt(
        path,
        factory: databaseFactoryFfiNoIsolate,
      );
      addTearDown(upgraded.close);

      expect(await upgraded.getVersion(), LocalFileCache.schemaVersion);
      final file = (await upgraded.query('files')).single;
      expect(file['path'], 'aiko-cache:avatars/u.jpg');
      // Sizes of files from before are filled in for trim.
      expect(file['size'], 1);
      expect(await upgraded.query('attachments'), isEmpty);
      expect(await upgraded.query('file_jobs'), isEmpty);
    },
  );

  test('trim lets the oldest copies under a key go, nothing else', () async {
    Future<void> writeAt(String key, int size, int at) async {
      await LocalFileCache.write(key, List.filled(size, 1));
      await db.update(
        'files',
        {'cached_at': at},
        where: 'path = ?',
        whereArgs: ['aiko-cache:$key'],
      );
    }

    await writeAt('receipts/users/u/old', 40, 1);
    await writeAt('receipts/users/u/mid', 40, 2);
    await writeAt('receipts/users/u/new', 40, 3);
    await writeAt('attachments/waiting', 400, 0);

    await LocalFileCache.trim('receipts/', maxBytes: 100);

    expect(
      await LocalFileCache.contains('aiko-cache:receipts/users/u/new'),
      isTrue,
    );
    expect(
      await LocalFileCache.contains('aiko-cache:receipts/users/u/mid'),
      isTrue,
    );
    expect(
      await LocalFileCache.contains('aiko-cache:receipts/users/u/old'),
      isFalse,
    );
    // Bytes that exist only here are never trimmed.
    expect(
      await LocalFileCache.contains('aiko-cache:attachments/waiting'),
      isTrue,
    );
  });

  test('removeUnder deletes only the files under that key', () async {
    await LocalFileCache.write('avatars/u1/a.jpg', [1]);
    await LocalFileCache.write('avatars/u1/b.jpg', [1]);
    await LocalFileCache.write('avatars/u10/c.jpg', [1]);

    await LocalFileCache.removeUnder('avatars/u1/');

    expect(
      await LocalFileCache.contains('aiko-cache:avatars/u1/a.jpg'),
      isFalse,
    );
    expect(
      await LocalFileCache.contains('aiko-cache:avatars/u1/b.jpg'),
      isFalse,
    );
    expect(
      await LocalFileCache.contains('aiko-cache:avatars/u10/c.jpg'),
      isTrue,
    );
  });
}
