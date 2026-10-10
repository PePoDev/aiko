import 'package:aiko/core/offline/firestore_sync_state.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const collections = ['accounts', 'transactions'];

  test(
    'reads from the server when no listener covers the collection',
    () async {
      final sync = FirestoreSyncState();

      expect(
        (await sync.readOptions('accounts')).source,
        Source.serverAndCache,
      );
    },
  );

  test('reads from the cache once the listener has synced', () async {
    final sync = FirestoreSyncState()..beginListening('uid', collections);

    sync.markServerSynced('accounts');

    expect((await sync.readOptions('accounts')).source, Source.cache);
    expect(sync.isServerSynced('accounts'), isTrue);
  });

  test('a waiting read resumes as soon as the listener syncs', () async {
    final sync = FirestoreSyncState(syncWait: const Duration(seconds: 30))
      ..beginListening('uid', collections);

    final pending = sync.readOptions('transactions');
    sync.markServerSynced('transactions');

    expect((await pending).source, Source.cache);
  });

  test(
    'after the wait times out, reads use the cache without waiting again',
    () async {
      final sync = FirestoreSyncState(
        syncWait: const Duration(milliseconds: 10),
      )..beginListening('uid', collections);

      expect((await sync.readOptions('accounts')).source, Source.cache);
      expect(sync.isServerSynced('accounts'), isFalse);
      final stopwatch = Stopwatch()..start();
      await sync.readOptions('accounts');
      expect(stopwatch.elapsedMilliseconds, lessThan(10));
    },
  );

  test('a failed listener sends reads back to the server', () async {
    final sync = FirestoreSyncState()..beginListening('uid', collections);
    sync.markServerSynced('accounts');

    sync.markListenerFailed('accounts');

    expect((await sync.readOptions('accounts')).source, Source.serverAndCache);
    expect(sync.isServerSynced('accounts'), isFalse);
  });

  test('restarting listeners for the same user keeps the synced state', () {
    final sync = FirestoreSyncState()..beginListening('uid', collections);
    sync.markServerSynced('accounts');

    sync.beginListening('uid', collections);

    expect(sync.isServerSynced('accounts'), isTrue);
  });

  test('a different user or sign-out resets the synced state', () async {
    final sync = FirestoreSyncState()..beginListening('alice', collections);
    sync.markServerSynced('accounts');

    sync.beginListening('bob', collections);
    expect(sync.isServerSynced('accounts'), isFalse);

    sync.markServerSynced('accounts');
    sync.stopListening();
    expect(sync.isServerSynced('accounts'), isFalse);
    expect((await sync.readOptions('accounts')).source, Source.serverAndCache);
  });

  test('allServerSynced requires every collection', () {
    final sync = FirestoreSyncState()..beginListening('uid', collections);
    sync.markServerSynced('accounts');

    expect(sync.allServerSynced(collections), isFalse);
    sync.markServerSynced('transactions');
    expect(sync.allServerSynced(collections), isTrue);
  });

  test('sync events for collections without a listener are ignored', () {
    final sync = FirestoreSyncState()..beginListening('uid', collections);

    sync.markServerSynced('attachments');

    expect(sync.isServerSynced('attachments'), isFalse);
  });
}
