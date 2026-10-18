import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

/// What a read could learn about one document.
class DocumentRead {
  const DocumentRead.found(Map<String, dynamic> this.data) : known = true;
  const DocumentRead.missing() : data = null, known = true;
  const DocumentRead.unknown() : data = null, known = false;

  /// The document's fields; null when it doesn't exist or isn't known.
  final Map<String, dynamic>? data;

  /// Whether the cache or the server could say if the document exists.
  final bool known;
}

/// Decides where signed-in reads come from, and keeps track of what is still
/// waiting to upload.
///
/// `firebaseSyncProvider` keeps one listener per synced collection. Once a
/// listener has delivered a snapshot, the SDK cache holds the collection (as
/// of the last sync, offline), so reads are served from that cache straight
/// away; they are not billed and never wait for the network. The listener
/// then refreshes the screens when the server reports changes.
///
/// Reads that start before their listener's first snapshot wait for it until
/// [firstSnapshotWait] after the listeners started: one deadline shared by
/// every collection, so consecutive reads never add up their waits. When the
/// cache can't answer (nothing cached yet, listener not caught up), a read asks
/// the server for at most [serverWait]; after a server read times out, later
/// reads stop asking until the server is heard from again.
class FirestoreSyncState {
  FirestoreSyncState({
    this.firstSnapshotWait = const Duration(seconds: 2),
    this.serverWait = const Duration(seconds: 3),
    this.unreachableRetry = const Duration(minutes: 1),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  static final instance = FirestoreSyncState();

  final Duration firstSnapshotWait;
  final Duration serverWait;

  /// How long reads skip the server after a server read timed out, unless a
  /// listener or the device's network says it's back sooner.
  final Duration unreachableRetry;
  final DateTime Function() _clock;

  String? _uid;
  final _listened = <String>{};
  final _firstSnapshot = <String, Completer<void>>{};
  Completer<void>? _deadline;
  Timer? _deadlineTimer;
  final _delivered = <String>{};
  final _serverSynced = <String>{};
  final _live = <String>{};
  final _failed = <String>{};
  final _servedEarly = <String>{};
  final _pendingCollections = <String>{};
  var _writesInFlight = 0;
  var _generation = 0;
  var _deviceOffline = false;
  DateTime? _serverUnreachableAt;
  DateTime? _lastSyncedAt;
  bool? _wasInSync;
  // Delivered asynchronously: writes are tracked from inside provider builds,
  // which must not update other providers synchronously.
  final _changes = StreamController<void>.broadcast();

  static const _cache = GetOptions(source: Source.cache);
  static const _server = GetOptions(source: Source.server);

  /// Listeners are being attached for [uid]. A repeat call for the same user
  /// keeps the current state so readers that are already waiting stay valid.
  /// Reads served before the first call (the app root reads the profile and
  /// language before the shell starts the listeners) are remembered, so the
  /// first snapshots refresh them.
  void beginListening(String uid, Iterable<String> collections) {
    if (_uid == uid) return;
    final servedEarly = _uid == null ? {..._servedEarly} : const <String>{};
    stopListening();
    _servedEarly.addAll(servedEarly);
    _uid = uid;
    _listened.addAll(collections);
    for (final collection in collections) {
      _firstSnapshot[collection] = Completer<void>();
    }
    final deadline = _deadline = Completer<void>();
    _deadlineTimer = Timer(firstSnapshotWait, () {
      if (!deadline.isCompleted) deadline.complete();
    });
    _notify();
  }

  /// The signed-in user whose collections are listened to; null signed out.
  String? get userId => _uid;

  /// Signed out or disposed: release waiting readers and forget the state,
  /// including writes still waiting for the previous user's session.
  void stopListening() {
    for (final waiter in _firstSnapshot.values) {
      if (!waiter.isCompleted) waiter.complete();
    }
    _deadlineTimer?.cancel();
    final deadline = _deadline;
    if (deadline != null && !deadline.isCompleted) deadline.complete();
    _deadline = null;
    _firstSnapshot.clear();
    _listened.clear();
    _delivered.clear();
    _serverSynced.clear();
    _live.clear();
    _failed.clear();
    _servedEarly.clear();
    _pendingCollections.clear();
    _writesInFlight = 0;
    _generation++;
    _uid = null;
    _lastSyncedAt = null;
    _wasInSync = null;
    _notify();
  }

  /// The collection's listener delivered a snapshot. Returns true when reads
  /// of the collection were served before this first snapshot, so the caller
  /// should have them read again.
  bool markSnapshot(
    String collection, {
    required bool fromCache,
    bool hasPendingWrites = false,
  }) {
    if (!_listened.contains(collection)) return false;
    final first = _delivered.add(collection);
    _failed.remove(collection);
    if (fromCache) {
      _live.remove(collection);
    } else {
      _serverSynced.add(collection);
      _live.add(collection);
      _serverUnreachableAt = null;
    }
    if (hasPendingWrites) {
      _pendingCollections.add(collection);
    } else {
      _pendingCollections.remove(collection);
    }
    final waiter = _firstSnapshot[collection];
    if (waiter != null && !waiter.isCompleted) waiter.complete();
    _notify();
    return first && _servedEarly.remove(collection);
  }

  /// The collection's listener delivered a snapshot confirmed by the server.
  void markServerSynced(String collection) =>
      markSnapshot(collection, fromCache: false);

  /// The listener failed (for example, permission denied); read from the
  /// server again so errors surface as before.
  void markListenerFailed(String collection) {
    _serverSynced.remove(collection);
    _live.remove(collection);
    _delivered.remove(collection);
    _pendingCollections.remove(collection);
    if (_listened.contains(collection)) _failed.add(collection);
    final waiter = _firstSnapshot.remove(collection);
    if (waiter != null && !waiter.isCompleted) waiter.complete();
    _notify();
  }

  bool isServerSynced(String collection) => _serverSynced.contains(collection);

  /// Whether every collection reflects the server, so values derived from them
  /// together (such as reconciled balances) are safe to write back.
  bool allServerSynced(Iterable<String> collections) =>
      collections.every(_serverSynced.contains);

  /// Whether the collection's listener has delivered any snapshot yet.
  bool hasSnapshot(String collection) => _delivered.contains(collection);

  /// Whether the device reports no network ([deviceOffline]). Reads then
  /// use the cache without waiting for listeners or asking the server.
  bool get deviceOffline => _deviceOffline;
  set deviceOffline(bool offline) {
    if (offline == _deviceOffline) return;
    _deviceOffline = offline;
    // Back online: give the server another chance straight away.
    if (!offline) _serverUnreachableAt = null;
    _notify();
  }

  bool get _serverUnreachable {
    final since = _serverUnreachableAt;
    return since != null && _clock().difference(since) < unreachableRetry;
  }

  /// Where to read [collection] from: the cache once its listener has
  /// delivered anything (or the brief wait for it ran out); the server when
  /// no listener covers it or its listener failed.
  Future<GetOptions> readOptions(String collection) async {
    await _awaitFirstSnapshot(collection);
    if (!_firstSnapshot.containsKey(collection) &&
        !_delivered.contains(collection)) {
      return const GetOptions();
    }
    return _cache;
  }

  /// Reads [query] over [collection]: from the cache, and from the server
  /// (briefly) only when the cache returns nothing and can't be trusted to be
  /// complete. A failed listener sends the read to the server so its error
  /// surfaces; offline that read falls back to the cache.
  Future<QuerySnapshot<T>> readQuery<T>(
    String collection,
    Query<T> query,
  ) async {
    await _awaitFirstSnapshot(collection);
    if (_failed.contains(collection)) {
      try {
        final fromServer = await _askServer(() => query.get(_server));
        if (fromServer != null) return fromServer;
      } on FirebaseException catch (error) {
        if (error.code != 'unavailable') rethrow;
      }
      return query.get(_cache);
    }
    _noteRead(collection);
    final cached = await query.get(_cache);
    if (cached.docs.isNotEmpty || !_mayAskServer(collection)) return cached;
    // The collection's listener is still downloading it (a large ledger on a
    // slow network): wait for that instead of sending a second query, which
    // the server would bill again for every document.
    final waiter = _firstSnapshot[collection];
    if (waiter != null && !waiter.isCompleted) {
      await Future.any([waiter.future, Future<void>.delayed(serverWait)]);
      if (waiter.isCompleted) return query.get(_cache);
    }
    // Nothing cached, and nothing says the cache is complete (new device,
    // listener not caught up): ask the server so callers don't mistake "not
    // downloaded yet" for "doesn't exist".
    try {
      return await _askServer(() => query.get(_server)) ?? cached;
    } on FirebaseException {
      return cached;
    }
  }

  /// Reads [doc] of [collection] from the cache only. Unknown when the cache
  /// has never seen the document and no listener has confirmed the collection
  /// with the server.
  Future<DocumentRead> readCachedDocument(
    String collection,
    DocumentReference<Map<String, dynamic>> doc,
  ) async {
    await _awaitFirstSnapshot(collection);
    _noteRead(collection);
    try {
      final snapshot = await doc.get(_cache);
      final data = snapshot.data();
      if (data != null) return DocumentRead.found(data);
      // The cache knows the document doesn't exist.
      return const DocumentRead.missing();
    } on FirebaseException {
      // Not in the cache.
    }
    // A listener synced with the server keeps every document of its
    // collection in the cache, so one that isn't there doesn't exist.
    if (_serverSynced.contains(collection)) return const DocumentRead.missing();
    return const DocumentRead.unknown();
  }

  /// Asks the server for [doc] of [collection], for at most [serverWait].
  /// Unknown when offline, when the server doesn't answer in time, or when the
  /// collection's listener has already delivered a snapshot (its cache is the
  /// best copy until the server says otherwise, and the listener will).
  Future<DocumentRead> readServerDocument(
    String collection,
    DocumentReference<Map<String, dynamic>> doc,
  ) async {
    if (!_mayAskServer(collection)) return const DocumentRead.unknown();
    try {
      final snapshot = await _askServer(() => doc.get(_server));
      if (snapshot == null) return const DocumentRead.unknown();
      final data = snapshot.data();
      return data == null
          ? const DocumentRead.missing()
          : DocumentRead.found(data);
    } on FirebaseException {
      return const DocumentRead.unknown();
    }
  }

  Future<void> _awaitFirstSnapshot(String collection) async {
    final waiter = _firstSnapshot[collection];
    final deadline = _deadline;
    if (waiter == null ||
        waiter.isCompleted ||
        deadline == null ||
        deadline.isCompleted ||
        _deviceOffline) {
      return;
    }
    await Future.any([waiter.future, deadline.future]);
  }

  /// A read served before the collection's listener delivered anything; its
  /// first snapshot should refresh what was read.
  void _noteRead(String collection) {
    if (!_delivered.contains(collection)) _servedEarly.add(collection);
  }

  bool _mayAskServer(String collection) =>
      !_deviceOffline &&
      !_serverUnreachable &&
      !_delivered.contains(collection) &&
      !_serverSynced.contains(collection);

  Future<S?> _askServer<S>(Future<S> Function() read) async {
    try {
      return await read().timeout(serverWait);
    } on TimeoutException {
      _serverUnreachableAt = _clock();
      return null;
    }
  }

  /// Follows a write handed to the SDK until the server acknowledges or
  /// rejects it. Its outcome is reported elsewhere ([OfflineStore.errors]).
  void trackWrite(Future<void> write) {
    final generation = _generation;
    _writesInFlight++;
    _notify();
    void done() {
      if (generation != _generation) return;
      _writesInFlight--;
      _notify();
    }

    write.then<void>((_) => done(), onError: (Object _) => done());
  }

  /// Whether changes made while signed in are still waiting to upload: writes
  /// handed to the SDK and not yet acknowledged, or (writes from earlier
  /// sessions, edits by other code) documents the listeners report as having
  /// local changes.
  bool get hasPendingWrites =>
      _writesInFlight > 0 || _pendingCollections.isNotEmpty;

  /// Whether every listened collection is confirmed by the server and nothing
  /// waits to upload.
  bool get inSync =>
      _listened.isNotEmpty &&
      !hasPendingWrites &&
      _listened.every(_live.contains);

  /// The last time [inSync] was seen to hold this session: kept current while
  /// in sync, and frozen when it stops (offline, or changes waiting).
  DateTime? get lastSyncedAt => _lastSyncedAt;

  /// Fires whenever [hasPendingWrites], [inSync], [lastSyncedAt] or
  /// [deviceOffline] may have changed.
  Stream<void> get changes => _changes.stream;

  void _notify() {
    final inSync = this.inSync;
    if (inSync || _wasInSync == true) _lastSyncedAt = _clock();
    _wasInSync = inSync;
    _changes.add(null);
  }
}
