import 'dart:async';

import 'package:aiko/core/storage/file_sync_queue.dart';
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
    test('takes the account\'s jobs off the queue, and puts them back if it '
        'stays', () async {
      await queue.enqueue(_job('a'));
      await queue.enqueue(_job('b'));
      await queue.enqueue(_job('theirs', owner: 'uid-2'));

      final held = await jobs.hold('uid-1');

      expect(held!.map((job) => job.id), ['a', 'b']);
      expect(ran, isEmpty);
      expect(await queue.pendingCount('uid-1'), 0);
      expect(await queue.pendingCount('uid-2'), 1);

      await jobs.release(held);
      expect((await queue.pending(ownerId: 'uid-1')).map((job) => job.id), [
        'a',
        'b',
      ]);
    });

    test('lets an upload that is running finish first', () async {
      final upload = Completer<void>();
      queue.register('upload', (job, run) async {
        ran.add(job.id);
        await upload.future;
      });
      await queue.enqueue(_job('a'));
      final pass = queue.process();
      await pumpEventQueue();

      final hold = jobs.hold('uid-1');
      var held = false;
      unawaited(hold.then((_) => held = true));
      await pumpEventQueue();
      expect(held, isFalse);

      upload.complete();
      await pass;
      expect(await hold, isNotNull);
      expect(ran, ['a']);
    });

    test('gives up, with the jobs back on the queue, when a running upload '
        'doesn\'t finish', () async {
      final upload = Completer<void>();
      queue.register('upload', (job, run) => upload.future);
      await queue.enqueue(_job('a'));
      await queue.enqueue(_job('b'));
      final pass = queue.process();
      await pumpEventQueue();

      final held = await jobs.hold('uid-1', timeout: Duration.zero);

      expect(held, isNull);
      expect(await queue.pendingCount('uid-1'), 2);
      upload.complete();
      await pass;
    });

    test('drops whatever the account still has queued', () async {
      await queue.enqueue(_job('a'));
      await queue.enqueue(_job('theirs', owner: 'uid-2'));

      await jobs.drop('uid-1');

      expect(await queue.pendingCount('uid-1'), 0);
      expect(await queue.pendingCount('uid-2'), 1);
    });
  });
}
