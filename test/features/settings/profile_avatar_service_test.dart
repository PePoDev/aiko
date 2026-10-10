import 'package:aiko/core/storage/local_file_cache.dart';
import 'package:aiko/features/settings/application/profile_avatar_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart' as sqlite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    sqlite.databaseFactory = databaseFactoryFfi;
  });

  final service = ProfileAvatarService(resolveUserId: () async => 'local:u1');

  test('a picked photo leaves the saved avatar alone until commit', () async {
    final saved = await LocalFileCache.write('avatars/local:u1.jpg', [1, 1]);

    final pending = await service.stage([2, 2], fileName: 'new.JPG');

    expect(pending.previewPath, isNot(saved));
    expect(await LocalFileCache.read(saved), [1, 1]);
    expect(await LocalFileCache.read(pending.previewPath), [2, 2]);

    final committed = await service.commit(pending, replacedPath: saved);

    expect(committed.localPath, saved);
    expect(committed.cloudUrl, isNull); // Not signed in: no upload.
    expect(await LocalFileCache.read(saved), [2, 2]);
    await expectLater(
      LocalFileCache.read(pending.previewPath),
      throwsStateError,
    );
  });

  test('commit drops a previous avatar stored under another type', () async {
    final previous = await LocalFileCache.write('avatars/local:u1.png', [3]);
    final pending = await service.stage([4], fileName: 'next.jpg');

    final committed = await service.commit(pending, replacedPath: previous);

    expect(committed.localPath, 'aiko-cache:avatars/local:u1.jpg');
    await expectLater(LocalFileCache.read(previous), throwsStateError);
  });

  test('discard removes only the preview', () async {
    final saved = await LocalFileCache.write('avatars/local:u1.webp', [5]);
    final pending = await service.stage([6], fileName: 'x.webp');

    await service.discard(pending);

    await expectLater(
      LocalFileCache.read(pending.previewPath),
      throwsStateError,
    );
    expect(await LocalFileCache.read(saved), [5]);
  });
}
