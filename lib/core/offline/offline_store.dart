import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' as cloud;

import '../firebase/firebase_backend.dart';
import '../storage/local_record_store.dart';
import 'firestore_sync_state.dart';
import 'record_batch.dart';
import 'record_query.dart';
import 'records/record_codec.dart';

export 'record_batch.dart';
export 'record_query.dart';

/// Reads and writes records where they live. Signed in, that is Firestore:
/// its persistent cache is the device copy and its write queue uploads
/// offline changes when the device is back online. Signed out (guests and
/// local-only builds), it is the [LocalRecordStore].
///
/// Signed-in writes return as soon as they are handed to the Firestore SDK,
/// which applies them to its cache straight away; they never wait for the
/// server. A later rejection is reported on [errors].
class OfflineStore {
  /// [local], [firestore] and [signedInUserId] default to the app's store,
  /// Firebase and the Firebase user; tests replace them.
  OfflineStore({
    LocalRecordStore? local,
    cloud.FirebaseFirestore? firestore,
    String? Function()? signedInUserId,
  }) : _local = local,
       _firestore = firestore,
       _signedInUserId = signedInUserId ?? (() => FirebaseBackend.userId);

  final LocalRecordStore? _local;
  final cloud.FirebaseFirestore? _firestore;
  final String? Function() _signedInUserId;

  /// Failures of writes that were handed to the SDK (and of sync listeners);
  /// the signed-in shell tells the user.
  static final errors = StreamController<Object>.broadcast();

  /// The most writes one Firestore batch may hold.
  static const maxBatchWrites = 500;

  LocalRecordStore get _localStore => _local ?? LocalRecordStore.instance;

  String? get _uid {
    final uid = _signedInUserId();
    return uid == null || uid.isEmpty ? null : uid;
  }

  /// Whether records are read from and written to Firestore.
  bool get canSyncRemote => _uid != null;

  cloud.CollectionReference<Map<String, dynamic>> _collection(String name) {
    final firestore = _firestore;
    if (firestore == null) return FirebaseBackend.collection(name);
    final uid = _uid;
    if (uid == null) throw StateError('Sign in to synchronize your data.');
    return firestore.collection('users').doc(uid).collection(name);
  }

  /// The [T] records matching [query]. [localOnly] reads the local store even
  /// when signed in (claiming guest records after sign-in).
  Future<List<T>> get<T extends OfflineRecord>({
    RecordQuery? query,
    bool localOnly = false,
  }) async {
    final codec = RecordCodecs.of<T>();
    final collection = codec.collection;
    final uid = _uid;
    if (localOnly || uid == null) {
      final rows = await _localStore.rows(
        collection,
        ownerId: query?.ownerId,
        id: query?.id,
      );
      return [
        for (final row in query?.sortAndLimit(rows) ?? rows) codec.fromRow(row),
      ];
    }
    // Every signed-in collection lives under the user's own document.
    final ownerId = query?.ownerId;
    if (ownerId != null && ownerId != uid) return [];
    cloud.Query<Map<String, dynamic>> remote = _collection(collection);
    final id = query?.id;
    if (id != null) remote = remote.where('id', isEqualTo: id);
    final orderBy = query?.orderBy;
    if (orderBy != null) {
      remote = remote.orderBy(orderBy, descending: query!.descending);
    }
    final limit = query?.limit;
    if (limit != null) remote = remote.limit(limit);
    // The cache when the listener keeps it; the server only briefly, when the
    // cache can't answer yet ([FirestoreSyncState.readQuery]).
    final snapshot = await FirestoreSyncState.instance.readQuery(
      collection,
      remote,
    );
    return [for (final doc in snapshot.docs) codec.fromRow(doc.data())];
  }

  /// Stores [record] (insert or replace).
  Future<T> upsert<T extends OfflineRecord>(T record) async {
    await commit(RecordBatch()..upsert(record));
    return record;
  }

  /// Stores up to [maxBatchWrites] records as one atomic write. [onRejected]
  /// is told if the server later rejects it (signed in only).
  Future<void> upsertBatch<T extends OfflineRecord>(
    List<T> records, {
    void Function(Object error)? onRejected,
  }) async {
    final batch = RecordBatch();
    for (final record in records) {
      batch.upsert(record);
    }
    await commit(batch, onRejected: onRejected);
  }

  /// Deletes [record]. [localOnly] deletes the local copy even when signed in.
  Future<void> delete<T extends OfflineRecord>(
    T record, {
    bool localOnly = false,
  }) => commit(RecordBatch()..delete(record), localOnly: localOnly);

  /// Applies every write of [batch] or none: one Firestore WriteBatch signed
  /// in, one SQLite transaction otherwise ([localOnly] forces the latter).
  ///
  /// Signed in, a batch holds at most [maxBatchWrites] writes; with
  /// [allowChunks] a larger one is split into consecutive batches of that
  /// size, for operations that don't need to be atomic as a whole (put the
  /// writes that must land together last). Owners are checked before
  /// anything is written. [onRejected] is told if the server later rejects
  /// (a chunk of) the batch.
  Future<void> commit(
    RecordBatch batch, {
    bool localOnly = false,
    bool allowChunks = false,
    void Function(Object error)? onRejected,
  }) async {
    if (batch.isEmpty) return;
    final writes = batch.writes;
    final uid = _uid;
    if (localOnly || uid == null) {
      await _localStore.apply(writes);
      return;
    }
    if (writes.length > maxBatchWrites && !allowChunks) {
      throw ArgumentError.value(
        writes.length,
        'batch',
        'A batch holds at most $maxBatchWrites writes.',
      );
    }
    for (final write in writes) {
      final row = write.row;
      final owner = row == null ? write.ownerId : row['user_id'] ?? row['id'];
      if (owner != null && owner != uid) {
        throw StateError('Record owner does not match the signed-in user.');
      }
    }
    final firestore = _firestore ?? FirebaseBackend.firestore;
    for (var start = 0; start < writes.length; start += maxBatchWrites) {
      final end = start + maxBatchWrites < writes.length
          ? start + maxBatchWrites
          : writes.length;
      final remote = firestore.batch();
      for (final write in writes.sublist(start, end)) {
        final doc = _collection(write.collection).doc(write.id);
        final row = write.row;
        if (row == null) {
          remote.delete(doc);
        } else {
          remote.set(doc, row);
        }
      }
      await acceptWrite(remote.commit(), onError: onRejected);
    }
  }

  /// Hands a signed-in SDK write off without waiting for the server: the SDK
  /// applies it to its cache straight away and uploads it when online (also
  /// after a restart). A later failure goes to [errors] and [onError].
  static Future<void> acceptWrite(
    Future<void> write, {
    void Function(Object error)? onError,
  }) {
    // Counts as waiting to sync until the server acknowledges it.
    FirestoreSyncState.instance.trackWrite(write);
    unawaited(
      write.then<void>(
        (_) {},
        onError: (Object error) {
          errors.add(error);
          onError?.call(error);
        },
      ),
    );
    return Future<void>.value();
  }
}
