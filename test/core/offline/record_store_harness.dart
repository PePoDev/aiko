import 'package:aiko/core/offline/offline_store.dart';
import 'package:aiko/core/offline/offline_user_context.dart';
import 'package:aiko/core/storage/local_record_store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// A fresh, empty in-memory [LocalRecordStore] (SQLite through FFI).
Future<LocalRecordStore> openMemoryRecordStore() {
  sqfliteFfiInit();
  return LocalRecordStore.openAt(
    inMemoryDatabasePath,
    factory: databaseFactoryFfiNoIsolate,
  );
}

/// Resolves a fixed owner instead of reading secure storage.
class FixedUserContext implements OfflineUserContext {
  const FixedUserContext(this.userId);

  final String userId;

  @override
  Future<String> resolveUserId() async => userId;
}

/// A signed-out [OfflineStore] over [local] that remembers every committed
/// batch, and can be told to fail commits.
class RecordingStore extends OfflineStore {
  RecordingStore(LocalRecordStore local)
    : super(local: local, signedInUserId: () => null);

  final List<RecordBatch> commits = [];
  bool failCommits = false;

  @override
  Future<void> commit(
    RecordBatch batch, {
    bool localOnly = false,
    bool allowChunks = false,
    void Function(Object error)? onRejected,
  }) async {
    if (batch.isEmpty) return;
    commits.add(batch);
    if (failCommits) throw StateError('commit failed');
    await super.commit(
      batch,
      localOnly: localOnly,
      allowChunks: allowChunks,
      onRejected: onRejected,
    );
  }
}
