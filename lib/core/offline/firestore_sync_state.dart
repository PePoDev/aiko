import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

/// Decides where signed-in reads come from, to keep Firestore read costs down.
///
/// `firebaseSyncProvider` keeps one listener per synced collection. Once a
/// listener has caught up with the server, the SDK cache holds the current
/// data, so repository reads are served from that cache (not billed) instead
/// of re-reading every document from the server (billed per document).
///
/// Reads that start before their listener catches up wait up to [syncWait]
/// for it, then use the cache (offline or slow network).
class FirestoreSyncState {
  FirestoreSyncState({this.syncWait = const Duration(seconds: 3)});

  static final instance = FirestoreSyncState();

  final Duration syncWait;
  String? _uid;
  final _waiters = <String, Completer<void>>{};
  final _serverSynced = <String>{};

  static const _cache = GetOptions(source: Source.cache);
  static const _server = GetOptions();

  /// Listeners are being attached for [uid]. A repeat call for the same user
  /// keeps the current state so readers that are already waiting stay valid.
  void beginListening(String uid, Iterable<String> collections) {
    if (_uid == uid) return;
    stopListening();
    _uid = uid;
    for (final collection in collections) {
      _waiters[collection] = Completer<void>();
    }
  }

  /// Signed out or disposed: release waiting readers and forget the state.
  void stopListening() {
    for (final waiter in _waiters.values) {
      if (!waiter.isCompleted) waiter.complete();
    }
    _waiters.clear();
    _serverSynced.clear();
    _uid = null;
  }

  /// The collection's listener delivered a snapshot confirmed by the server.
  void markServerSynced(String collection) {
    if (!_waiters.containsKey(collection)) return;
    _serverSynced.add(collection);
    final waiter = _waiters[collection]!;
    if (!waiter.isCompleted) waiter.complete();
  }

  /// The listener failed (for example, permission denied); read from the
  /// server again so errors surface as before.
  void markListenerFailed(String collection) {
    _serverSynced.remove(collection);
    final waiter = _waiters.remove(collection);
    if (waiter != null && !waiter.isCompleted) waiter.complete();
  }

  bool isServerSynced(String collection) => _serverSynced.contains(collection);

  /// Whether every collection reflects the server, so values derived from them
  /// together (such as reconciled balances) are safe to write back.
  bool allServerSynced(Iterable<String> collections) =>
      collections.every(_serverSynced.contains);

  /// Where to read [collection] from: the cache when a listener maintains it,
  /// otherwise the server.
  Future<GetOptions> readOptions(String collection) async {
    final waiter = _waiters[collection];
    if (waiter == null) return _server;
    if (!waiter.isCompleted) {
      await waiter.future.timeout(
        syncWait,
        onTimeout: () {
          // Offline or slow: stop waiting; the cache is the best copy we have.
          if (!waiter.isCompleted) waiter.complete();
        },
      );
    }
    return _cache;
  }
}
