import 'dart:async';

import 'package:brick_sqlite/brick_sqlite.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as cloud;

import '../../brick/model_dictionary.dart';
import '../../brick/repository.dart';
import '../firebase/firebase_backend.dart';
import 'firestore_sync_state.dart';

/// Firebase owns authenticated persistence, cache, retry, and cross-device data.
/// SQLite remains available for local-only use and migration of existing data.
class OfflineStore {
  OfflineStore() : _repository = AikoBrickRepository();
  final AikoBrickRepository _repository;
  static final errors = StreamController<Object>.broadcast();

  bool get canSyncRemote => FirebaseBackend.userId != null;

  Future<List<T>> get<T extends SqliteModel>({
    Query? query,
    OfflineReadPolicy? policy,
  }) async {
    if (!canSyncRemote || policy == OfflineReadPolicy.localOnly) {
      return _repository.get<T>(query: query);
    }
    final adapter = firestoreAdapters[T]!;
    cloud.Query<Map<String, dynamic>> remote = FirebaseBackend.collection(
      adapter.collectionName,
    );
    for (final condition in query?.where ?? <WhereCondition>[]) {
      if (condition.conditions != null ||
          condition.compare != Compare.exact ||
          !condition.isRequired) {
        throw UnsupportedError(
          'This Firestore query requires an explicit repository mapping.',
        );
      }
      if (condition.evaluatedField == 'userId') {
        if (condition.value != FirebaseBackend.userId) return [];
        continue;
      }
      remote = remote.where(
        _field(condition.evaluatedField),
        isEqualTo: condition.value,
      );
    }
    for (final order in query?.orderBy ?? <OrderBy>[]) {
      remote = remote.orderBy(
        _field(order.evaluatedField),
        descending: !order.ascending,
      );
    }
    if (query?.limit != null) remote = remote.limit(query!.limit!);
    final sync = FirestoreSyncState.instance;
    final collection = adapter.collectionName;
    var snapshot = await remote.get(await sync.readOptions(collection));
    // An empty cache result before the listener has confirmed with the server
    // may just mean "not cached yet" (new device, slow network); ask the server
    // so callers never mistake it for "doesn't exist".
    if (snapshot.metadata.isFromCache &&
        snapshot.docs.isEmpty &&
        !sync.isServerSynced(collection)) {
      snapshot = await remote.get();
    }
    return Future.wait(
      snapshot.docs.map(
        (doc) async => await adapter.fromFirestore(doc.data()) as T,
      ),
    );
  }

  static String _field(String name) =>
      name.replaceAllMapped(RegExp('[A-Z]'), (m) => '_${m[0]!.toLowerCase()}');

  /// SDK writes are persisted before acknowledgement; offline saves should not
  /// wait indefinitely for a server. Late rejections are surfaced to the shell.
  static Future<void> acceptWrite(Future<void> write) async {
    final observed = write.catchError((Object error) {
      errors.add(error);
      throw error;
    });
    await observed.timeout(const Duration(seconds: 3), onTimeout: () {});
  }

  Future<T> upsert<T extends SqliteModel>(T model, {Query? query}) async {
    if (!canSyncRemote) return _repository.upsert<T>(model, query: query);
    final adapter = firestoreAdapters[T]!;
    final row = await adapter.toFirestore(model);
    final uid = FirebaseBackend.userId!;
    if ((row['user_id'] ?? row['id']) != uid) {
      throw StateError('Record owner does not match the signed-in user.');
    }
    await acceptWrite(
      FirebaseBackend.collection(
        adapter.collectionName,
      ).doc(row['id'] as String).set(row),
    );
    return model;
  }

  /// The most writes one Firestore batch may hold.
  static const maxBatchWrites = 500;

  /// Upserts up to [maxBatchWrites] models. Signed in, they are one Firestore
  /// batch with a single acknowledgement instead of one acknowledged write
  /// each; locally they are upserted one by one.
  Future<void> upsertBatch<T extends SqliteModel>(List<T> models) async {
    if (models.isEmpty) return;
    if (!canSyncRemote) {
      for (final model in models) {
        await _repository.upsert<T>(model);
      }
      return;
    }
    if (models.length > maxBatchWrites) {
      throw ArgumentError.value(
        models.length,
        'models',
        'A batch holds at most $maxBatchWrites writes.',
      );
    }
    final adapter = firestoreAdapters[T]!;
    final uid = FirebaseBackend.userId!;
    final collection = FirebaseBackend.collection(adapter.collectionName);
    final batch = FirebaseBackend.firestore.batch();
    for (final model in models) {
      final row = await adapter.toFirestore(model);
      if ((row['user_id'] ?? row['id']) != uid) {
        throw StateError('Record owner does not match the signed-in user.');
      }
      batch.set(collection.doc(row['id'] as String), row);
    }
    await acceptWrite(batch.commit());
  }

  Future<bool> delete<T extends SqliteModel>(
    T model, {
    Query? query,
    bool localOnly = false,
  }) async {
    if (localOnly || !canSyncRemote) {
      return _repository.delete<T>(model, query: query);
    }
    final adapter = firestoreAdapters[T]!;
    final row = await adapter.toFirestore(model);
    await acceptWrite(
      FirebaseBackend.collection(
        adapter.collectionName,
      ).doc(row['id'] as String).delete(),
    );
    return true;
  }
}
