import 'package:aiko/core/storage/local_file_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart' as sqlite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    sqlite.databaseFactory = databaseFactoryFfi;
  });

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
}
