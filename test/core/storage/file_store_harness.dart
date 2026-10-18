import 'dart:async';
import 'dart:typed_data';

import 'package:aiko/core/storage/file_sync_queue.dart';
import 'package:aiko/core/storage/local_file_cache.dart';
import 'package:aiko/core/storage/remote_file_store.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Makes a fresh, empty in-memory database the [LocalFileCache] (and so the
/// file queue and attachment metadata) for one test. Close it afterwards
/// with [closeMemoryFileCache].
Future<Database> openMemoryFileCache() async {
  sqfliteFfiInit();
  final db = await LocalFileCache.openAt(
    inMemoryDatabasePath,
    factory: databaseFactoryFfiNoIsolate,
  );
  LocalFileCache.useDatabase(db);
  return db;
}

Future<void> closeMemoryFileCache(Database db) async {
  LocalFileCache.useDatabase(null);
  await db.close();
}

/// A queue for tests: no automatic passes and no retry timer.
FileSyncQueue testQueue(
  FakeRemoteFileStore remote, {
  String? Function()? signedInUserId,
}) => FileSyncQueue(
  remote: remote,
  signedInUserId: signedInUserId ?? () => 'uid-1',
  retryDelay: (_) => null,
  autoProcess: false,
);

/// Firebase Storage in memory. [failure] makes every call throw it.
class FakeRemoteFileStore implements RemoteFileStore {
  final files = <String, Uint8List>{};
  final contentTypes = <String, String>{};
  final calls = <String>[];
  Object? failure;

  /// While set, uploads wait for it (like an upload between Storage's own
  /// retries) unless [cancelUploads] cancels them.
  Completer<void>? holdUploads;
  final _uploading = <Completer<void>>{};

  /// How many uploads [cancelUploads] cancelled.
  var cancelled = 0;

  /// An error that [isTransientFileError] treats as "offline".
  static final offline = FirebaseException(
    plugin: 'firebase_storage',
    code: 'retry-limit-exceeded',
  );

  /// What a cancelled upload fails with.
  static final canceled = FirebaseException(
    plugin: 'firebase_storage',
    code: 'canceled',
  );

  void _check() {
    final error = failure;
    if (error != null) throw error;
  }

  @override
  Future<void> put(
    String path,
    Uint8List bytes, {
    required String contentType,
  }) async {
    calls.add('put $path');
    _check();
    final hold = holdUploads;
    if (hold != null) {
      final upload = Completer<void>();
      _uploading.add(upload);
      unawaited(
        hold.future.then((_) {
          if (!upload.isCompleted) upload.complete();
        }),
      );
      try {
        await upload.future;
      } finally {
        _uploading.remove(upload);
      }
    }
    files[path] = bytes;
    contentTypes[path] = contentType;
  }

  @override
  Future<Uint8List> get(
    String path, {
    required int maxBytes,
    int? sizeBytes,
  }) async {
    calls.add('get $path');
    _check();
    final bytes = files[path];
    if (bytes == null) {
      throw FirebaseException(
        plugin: 'firebase_storage',
        code: 'object-not-found',
      );
    }
    return bytes;
  }

  @override
  Future<void> delete(String path) async {
    calls.add('delete $path');
    _check();
    files.remove(path);
  }

  @override
  Future<String> downloadUrl(String path) async {
    _check();
    return 'https://files.test/$path';
  }

  @override
  String? pathOf(String url) => url.startsWith('https://files.test/')
      ? url.substring('https://files.test/'.length)
      : null;

  @override
  bool cancelUploads() {
    final running = _uploading.where((upload) => !upload.isCompleted);
    if (running.isEmpty) return false;
    for (final upload in running.toList()) {
      cancelled++;
      upload.completeError(canceled);
    }
    return true;
  }
}
