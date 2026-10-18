import 'dart:async';

import 'package:aiko/core/storage/file_sync_queue.dart';
import 'package:aiko/core/storage/local_file_cache.dart';
import 'package:aiko/features/auth/data/account_file_jobs.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../core/storage/file_store_harness.dart';

FileJob _job(String id, {String owner = 'uid-1'}) =>
    FileJob(id: id, ownerId: owner, kind: 'upload', data: {'name': id});

void main() {
  late Database db;
  late FileSyncQueue queue;
  late AccountFileJobs jobs;
  late List<String> ran;

  setUp(() async {
    db = await openMemoryFileCache();
    queue = testQueue(FakeRemoteFileStore());
    jobs = AccountFileJobs(queue);
    ran = [];
    queue.register('upload', (job, run) async => ran.add(job.id));
  });

  tearDown(() async {
    await queue.dispose();
    await closeMemoryFileCache(db);
  });

  group('waiting', () {
    test('false when the account has nothing queued', () async {
      await queue.enqueue(_job('theirs', owner: 'uid-2'));

      expect(await jobs.waiting('uid-1', timeout: Duration.zero), isFalse);
    });

    test('false once the queued files uploaded in time', () async {
      await queue.enqueue(_job('a'));

      expect(
        await jobs.waiting('uid-1', timeout: const Duration(seconds: 1)),
        isFalse,
      );
      expect(ran, ['a']);
    });

    test('true while a file can\'t upload (offline)', () async {
      queue.register(
        'upload',
        (job, run) async => throw FakeRemoteFileStore.offline,
      );
      await queue.enqueue(_job('a'));

      expect(
        await jobs.waiting('uid-1', timeout: const Duration(seconds: 1)),
        isTrue,
      );
    });
  });

  group('around deleting the account', () {
    test('holding runs none of the waiting jobs, although the queue starts '
        'passes by itself, and they run once released', () async {
      await queue.enqueue(_job('a'));
      await queue.enqueue(_job('b'));
      // The app's queue: queueing or removing work starts a pass.
      final app = FileSyncQueue(
        remote: FakeRemoteFileStore(),
        signedInUserId: () => 'uid-1',
        retryDelay: (_) => null,
      )..register('upload', (job, run) async => ran.add(job.id));
      addTearDown(app.dispose);
      final appJobs = AccountFileJobs(app);

      expect(await appJobs.hold(), isTrue);
      // Queueing or removing work while held starts no job either.
      await app.enqueue(_job('c'));
      await app.remove('b');
      await pumpEventQueue();

      expect(ran, isEmpty);
      expect((await app.pending()).map((job) => job.id), ['a', 'c']);

      appJobs.release();
      await app.process();
      expect(ran, ['a', 'c']);
    });

    test('lets the upload that is running finish first, and starts no '
        'other', () async {
      final upload = Completer<void>();
      queue.register('upload', (job, run) async {
        ran.add(job.id);
        await upload.future;
      });
      await queue.enqueue(_job('a'));
      await queue.enqueue(_job('b'));
      final pass = queue.process();
      await pumpEventQueue();

      final hold = jobs.hold();
      var held = false;
      unawaited(hold.then((_) => held = true));
      await pumpEventQueue();
      expect(held, isFalse);

      upload.complete();
      await pass;
      expect(await hold, isTrue);
      expect(ran, ['a']);
      expect((await queue.pending()).map((job) => job.id), ['b']);
    });

    test('gives up, with the queue running again, when a running upload '
        'doesn\'t finish', () async {
      final upload = Completer<void>();
      queue.register('upload', (job, run) async {
        ran.add(job.id);
        if (job.id == 'a') await upload.future;
      });
      await queue.enqueue(_job('a'));
      await queue.enqueue(_job('b'));
      final pass = queue.process();
      await pumpEventQueue();

      expect(await jobs.hold(timeout: Duration.zero), isFalse);

      expect(await queue.pendingCount('uid-1'), 2);
      upload.complete();
      await pass;
      expect(ran, ['a', 'b']);
      expect(await queue.pendingCount('uid-1'), 0);
    });

    test('forgets what the deleted account kept on this device', () async {
      await queue.enqueue(_job('a'));
      await queue.enqueue(_job('theirs', owner: 'uid-2'));
      for (final owner in ['uid-1', 'uid-2']) {
        await db.insert('attachments', {
          'id': 'attachment-$owner',
          'owner_id': owner,
          'transaction_id': 't',
          'data': '{}',
          'created_at': '2026-06-01T00:00:00.000Z',
        });
        await LocalFileCache.write('avatars/$owner/photo.jpg', [1]);
        await LocalFileCache.write('receipts/users/$owner/receipts/r/r.jpg', [
          2,
        ]);
      }

      await jobs.forget('uid-1');

      expect(await queue.pendingCount('uid-1'), 0);
      expect(await queue.pendingCount('uid-2'), 1);
      expect((await db.query('attachments')).map((row) => row['owner_id']), [
        'uid-2',
      ]);
      expect(
        (await db.query('files', columns: ['path'])).map((row) => row['path']),
        unorderedEquals([
          '${LocalFileCache.pathPrefix}avatars/uid-2/photo.jpg',
          '${LocalFileCache.pathPrefix}receipts/users/uid-2/receipts/r/r.jpg',
        ]),
      );
    });
  });
}
