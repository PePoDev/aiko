// The fakes below stand in for the SDK's cache and server.
// ignore_for_file: subtype_of_sealed_class

import 'dart:async';

import 'package:aiko/core/offline/firestore_sync_state.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const collections = ['accounts', 'transactions'];

  FirestoreSyncState state({
    Duration firstSnapshotWait = const Duration(seconds: 30),
    Duration serverWait = const Duration(seconds: 30),
    DateTime Function()? clock,
  }) => FirestoreSyncState(
    firstSnapshotWait: firstSnapshotWait,
    serverWait: serverWait,
    clock: clock,
  );

  group('readOptions', () {
    test(
      'reads from the server when no listener covers the collection',
      () async {
        final sync = state();

        expect(
          (await sync.readOptions('accounts')).source,
          Source.serverAndCache,
        );
      },
    );

    test('reads from the cache once the listener delivered any snapshot, '
        'even one from the cache', () async {
      final sync = state()..beginListening('uid', collections);

      sync.markSnapshot('accounts', fromCache: true);

      expect((await sync.readOptions('accounts')).source, Source.cache);
      expect(sync.hasSnapshot('accounts'), isTrue);
      expect(sync.isServerSynced('accounts'), isFalse);
    });

    test(
      'a waiting read resumes as soon as the first snapshot arrives',
      () async {
        final sync = state()..beginListening('uid', collections);

        final pending = sync.readOptions('transactions');
        sync.markSnapshot('transactions', fromCache: true);

        expect((await pending).source, Source.cache);
      },
    );

    test('reads share one deadline, so waits never add up', () async {
      final sync = state(firstSnapshotWait: const Duration(milliseconds: 80))
        ..beginListening('uid', collections);
      final stopwatch = Stopwatch()..start();

      expect((await sync.readOptions('accounts')).source, Source.cache);
      expect((await sync.readOptions('transactions')).source, Source.cache);

      expect(stopwatch.elapsedMilliseconds, lessThan(160));
      // Later reads don't wait at all.
      final again = Stopwatch()..start();
      await sync.readOptions('accounts');
      expect(again.elapsedMilliseconds, lessThan(40));
    });

    test('an offline device reads the cache without waiting', () async {
      final sync = state()..beginListening('uid', collections);
      sync.deviceOffline = true;

      final stopwatch = Stopwatch()..start();
      expect((await sync.readOptions('accounts')).source, Source.cache);
      expect(stopwatch.elapsedMilliseconds, lessThan(1000));
    });

    test('a failed listener sends reads back to the server', () async {
      final sync = state()..beginListening('uid', collections);
      sync.markServerSynced('accounts');

      sync.markListenerFailed('accounts');

      expect(
        (await sync.readOptions('accounts')).source,
        Source.serverAndCache,
      );
      expect(sync.isServerSynced('accounts'), isFalse);
    });
  });

  test('restarting listeners for the same user keeps the synced state', () {
    final sync = state()..beginListening('uid', collections);
    sync.markServerSynced('accounts');

    sync.beginListening('uid', collections);

    expect(sync.isServerSynced('accounts'), isTrue);
  });

  test('a different user or sign-out resets the synced state', () async {
    final sync = state()..beginListening('alice', collections);
    sync.markServerSynced('accounts');

    sync.beginListening('bob', collections);
    expect(sync.isServerSynced('accounts'), isFalse);
    expect(sync.userId, 'bob');

    sync.markServerSynced('accounts');
    sync.stopListening();
    expect(sync.isServerSynced('accounts'), isFalse);
    expect(sync.userId, isNull);
    expect((await sync.readOptions('accounts')).source, Source.serverAndCache);
  });

  test('allServerSynced requires every collection', () {
    final sync = state()..beginListening('uid', collections);
    sync.markServerSynced('accounts');

    expect(sync.allServerSynced(collections), isFalse);
    sync.markServerSynced('transactions');
    expect(sync.allServerSynced(collections), isTrue);
  });

  test('sync events for collections without a listener are ignored', () {
    final sync = state()..beginListening('uid', collections);

    sync.markServerSynced('attachments');

    expect(sync.isServerSynced('attachments'), isFalse);
  });

  group('readQuery', () {
    test('a cached result is used without asking the server', () async {
      final sync = state()..beginListening('uid', collections);
      sync.markSnapshot('accounts', fromCache: true);
      final query = _FakeQuery(cache: ['a'], server: ['a', 'b']);

      final result = await sync.readQuery('accounts', query);

      expect(result.docs.map((doc) => doc.id), ['a']);
      expect(query.sources, [Source.cache]);
    });

    test('an empty cache asks the server when the listener still has '
        'nothing after the wait (not downloaded yet)', () async {
      final sync = state(
        firstSnapshotWait: Duration.zero,
        serverWait: const Duration(milliseconds: 20),
      )..beginListening('uid', collections);
      final query = _FakeQuery(server: ['a']);

      final result = await sync.readQuery('accounts', query);

      expect(result.docs.map((doc) => doc.id), ['a']);
      expect(query.sources, [Source.cache, Source.server]);
    });

    test('an empty cache waits for a listener that is still downloading '
        'instead of sending a second, separately billed query', () async {
      final sync = state(firstSnapshotWait: Duration.zero)
        ..beginListening('uid', collections);
      final query = _FakeQuery(server: ['a']);

      final read = sync.readQuery('accounts', query);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      sync.markSnapshot('accounts', fromCache: false);

      expect((await read).docs, isEmpty);
      expect(query.sources, [Source.cache, Source.cache]);
    });

    test('an empty cache is the answer once the listener delivered', () async {
      final sync = state()..beginListening('uid', collections);
      sync.markSnapshot('accounts', fromCache: true);
      final query = _FakeQuery(server: ['a']);

      expect((await sync.readQuery('accounts', query)).docs, isEmpty);
      expect(query.sources, [Source.cache]);
    });

    test('offline, an empty cache is the answer straight away', () async {
      final sync = state()..beginListening('uid', collections);
      sync.deviceOffline = true;
      final query = _FakeQuery(server: ['a']);

      expect((await sync.readQuery('accounts', query)).docs, isEmpty);
      expect(query.sources, [Source.cache]);
    });

    test('a server that does not answer in time falls back to the cache, and '
        'later reads stop asking until it is heard from', () async {
      final sync = state(
        firstSnapshotWait: Duration.zero,
        serverWait: const Duration(milliseconds: 30),
      )..beginListening('uid', collections);
      final hanging = _FakeQuery(hangServer: true);

      final stopwatch = Stopwatch()..start();
      expect((await sync.readQuery('accounts', hanging)).docs, isEmpty);
      expect(stopwatch.elapsedMilliseconds, lessThan(1000));

      final next = _FakeQuery(server: ['t']);
      expect((await sync.readQuery('transactions', next)).docs, isEmpty);
      expect(next.sources, [Source.cache]);

      // Any server snapshot means the server is reachable again.
      sync.markServerSynced('accounts');
      final retry = _FakeQuery(server: ['t']);
      expect((await sync.readQuery('transactions', retry)).docs.single.id, 't');
    });

    test('server errors fall back to the cache', () async {
      final sync = state(
        firstSnapshotWait: Duration.zero,
        serverWait: const Duration(milliseconds: 20),
      )..beginListening('uid', collections);
      final query = _FakeQuery(
        serverError: FirebaseException(plugin: 'test', code: 'unavailable'),
      );

      expect((await sync.readQuery('accounts', query)).docs, isEmpty);
    });

    test('a failed listener reads the server so its error surfaces, and the '
        'cache when offline', () async {
      final sync = state()..beginListening('uid', collections);
      sync.markListenerFailed('accounts');

      final denied = _FakeQuery(
        serverError: FirebaseException(
          plugin: 'test',
          code: 'permission-denied',
        ),
      );
      await expectLater(
        sync.readQuery('accounts', denied),
        throwsA(isA<FirebaseException>()),
      );

      final offline = _FakeQuery(
        cache: ['a'],
        serverError: FirebaseException(plugin: 'test', code: 'unavailable'),
      );
      expect((await sync.readQuery('accounts', offline)).docs.single.id, 'a');
      expect(offline.sources, [Source.server, Source.cache]);
    });
  });

  group('documents', () {
    test('the cache answers found and known-missing documents', () async {
      final sync = state()..beginListening('uid', ['preferences']);
      sync.markSnapshot('preferences', fromCache: true);

      final found = await sync.readCachedDocument(
        'preferences',
        _FakeDoc(cached: {'value': 'th'}),
      );
      expect(found.known, isTrue);
      expect(found.data, {'value': 'th'});

      final missing = await sync.readCachedDocument(
        'preferences',
        _FakeDoc(cachedMissing: true),
      );
      expect(missing.known, isTrue);
      expect(missing.data, isNull);
    });

    test('a document the cache never saw is unknown until the listener has '
        'synced with the server', () async {
      final sync = state()..beginListening('uid', ['preferences']);
      sync.markSnapshot('preferences', fromCache: true);

      expect(
        (await sync.readCachedDocument('preferences', _FakeDoc())).known,
        isFalse,
      );

      sync.markSnapshot('preferences', fromCache: false);
      final synced = await sync.readCachedDocument('preferences', _FakeDoc());
      expect(synced.known, isTrue);
      expect(synced.data, isNull);
    });

    test('the server is asked only while nothing has been delivered', () async {
      final sync = state(firstSnapshotWait: Duration.zero)
        ..beginListening('uid', ['preferences']);

      final fromServer = await sync.readServerDocument(
        'preferences',
        _FakeDoc(server: {'value': 'en'}),
      );
      expect(fromServer.data, {'value': 'en'});

      final missing = await sync.readServerDocument('preferences', _FakeDoc());
      expect(missing.known, isTrue);
      expect(missing.data, isNull);

      sync.markSnapshot('preferences', fromCache: true);
      final doc = _FakeDoc(server: {'value': 'en'});
      expect(
        (await sync.readServerDocument('preferences', doc)).known,
        isFalse,
      );
      expect(doc.sources, isEmpty);
    });

    test('a server read that times out is unknown', () async {
      final sync = state(
        firstSnapshotWait: Duration.zero,
        serverWait: const Duration(milliseconds: 20),
      )..beginListening('uid', ['preferences']);

      final result = await sync.readServerDocument(
        'preferences',
        _FakeDoc(hangServer: true),
      );
      expect(result.known, isFalse);
    });
  });

  test('reads served before the first snapshot ask for a refresh once it '
      'arrives', () async {
    final sync = state(firstSnapshotWait: Duration.zero);
    // The app root reads before the shell starts the listeners.
    await sync.readCachedDocument('preferences', _FakeDoc());
    sync.beginListening('uid', ['preferences', 'accounts']);
    await sync.readQuery('accounts', _FakeQuery(cache: ['a']));

    expect(sync.markSnapshot('preferences', fromCache: true), isTrue);
    expect(sync.markSnapshot('preferences', fromCache: false), isFalse);
    expect(sync.markSnapshot('accounts', fromCache: true), isTrue);

    final later = state()..beginListening('uid', ['accounts']);
    expect(later.markSnapshot('accounts', fromCache: true), isFalse);
  });

  group('pending writes', () {
    test(
      'a tracked write is pending until the server answers, either way',
      () async {
        final sync = state()..beginListening('uid', collections);
        final acked = Completer<void>();
        final rejected = Completer<void>();

        sync.trackWrite(acked.future);
        sync.trackWrite(rejected.future);
        expect(sync.hasPendingWrites, isTrue);

        acked.complete();
        await pumpEventQueue();
        expect(sync.hasPendingWrites, isTrue);

        rejected.completeError(StateError('rejected'));
        await pumpEventQueue();
        expect(sync.hasPendingWrites, isFalse);
      },
    );

    test('listeners report documents with local changes', () {
      final sync = state()..beginListening('uid', collections);

      sync.markSnapshot('accounts', fromCache: true, hasPendingWrites: true);
      expect(sync.hasPendingWrites, isTrue);

      sync.markSnapshot('accounts', fromCache: false);
      expect(sync.hasPendingWrites, isFalse);
    });

    test("signing out forgets the previous user's writes", () async {
      final sync = state()..beginListening('alice', collections);
      final stuck = Completer<void>();
      sync.trackWrite(stuck.future);

      sync.stopListening();
      sync.beginListening('bob', collections);
      expect(sync.hasPendingWrites, isFalse);

      stuck.complete();
      await pumpEventQueue();
      final bobWrite = Completer<void>();
      sync.trackWrite(bobWrite.future);
      expect(sync.hasPendingWrites, isTrue);
    });
  });

  test(
    'lastSyncedAt follows the in-sync state and freezes when it ends',
    () async {
      var now = DateTime.utc(2026, 10, 17, 9);
      final sync = state(clock: () => now)..beginListening('uid', collections);
      expect(sync.inSync, isFalse);
      expect(sync.lastSyncedAt, isNull);

      sync.markServerSynced('accounts');
      sync.markServerSynced('transactions');
      expect(sync.inSync, isTrue);
      expect(sync.lastSyncedAt, DateTime.utc(2026, 10, 17, 9));

      now = DateTime.utc(2026, 10, 17, 10);
      // Offline: the listener falls back to the cache.
      sync.markSnapshot('accounts', fromCache: true);
      expect(sync.inSync, isFalse);
      expect(sync.lastSyncedAt, DateTime.utc(2026, 10, 17, 10));

      now = DateTime.utc(2026, 10, 17, 12);
      sync.markSnapshot('transactions', fromCache: true);
      expect(sync.lastSyncedAt, DateTime.utc(2026, 10, 17, 10));
    },
  );

  test('changes are announced', () async {
    final sync = state();
    var events = 0;
    final subscription = sync.changes.listen((_) => events++);
    addTearDown(subscription.cancel);

    sync.beginListening('uid', collections);
    sync.deviceOffline = true;
    await pumpEventQueue();

    expect(events, greaterThanOrEqualTo(2));
  });
}

class _FakeQuery extends Fake implements Query<Map<String, dynamic>> {
  _FakeQuery({
    this.cache = const [],
    this.server = const [],
    this.serverError,
    this.hangServer = false,
  });

  final List<String> cache;
  final List<String> server;
  final Object? serverError;
  final bool hangServer;
  final sources = <Source>[];

  @override
  Future<QuerySnapshot<Map<String, dynamic>>> get([GetOptions? options]) {
    final source = options?.source ?? Source.serverAndCache;
    sources.add(source);
    if (source == Source.cache) return Future.value(_FakeQuerySnapshot(cache));
    if (hangServer) {
      return Completer<QuerySnapshot<Map<String, dynamic>>>().future;
    }
    final error = serverError;
    if (error != null) return Future.error(error);
    return Future.value(_FakeQuerySnapshot(server));
  }
}

class _FakeQuerySnapshot extends Fake
    implements QuerySnapshot<Map<String, dynamic>> {
  _FakeQuerySnapshot(this.ids);

  final List<String> ids;

  @override
  List<QueryDocumentSnapshot<Map<String, dynamic>>> get docs => [
    for (final id in ids) _FakeQueryDoc(id),
  ];
}

class _FakeQueryDoc extends Fake
    implements QueryDocumentSnapshot<Map<String, dynamic>> {
  _FakeQueryDoc(this.id);

  @override
  final String id;

  @override
  Map<String, dynamic> data() => {'id': id};
}

class _FakeDoc extends Fake implements DocumentReference<Map<String, dynamic>> {
  _FakeDoc({
    this.cached,
    this.cachedMissing = false,
    this.server,
    this.hangServer = false,
  });

  final Map<String, dynamic>? cached;
  final bool cachedMissing;
  final Map<String, dynamic>? server;
  final bool hangServer;
  final sources = <Source>[];

  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([GetOptions? options]) {
    final source = options?.source ?? Source.serverAndCache;
    if (source != Source.cache) sources.add(source);
    if (source == Source.cache) {
      final cached = this.cached;
      if (cached != null || cachedMissing) {
        return Future.value(_FakeDocSnapshot(cached));
      }
      return Future.error(
        FirebaseException(plugin: 'test', code: 'unavailable'),
      );
    }
    if (hangServer) {
      return Completer<DocumentSnapshot<Map<String, dynamic>>>().future;
    }
    return Future.value(_FakeDocSnapshot(server));
  }
}

class _FakeDocSnapshot extends Fake
    implements DocumentSnapshot<Map<String, dynamic>> {
  _FakeDocSnapshot(this._data);

  final Map<String, dynamic>? _data;

  @override
  bool get exists => _data != null;

  @override
  Map<String, dynamic>? data() => _data;
}
