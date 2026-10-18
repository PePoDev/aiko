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

  test('other failures are counted; at the limit the job fails for good, '
      'is reported and waits for the next launch', () async {
    var runs = 0;
    queue.register('broken', (job, run) async {
      runs++;
      throw StateError('rejected');
    });
    final failures = <Object>[];
    final subscription = queue.failures.listen(failures.add);
    await queue.enqueue(_job('broken', kind: 'broken'));
    await queue.enqueue(_job('fine'));

    await queue.process();
    // A rejection doesn't hold up the rest.
    expect(ran, ['fine']);
    expect((await queue.pending()).single.attempts, 1);

    for (var i = 1; i < FileSyncQueue.maxAttempts; i++) {
      await queue.process();
    }
    await pumpEventQueue();
    final failed = (await queue.pending()).single;
    expect(failed.failed, isTrue);
    expect(failures.single, isA<StateError>());
    expect(await queue.counts('uid-1'), (pending: 1, failed: 1));
    expect(await queue.pendingCount('uid-1'), 1);

    // Not run again on this launch...
    await queue.process();
    expect(runs, FileSyncQueue.maxAttempts);

    // ...but the next launch gives it another set of tries.
    final relaunched = testQueue(remote);
    relaunched.register('broken', (job, run) async => runs++);
    await relaunched.process();
    expect(runs, FileSyncQueue.maxAttempts + 1);
    expect(await relaunched.pending(), isEmpty);
    await subscription.cancel();
    await relaunched.dispose();
  });

  test('a delete that keeps failing is dropped at the limit', () async {
    remote.failure = StateError('rejected');
    await queue.enqueueDelete('uid-1', 'users/uid-1/receipts/r1/a.jpg');

    for (var i = 0; i < FileSyncQueue.maxAttempts; i++) {
      await queue.process();
    }

    expect(await queue.pending(), isEmpty);
  });

  test('queueing a failed job again gives it a fresh start', () async {
    queue.register('broken', (job, run) async => throw StateError('no'));
    await queue.enqueue(_job('a', kind: 'broken'));
    for (var i = 0; i < FileSyncQueue.maxAttempts; i++) {
      await queue.process();
    }
    expect((await queue.job('a'))!.failed, isTrue);

    await queue.enqueue(_job('a', kind: 'broken'));

    expect((await queue.job('a'))!.attempts, 0);
    expect(await queue.counts('uid-1'), (pending: 1, failed: 0));
  });

  test('a job whose owner signed out while it ran waits for them, '
      'without counting an attempt', () async {
    String? signedIn = 'uid-1';
    final perUser = testQueue(remote, signedInUserId: () => signedIn);
    var runs = 0;
    perUser.register('write', (job, run) async {
      runs++;
      if (runs == 1) signedIn = null; // Logged out during the upload.
      run.checkOwner();
    });
    await perUser.enqueue(_job('a', kind: 'write'));
    await perUser.enqueue(_job('b', kind: 'write'));

    await perUser.process();
    final waiting = await perUser.pending();
    expect(waiting.map((job) => job.id), ['a', 'b']);
    expect(waiting.first.attempts, 0);

    signedIn = 'uid-1';
    await perUser.process();
    expect(await perUser.pending(), isEmpty);
    await perUser.dispose();
  });

  test(
    'suspend waits for the running job and holds passes until resume',
    () async {
      final started = Completer<void>();
      final release = Completer<void>();
      queue.register('slow', (job, run) async {
        ran.add(job.id);
        started.complete();
        await release.future;
      });
      await queue.enqueue(_job('first', kind: 'slow'));
      await queue.enqueue(_job('second'));

      unawaited(queue.process());
      await started.future;
      var suspended = false;
      final suspending = queue.suspend().then((_) => suspended = true);
      await pumpEventQueue();
      expect(suspended, isFalse);

      release.complete();
      await suspending;
      // The running job finished; the next one didn't start.
      expect(ran, ['first']);
      await queue.process();
      expect(ran, ['first']);
      expect((await queue.pending()).single.id, 'second');

      queue.resume();
      await queue.process();
      expect(ran, ['first', 'second']);
    },
  );

  test('coming back online runs a pass at once with a fresh backoff', () async {
    final rounds = <int>[];
    final backoff = FileSyncQueue(
      remote: remote,
      signedInUserId: () => 'uid-1',
      retryDelay: (round) {
        rounds.add(round);
        return null;
      },
      autoProcess: false,
    );
    var offline = true;
    var runs = 0;
    backoff.register('upload', (job, run) async {
      runs++;
      if (offline) throw FakeRemoteFileStore.offline;
    });
    await backoff.enqueue(_job('a', kind: 'upload'));
    await backoff.process();
    await backoff.process();
    expect(rounds, [0, 1]);

    final online = StreamController<bool>();
    final subscription = backoff.followNetwork(online.stream);
    online.add(false);
    await pumpEventQueue();
    expect(runs, 2);

    offline = false;
    online.add(true);
    await pumpEventQueue();
    expect(runs, 3);
    expect(await backoff.pending(), isEmpty);

    // Still online (another network): no extra pass.
    online.add(true);
    await pumpEventQueue();
    expect(runs, 3);

    // Back to the first delay after the next failure.
    offline = true;
    await backoff.enqueue(_job('b', kind: 'upload'));
    await backoff.process();
    expect(rounds, [0, 1, 0]);
    await subscription.cancel();
    await online.close();
    await backoff.dispose();
  });

  group('an upload in progress', () {
    late StreamController<bool> online;
    late StreamController<String?> users;
    late String? signedIn;
    late FileSyncQueue uploads;

    setUp(() {
      online = StreamController<bool>();
      users = StreamController<String?>();
      signedIn = 'uid-1';
      uploads = FileSyncQueue(
        remote: remote,
        signedInUserId: () => signedIn,
        retryDelay: (_) => null,
        autoProcess: false,
      );
      uploads.register(
        'upload',
        (job, run) => remote.put(
          'users/${job.ownerId}/${job.id}',
          Uint8List(1),
          contentType: 'image/png',
        ),
      );
      uploads.followNetwork(online.stream);
      uploads.followUser(users.stream);
    });

    tearDown(() async {
      final hold = remote.holdUploads;
      if (hold != null && !hold.isCompleted) hold.complete();
      await online.close();
      await users.close();
      await uploads.dispose();
    });

    Future<void> startUploading() async {
      remote.holdUploads = Completer<void>();
      await uploads.enqueue(_job('a', kind: 'upload'));
      await uploads.enqueue(_job('b', kind: 'upload'));
      unawaited(uploads.process());
      await pumpEventQueue();
      expect(remote.calls, ['put users/uid-1/a']);
    }

    test('starts again at once when the device is back online, instead of '
        "waiting out Storage's own retries", () async {
      online.add(true);
      await pumpEventQueue();
      await startUploading();

      online.add(false);
      await pumpEventQueue();
      expect(remote.cancelled, 0);

      online.add(true);
      await pumpEventQueue();
      expect(remote.cancelled, 1);
      // The same job again, first in line, with no attempt counted.
      expect(remote.calls, ['put users/uid-1/a', 'put users/uid-1/a']);
      final waiting = await uploads.pending();
      expect(waiting.map((job) => job.id), ['a', 'b']);
      expect(waiting.first.attempts, 0);

      remote.holdUploads!.complete();
      await uploads.process();
      expect(await uploads.pending(), isEmpty);
      expect(remote.files.keys, ['users/uid-1/a', 'users/uid-1/b']);
    });

    test(
      'keeps going when the network is first reported, or still there',
      () async {
        await startUploading();

        online.add(true);
        await pumpEventQueue();
        online.add(true);
        await pumpEventQueue();

        expect(remote.cancelled, 0);
        expect(remote.calls, ['put users/uid-1/a']);
      },
    );

    test('is cancelled when its owner signs out; the job waits for them, '
        'unchanged', () async {
      users.add('uid-1');
      await startUploading();

      signedIn = null;
      users.add(null);
      await pumpEventQueue();

      expect(remote.cancelled, 1);
      expect(remote.files, isEmpty);
      final waiting = await uploads.pending();
      expect(waiting.map((job) => job.id), ['a', 'b']);
      expect(waiting.first.attempts, 0);

      // Back again: uploaded once.
      remote.holdUploads!.complete();
      remote.holdUploads = null;
      signedIn = 'uid-1';
      users.add('uid-1');
      await pumpEventQueue();
      await uploads.process();
      expect(await uploads.pending(), isEmpty);
      expect(
        remote.calls.where((call) => call == 'put users/uid-1/a'),
        hasLength(2),
      );
      expect(remote.files.keys, ['users/uid-1/a', 'users/uid-1/b']);
    });
  });

  test(
    'passes of queues sharing a lock (browser tabs) never overlap',
    () async {
      // One lock for both "tabs", like the browser's Web Lock.
      Future<void> lastPass = Future.value();
      Future<void> lock(Future<void> Function() pass) {
        final next = lastPass.then((_) => pass());
        lastPass = next.catchError((_) {});
        return next;
      }

      FileSyncQueue tab() => FileSyncQueue(
        remote: remote,
        signedInUserId: () => 'uid-1',
        retryDelay: (_) => null,
        exclusive: lock,
        autoProcess: false,
      );
      final tab1 = tab();
      final tab2 = tab();
      final runs = <String>[];
      var running = 0;
      var overlapped = false;
      for (final (name, queue) in [('tab1', tab1), ('tab2', tab2)]) {
        queue.register('upload', (job, run) async {
          if (++running > 1) overlapped = true;
          await Future<void>.delayed(const Duration(milliseconds: 20));
          runs.add('$name ${job.id}');
          running--;
        });
      }
      await tab1.enqueue(_job('a', kind: 'upload'));

      await Future.wait([tab1.process(), tab2.process()]);

      expect(overlapped, isFalse);
      expect(runs, ['tab1 a']);
      await tab1.dispose();
      await tab2.dispose();
    },
  );

  test('clearOwner forgets only that owner\'s jobs', () async {
    await queue.enqueue(_job('mine', owner: 'uid-1'));
    await queue.enqueue(_job('theirs', owner: 'uid-2'));

    await queue.clearOwner('uid-1');

    expect((await queue.pending()).single.id, 'theirs');
  });

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
