import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:sqflite/sqflite.dart'
    show ConflictAlgorithm, Database, DatabaseExecutor;

import '../connectivity/network_status.dart';
import '../firebase/firebase_backend.dart';
import 'exclusive_lock.dart';
import 'local_file_cache.dart';
import 'remote_file_store.dart';

/// One upload to or delete from Firebase Storage that is waiting to run.
class FileJob {
  const FileJob({
    required this.id,
    required this.ownerId,
    required this.kind,
    this.data = const {},
    this.seq = 0,
    this.attempts = 0,
  });

  /// One job per id: enqueueing the same id again replaces the waiting job.
  final String id;

  /// The user whose files these are; jobs run only while they are signed in.
  final String ownerId;

  /// Which registered handler runs it.
  final String kind;
  final Map<String, dynamic> data;

  /// Queue position, assigned when the job is stored.
  final int seq;

  /// Failed runs so far that were not just a missing connection.
  final int attempts;

  /// Ran out of attempts ([FileSyncQueue.maxAttempts]): it stays queued, but
  /// passes skip it until the next launch or until it is queued again.
  bool get failed => attempts >= FileSyncQueue.maxAttempts;

  static FileJob _fromRow(Map<String, Object?> row) => FileJob(
    id: row['id']! as String,
    ownerId: row['owner_id']! as String,
    kind: row['kind']! as String,
    data: (jsonDecode(row['data']! as String) as Map).cast<String, dynamic>(),
    seq: row['seq']! as int,
    attempts: row['attempts']! as int,
  );
}

/// Runs one job. Completing means done (the job is removed). Throwing an
/// error that [isTransientFileError] accepts keeps the job for a later pass,
/// [FileOwnerSignedOut] keeps it until its owner signs in again, and any
/// other error counts as a failed attempt.
typedef FileJobHandler = Future<void> Function(FileJob job, FileJobRun run);

/// The job's owner is no longer the signed-in user (signed out or switched
/// account while it ran). The job waits, unchanged, for them.
class FileOwnerSignedOut implements Exception {
  const FileOwnerSignedOut();
}

/// What a running handler can ask the queue.
class FileJobRun {
  FileJobRun._(this.queue, this.job);

  final FileSyncQueue queue;
  final FileJob job;

  /// Whether the job is still the one waiting: false when it was replaced or
  /// removed while it ran (for example, the file was deleted meanwhile, or
  /// another browser tab ran it first).
  Future<bool> isCurrent() async {
    final db = await queue._database();
    final rows = await db.query(
      'file_jobs',
      columns: const ['seq'],
      where: 'id = ?',
      whereArgs: [job.id],
    );
    return rows.isNotEmpty && rows.single['seq'] == job.seq;
  }

  /// Throws [FileOwnerSignedOut] unless the job's owner is still signed in.
  /// Call it right before a write that goes out as the signed-in user
  /// (Firestore, the profile), with no await in between: after a sign-out
  /// that write would be refused, or land in someone else's data.
  void checkOwner() {
    if (queue._signedInUserId() != job.ownerId) {
      throw const FileOwnerSignedOut();
    }
  }
}

/// Persistent queue of Firebase Storage uploads and deletes, so saving a file
/// never waits for the network.
///
/// Jobs live in the `file_jobs` table of [LocalFileCache]'s database, per
/// owner, and survive restarts. While their owner is signed in, a pass runs
/// them in queue order: at launch and sign-in, when the app resumes, when the
/// device comes back online, when new work is queued, on [process], and on a
/// backoff timer after a failure. Passes never overlap, not even across
/// browser tabs (which share the database). A job that fails for want of a
/// connection moves to the back and ends the pass; one that fails otherwise
/// is retried until [maxAttempts], then waits as [FileJob.failed] (reported
/// on [failures]) until the next launch or until it is queued again.
class FileSyncQueue {
  FileSyncQueue({
    Future<Database> Function()? database,
    RemoteFileStore? remote,
    String? Function()? signedInUserId,
    Duration? Function(int round)? retryDelay,
    Future<void> Function(Future<void> Function() pass)? exclusive,
    this.autoProcess = true,
  }) : _database = database ?? LocalFileCache.database,
       remote = remote ?? const FirebaseRemoteFileStore(),
       _signedInUserId = signedInUserId ?? (() => FirebaseBackend.userId),
       _retryDelay = retryDelay ?? defaultRetryDelay,
       _exclusive = exclusive ?? ((pass) => runExclusive(_lockName, pass)) {
    register(deleteKind, _runDelete, keepFailed: false);
  }

  /// The app's queue.
  static final instance = FileSyncQueue();

  /// Kind of the built-in job that deletes `data['path']` from Storage.
  static const deleteKind = 'storage-delete';

  /// Failed runs (other than a missing connection) before a job is
  /// [FileJob.failed].
  static const maxAttempts = 5;

  /// The Web Lock that keeps passes of several tabs from overlapping.
  static const _lockName = 'aiko-file-sync';

  final Future<Database> Function() _database;
  final RemoteFileStore remote;
  final String? Function() _signedInUserId;
  final Duration? Function(int round) _retryDelay;
  final Future<void> Function(Future<void> Function() pass) _exclusive;

  /// Whether queueing work starts a pass (tests turn it off).
  final bool autoProcess;

  final _handlers = <String, FileJobHandler>{};
  final _keepFailed = <String>{};
  final _changes = StreamController<void>.broadcast();
  final _failures = StreamController<Object>.broadcast();
  Future<void>? _running;
  bool _again = false;
  Timer? _retryTimer;
  int _retryRound = 0;
  bool _started = false;
  bool _suspended = false;
  bool _retriedFailed = false;

  /// 30 s after the first failing pass, doubling to at most 15 minutes.
  static Duration defaultRetryDelay(int round) =>
      Duration(seconds: min(30 * pow(2, round).toInt(), 15 * 60));

  /// Fires whenever jobs are added, finish, fail for good or are removed.
  Stream<void> get changes => _changes.stream;

  /// The last error of each job that runs out of attempts.
  Stream<Object> get failures => _failures.stream;

  /// Registers the handler that runs jobs of [kind]. A job of a kind that
  /// doesn't [keepFailed] is dropped, not kept, when it runs out of attempts.
  void register(String kind, FileJobHandler handler, {bool keepFailed = true}) {
    _handlers[kind] = handler;
    keepFailed ? _keepFailed.add(kind) : _keepFailed.remove(kind);
  }

  /// Starts passes for the signed-in user at sign-in (and now, when already
  /// signed in), on app resume and when the device is back online. Does
  /// nothing in builds without Firebase. Safe to call more than once.
  void start() {
    if (_started) return;
    final auth = FirebaseBackend.auth;
    if (auth == null) return;
    _started = true;
    FirebaseRemoteFileStore.configureRetries(FirebaseBackend.storage);
    auth.authStateChanges().listen((user) {
      if (user != null) unawaited(process());
    });
    WidgetsBinding.instance.addObserver(_ResumeObserver(this));
    followNetwork(const PlatformNetworkMonitor().onlineChanges);
  }

  /// Runs a pass with a fresh backoff whenever [online] reports the device
  /// back online, instead of waiting for the backoff timer.
  StreamSubscription<bool> followNetwork(Stream<bool> online) {
    bool? wasOnline;
    return online.listen((isOnline) {
      if (isOnline && wasOnline != true) retryNow();
      wasOnline = isOnline;
    });
  }

  /// Runs a pass now, with the backoff reset (the device is back online).
  void retryNow() {
    _retryRound = 0;
    unawaited(process());
  }

  /// Stops running jobs until [resume]: no pass or job starts meanwhile. The
  /// returned future completes once the job running now (if any) is done,
  /// for example before deleting the account, so that no upload lands after
  /// the server deleted everything.
  Future<void> suspend() async {
    _suspended = true;
    _retryTimer?.cancel();
    _retryTimer = null;
    await _running;
  }

  /// Runs jobs again after [suspend], starting with a pass now.
  void resume() {
    if (!_suspended) return;
    _suspended = false;
    unawaited(process());
  }

  /// Queues [job], replacing a waiting job with the same id, and starts a
  /// pass. Pass [txn] to write inside the caller's transaction on this
  /// database; the caller then calls [process] after it commits.
  Future<void> enqueue(FileJob job, {DatabaseExecutor? txn}) async {
    if (txn != null) {
      await _insert(txn, job);
      return;
    }
    final db = await _database();
    await db.transaction((txn) => _insert(txn, job));
    _changed();
  }

  /// Queues deleting [path] from Storage once [ownerId] is signed in.
  Future<void> enqueueDelete(
    String ownerId,
    String path, {
    DatabaseExecutor? txn,
  }) => enqueue(
    FileJob(
      id: 'delete:$path',
      ownerId: ownerId,
      kind: deleteKind,
      data: {'path': path},
    ),
    txn: txn,
  );

  static Future<void> _insert(DatabaseExecutor txn, FileJob job) async {
    final last = await txn.rawQuery(
      'SELECT COALESCE(MAX(seq), 0) AS seq FROM file_jobs',
    );
    await txn.insert('file_jobs', {
      'id': job.id,
      'owner_id': job.ownerId,
      'kind': job.kind,
      'data': jsonEncode(job.data),
      'seq': (last.single['seq']! as int) + 1,
      'attempts': 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Removes the waiting job [id], if any. A run already in progress finds
  /// out through [FileJobRun.isCurrent].
  Future<void> remove(String id, {DatabaseExecutor? txn}) async {
    final executor = txn ?? await _database();
    await executor.delete('file_jobs', where: 'id = ?', whereArgs: [id]);
    if (txn == null) _changed();
  }

  /// Forgets every waiting job of [ownerId] (their account was deleted).
  Future<void> clearOwner(String ownerId, {DatabaseExecutor? txn}) async {
    final executor = txn ?? await _database();
    await executor.delete(
      'file_jobs',
      where: 'owner_id = ?',
      whereArgs: [ownerId],
    );
    if (txn == null) _changed();
  }

  /// The waiting job [id], if any.
  Future<FileJob?> job(String id) async {
    final db = await _database();
    final rows = await db.query('file_jobs', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : FileJob._fromRow(rows.single);
  }

  /// Waiting jobs in the order they run, only [ownerId]'s when given. They
  /// include [FileJob.failed] ones.
  Future<List<FileJob>> pending({String? ownerId}) async {
    final db = await _database();
    final rows = await db.query(
      'file_jobs',
      where: ownerId == null ? null : 'owner_id = ?',
      whereArgs: ownerId == null ? null : [ownerId],
      orderBy: 'seq, id',
    );
    return rows.map(FileJob._fromRow).toList(growable: false);
  }

  /// How many uploads and deletes are waiting for [ownerId], including
  /// [FileJob.failed] ones.
  Future<int> pendingCount(String ownerId) async =>
      (await counts(ownerId)).pending;

  /// How many of [ownerId]'s jobs are waiting ([pendingCount]) and how many
  /// of those are [FileJob.failed].
  Future<({int pending, int failed})> counts(String ownerId) async {
    final db = await _database();
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS n, '
      'COALESCE(SUM(CASE WHEN attempts >= ? THEN 1 ELSE 0 END), 0) AS failed '
      'FROM file_jobs WHERE owner_id = ?',
      [maxAttempts, ownerId],
    );
    final row = rows.single;
    return (pending: row['n']! as int, failed: row['failed']! as int);
  }

  /// Tell listeners the queue changed (after a transaction that called
  /// [enqueue] or [remove] with `txn`), and start a pass.
  void notifyChanged() => _changed();

  void _changed() {
    if (!_changes.isClosed) _changes.add(null);
    if (autoProcess) unawaited(process());
  }

  /// Runs the signed-in user's waiting jobs. A call during a pass makes that
  /// pass run once more instead of starting a second one.
  Future<void> process() {
    _retryTimer?.cancel();
    _retryTimer = null;
    final running = _running;
    if (_suspended) return running ?? Future.value();
    if (running != null) {
      _again = true;
      return running;
    }
    return _running = _exclusive(_drain).whenComplete(() => _running = null);
  }

  Future<void> _drain() async {
    do {
      _again = false;
      await _pass();
    } while (_again && !_suspended);
  }

  Future<void> _pass() async {
    final uid = _signedInUserId();
    if (uid == null || uid.isEmpty || _suspended) return;
    var failed = false;
    try {
      if (!_retriedFailed) {
        // Each launch gives jobs that failed for good another set of tries.
        _retriedFailed = true;
        await _retryFailed();
      }
      for (final job in await pending(ownerId: uid)) {
        // Signed out (or switched user) mid-pass: leave the rest for later.
        if (_suspended || _signedInUserId() != uid) return;
        final handler = _handlers[job.kind];
        if (handler == null || job.failed) continue;
        try {
          await handler(job, FileJobRun._(this, job));
          await _finish(job);
        } on FileOwnerSignedOut {
          // Signed out while it ran: it runs again when they are back.
          return;
        } catch (error) {
          failed = true;
          if (isTransientFileError(error)) {
            // Most likely offline: the rest would fail the same way. Going
            // to the back lets the next pass start with another job.
            await _moveToBack(job);
            break;
          }
          await _recordFailure(job, error);
        }
      }
    } catch (error) {
      failed = true;
      if (kDebugMode) debugPrint('[aiko-files] queue pass failed: $error');
    }
    if (!failed) {
      _retryRound = 0;
      return;
    }
    final delay = _retryDelay(_retryRound++);
    if (delay != null) _retryTimer = Timer(delay, () => unawaited(process()));
  }

  Future<void> _finish(FileJob job) async {
    final db = await _database();
    await db.delete(
      'file_jobs',
      where: 'id = ? AND seq = ?',
      whereArgs: [job.id, job.seq],
    );
    if (!_changes.isClosed) _changes.add(null);
  }

  Future<void> _moveToBack(FileJob job) async {
    final db = await _database();
    await db.transaction((txn) async {
      final last = await txn.rawQuery(
        'SELECT COALESCE(MAX(seq), 0) AS seq FROM file_jobs',
      );
      await txn.update(
        'file_jobs',
        {'seq': (last.single['seq']! as int) + 1},
        where: 'id = ? AND seq = ?',
        whereArgs: [job.id, job.seq],
      );
    });
  }

  Future<void> _recordFailure(FileJob job, Object error) async {
    if (kDebugMode) {
      debugPrint('[aiko-files] ${job.kind} ${job.id} failed: $error');
    }
    final attempts = job.attempts + 1;
    if (attempts < maxAttempts || _keepFailed.contains(job.kind)) {
      final db = await _database();
      await db.update(
        'file_jobs',
        {'attempts': attempts},
        where: 'id = ? AND seq = ?',
        whereArgs: [job.id, job.seq],
      );
    } else {
      await _finish(job);
    }
    if (attempts < maxAttempts) return;
    if (!_changes.isClosed) _changes.add(null);
    if (!_failures.isClosed) _failures.add(error);
  }

  /// Gives every [FileJob.failed] job a fresh set of attempts.
  Future<void> _retryFailed() async {
    final db = await _database();
    final retried = await db.update(
      'file_jobs',
      {'attempts': 0},
      where: 'attempts >= ?',
      whereArgs: [maxAttempts],
    );
    if (retried > 0 && !_changes.isClosed) _changes.add(null);
  }

  Future<void> _runDelete(FileJob job, FileJobRun run) =>
      remote.delete(job.data['path'] as String);

  /// Stops the retry timer and closes [changes] and [failures] (tests).
  @visibleForTesting
  Future<void> dispose() async {
    _retryTimer?.cancel();
    await _running;
    await _changes.close();
    await _failures.close();
  }
}

class _ResumeObserver with WidgetsBindingObserver {
  _ResumeObserver(this.queue);

  final FileSyncQueue queue;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(queue.process());
  }
}
