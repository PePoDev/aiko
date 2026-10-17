import 'dart:async';
import 'dart:typed_data';

import 'package:aiko/core/storage/file_sync_queue.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'file_store_harness.dart';

FileJob _job(String id, {String owner = 'uid-1', String kind = 'test'}) =>
    FileJob(id: id, ownerId: owner, kind: kind, data: {'name': id});

void main() {
  late Database db;
  late FakeRemoteFileStore remote;
  late FileSyncQueue queue;
  late List<String> ran;

  setUp(() async {
    db = await openMemoryFileCache();
    remote = FakeRemoteFileStore();
    queue = testQueue(remote);
    ran = [];
    queue.register('test', (job, run) async => ran.add(job.id));
  });

  tearDown(() async {
    await queue.dispose();
    await closeMemoryFileCache(db);
  });

  test('runs jobs in the order they were queued, then removes them', () async {
    await queue.enqueue(_job('a'));
    await queue.enqueue(_job('b'));
    await queue.enqueue(_job('c'));

    await queue.process();

    expect(ran, ['a', 'b', 'c']);
    expect(await queue.pending(), isEmpty);
  });

  test('queueing the same id again keeps one job, moved to the back', () async {
    await queue.enqueue(_job('a'));
    await queue.enqueue(_job('b'));
    await queue.enqueue(
      FileJob(id: 'a', ownerId: 'uid-1', kind: 'test', data: {'v': 2}),
    );

    final pending = await queue.pending();
    expect(pending.map((job) => job.id), ['b', 'a']);
    expect(pending.last.data, {'v': 2});
    expect(await queue.pendingCount('uid-1'), 2);
  });

  test('jobs survive a restart and run from a new queue', () async {
    await queue.enqueue(_job('a'));
    await queue.enqueue(_job('b'));

    final restarted = testQueue(remote);
    final ranAfterRestart = <String>[];
    restarted.register('test', (job, run) async => ranAfterRestart.add(job.id));
    await restarted.process();

    expect(ran, isEmpty);
    expect(ranAfterRestart, ['a', 'b']);
    expect(await restarted.pending(), isEmpty);
    await restarted.dispose();
  });

  test('runs only the signed-in owner\'s jobs, and none signed out', () async {
    String? signedIn;
    final perUser = testQueue(remote, signedInUserId: () => signedIn);
    final seen = <String>[];
    perUser.register('test', (job, run) async => seen.add(job.id));
    await perUser.enqueue(_job('mine', owner: 'uid-1'));
    await perUser.enqueue(_job('theirs', owner: 'uid-2'));
    await perUser.enqueue(_job('guest', owner: 'local:x'));

    await perUser.process();
    expect(seen, isEmpty);

    signedIn = 'uid-1';
    await perUser.process();
    expect(seen, ['mine']);
    expect(
      (await perUser.pending()).map((job) => job.ownerId),
      unorderedEquals(['uid-2', 'local:x']),
    );
    await perUser.dispose();
  });

  test(
    'an offline failure keeps the job, moves it back and ends the pass',
    () async {
      queue.register('flaky', (job, run) async {
        ran.add(job.id);
        throw FakeRemoteFileStore.offline;
      });
      await queue.enqueue(_job('offline', kind: 'flaky'));
      await queue.enqueue(_job('next'));

      await queue.process();

      // The second job waits for the next pass, which starts with it.
      expect(ran, ['offline']);
      final pending = await queue.pending();
      expect(pending.map((job) => job.id), ['next', 'offline']);
      expect(pending.last.attempts, 0);

      await queue.process();
      expect(ran, ['offline', 'next', 'offline']);
      expect((await queue.pending()).single.id, 'offline');
    },
  );

  test(
    'other failures are counted, and the job is dropped at the limit',
    () async {
      queue.register('broken', (job, run) async {
        throw StateError('rejected');
      });
      await queue.enqueue(_job('broken', kind: 'broken'));
      await queue.enqueue(_job('fine'));

      await queue.process();
      // A rejection doesn't hold up the rest.
      expect(ran, ['fine']);
      expect((await queue.pending()).single.attempts, 1);

      for (var i = 1; i < FileSyncQueue.maxAttempts; i++) {
        await queue.process();
      }
      expect(await queue.pending(), isEmpty);
    },
  );

  test('a job replaced while it ran stays queued', () async {
    final started = Completer<void>();
    final release = Completer<void>();
    final current = <bool>[];
    queue.register('slow', (job, run) async {
      started.complete();
      await release.future;
      current.add(await run.isCurrent());
    });
    await queue.enqueue(_job('a', kind: 'slow'));

    final pass = queue.process();
    await started.future;
    await queue.enqueue(_job('a', kind: 'slow'));
    release.complete();
    await pass;

    expect(current, [false]);
    expect((await queue.pending()).single.id, 'a');
  });

  test('a pass requested during a pass runs once more afterwards', () async {
    final release = Completer<void>();
    queue.register('slow', (job, run) async {
      ran.add(job.id);
      await release.future;
    });
    await queue.enqueue(_job('first', kind: 'slow'));

    final pass = queue.process();
    await pumpEventQueue();
    await queue.enqueue(_job('second'));
    final again = queue.process();
    expect(identical(again, pass), isTrue);
    release.complete();
    await pass;

    expect(ran, ['first', 'second']);
    expect(await queue.pending(), isEmpty);
  });

  test('delete jobs remove the file; one already gone is fine', () async {
    remote.files['users/uid-1/receipts/r1/a.jpg'] = Uint8List(1);
    await queue.enqueueDelete('uid-1', 'users/uid-1/receipts/r1/a.jpg');
    await queue.enqueueDelete('uid-1', 'users/uid-1/receipts/r1/a.jpg');
    await queue.enqueueDelete('uid-1', 'users/uid-1/avatars/gone.jpg');
    expect(await queue.pendingCount('uid-1'), 2);

    await queue.process();

    expect(remote.files, isEmpty);
    expect(remote.calls, [
      'delete users/uid-1/receipts/r1/a.jpg',
      'delete users/uid-1/avatars/gone.jpg',
    ]);
    expect(await queue.pending(), isEmpty);
  });

  test('an offline delete stays queued for later', () async {
    remote.failure = FakeRemoteFileStore.offline;
    await queue.enqueueDelete('uid-1', 'users/uid-1/receipts/r1/a.jpg');

    await queue.process();
    expect(await queue.pendingCount('uid-1'), 1);

    remote.failure = null;
    await queue.process();
    expect(await queue.pendingCount('uid-1'), 0);
  });

  test('jobs of a kind nobody handles wait', () async {
    await queue.enqueue(_job('later', kind: 'unknown'));
    await queue.process();
    expect((await queue.pending()).single.id, 'later');
  });

  test('changes fire when jobs are queued and finish', () async {
    var changes = 0;
    final subscription = queue.changes.listen((_) => changes++);
    await queue.enqueue(_job('a'));
    await queue.process();
    await pumpEventQueue();
    expect(changes, greaterThanOrEqualTo(2));
    await subscription.cancel();
  });
}
