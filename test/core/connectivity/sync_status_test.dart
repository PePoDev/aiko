import 'dart:async';

import 'package:aiko/core/connectivity/network_status.dart';
import 'package:aiko/core/connectivity/sync_status.dart';
import 'package:aiko/core/offline/firestore_sync_state.dart';
import 'package:aiko/core/storage/file_sync_queue.dart';
import 'package:aiko/core/storage/secure_storage_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' show Database;

import '../storage/file_store_harness.dart';

class _FakeMonitor implements NetworkMonitor {
  _FakeMonitor(this.online);

  bool online;
  final _changes = StreamController<bool>.broadcast();

  void set(bool value) {
    online = value;
    _changes.add(value);
  }

  @override
  Future<bool> isOnline() async => online;

  @override
  Stream<bool> get onlineChanges => _changes.stream;
}

void main() {
  group('syncBannerFor', () {
    test('signed in and offline: changes stay here and sync later', () {
      expect(
        syncBannerFor(const SyncStatus(offline: true, signedIn: true)),
        SyncBanner.offline,
      );
    });

    test('guests and local-only builds only hear about being offline', () {
      expect(
        syncBannerFor(const SyncStatus(offline: true)),
        SyncBanner.offlineLocal,
      );
      expect(syncBannerFor(const SyncStatus(syncing: true)), isNull);
    });

    test('online with changes waiting: syncing; in sync: nothing', () {
      expect(
        syncBannerFor(const SyncStatus(signedIn: true, syncing: true)),
        SyncBanner.syncing,
      );
      expect(syncBannerFor(const SyncStatus(signedIn: true)), isNull);
    });
  });

  test('connectivity results count as online unless there is none', () {
    expect(hasConnection([ConnectivityResult.wifi]), isTrue);
    expect(hasConnection([ConnectivityResult.none]), isFalse);
    expect(
      hasConnection([ConnectivityResult.mobile, ConnectivityResult.vpn]),
      isTrue,
    );
  });

  group('syncStatusProvider', () {
    late FirestoreSyncState sync;
    late _FakeMonitor monitor;
    late MemorySecureStorageService storage;
    late Database files;
    late FileSyncQueue queue;

    ProviderContainer container() {
      final container = ProviderContainer(
        overrides: [
          firestoreSyncStateProvider.overrideWithValue(sync),
          networkMonitorProvider.overrideWithValue(monitor),
          syncStatusStorageProvider.overrideWithValue(storage),
          fileSyncQueueProvider.overrideWithValue(queue),
          syncStatusProvider.overrideWith(
            () => SyncStatusNotifier(
              syncingDelay: const Duration(milliseconds: 20),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.listen(syncStatusProvider, (_, _) {});
      return container;
    }

    setUp(() async {
      sync = FirestoreSyncState();
      monitor = _FakeMonitor(true);
      storage = MemorySecureStorageService();
      files = await openMemoryFileCache();
      queue = testQueue(FakeRemoteFileStore(), signedInUserId: () => null);
    });

    tearDown(() async {
      await queue.dispose();
      await closeMemoryFileCache(files);
    });

    Future<void> waitFor(bool Function() condition) async {
      for (var i = 0; i < 50 && !condition(); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    }

    test('files waiting to upload show as syncing; failed ones and other '
        'users\' don\'t', () async {
      sync.beginListening('user-1', ['accounts']);
      final c = container();
      await pumpEventQueue();
      expect(c.read(syncStatusProvider).syncing, isFalse);

      await queue.enqueue(
        const FileJob(id: 'theirs', ownerId: 'user-2', kind: 'upload'),
      );
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(c.read(syncStatusProvider).syncing, isFalse);

      await queue.enqueue(
        const FileJob(id: 'mine', ownerId: 'user-1', kind: 'upload'),
      );
      await waitFor(() => c.read(syncStatusProvider).syncing);
      expect(c.read(syncStatusProvider).syncing, isTrue);
      expect(syncBannerFor(c.read(syncStatusProvider)), SyncBanner.syncing);

      // It fails for good: no longer "syncing" (it is reported instead).
      await files.update(
        'file_jobs',
        {'attempts': FileSyncQueue.maxAttempts},
        where: 'id = ?',
        whereArgs: ['mine'],
      );
      queue.notifyChanged();
      await waitFor(() => !c.read(syncStatusProvider).syncing);
      expect(c.read(syncStatusProvider).syncing, isFalse);

      await queue.remove('mine');
      await pumpEventQueue();
      expect(c.read(syncStatusProvider).syncing, isFalse);
    });

    test('files waiting for a user who signed out don\'t count', () async {
      await queue.enqueue(
        const FileJob(id: 'mine', ownerId: 'user-1', kind: 'upload'),
      );
      sync.beginListening('user-1', ['accounts']);
      final c = container();
      await waitFor(() => c.read(syncStatusProvider).syncing);
      expect(c.read(syncStatusProvider).syncing, isTrue);

      sync.stopListening();
      await waitFor(() => !c.read(syncStatusProvider).syncing);
      expect(c.read(syncStatusProvider).signedIn, isFalse);
      expect(c.read(syncStatusProvider).syncing, isFalse);
    });

    test(
      'follows the device going offline and back, and tells reads',
      () async {
        final c = container();
        await pumpEventQueue();
        expect(c.read(syncStatusProvider).offline, isFalse);

        monitor.set(false);
        await pumpEventQueue();
        expect(c.read(syncStatusProvider).offline, isTrue);
        expect(sync.deviceOffline, isTrue);

        monitor.set(true);
        await pumpEventQueue();
        expect(c.read(syncStatusProvider).offline, isFalse);
        expect(sync.deviceOffline, isFalse);
      },
    );

    test('signed-in changes waiting a moment show as syncing until the '
        'server has them', () async {
      sync.beginListening('user-1', ['accounts']);
      final c = container();
      await pumpEventQueue();
      expect(c.read(syncStatusProvider).signedIn, isTrue);

      final write = Completer<void>();
      sync.trackWrite(write.future);
      await pumpEventQueue();
      // A write the server takes straight away isn't worth a message.
      expect(c.read(syncStatusProvider).syncing, isFalse);

      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(c.read(syncStatusProvider).syncing, isTrue);

      write.complete();
      await pumpEventQueue();
      expect(c.read(syncStatusProvider).syncing, isFalse);
    });

    test('guests are never signed in', () async {
      final c = container();
      await pumpEventQueue();

      expect(c.read(syncStatusProvider).signedIn, isFalse);
    });

    test('the last sync time is remembered for an offline start', () async {
      await storage.write(
        'user-1:sync_last_synced_at',
        DateTime.utc(2026, 10, 16, 8).toIso8601String(),
      );
      sync.beginListening('user-1', ['accounts']);
      monitor.online = false;

      final c = container();
      await pumpEventQueue();

      expect(c.read(syncStatusProvider).offline, isTrue);
      expect(
        c.read(syncStatusProvider).lastSyncedAt,
        DateTime.utc(2026, 10, 16, 8),
      );
    });

    test('a sync this session is saved for the next one', () async {
      sync.beginListening('user-1', ['accounts']);
      final c = container();
      await pumpEventQueue();

      sync.markServerSynced('accounts');
      await pumpEventQueue();

      final synced = c.read(syncStatusProvider).lastSyncedAt;
      expect(synced, isNotNull);
      expect(
        DateTime.parse((await storage.read('user-1:sync_last_synced_at'))!),
        synced!.toUtc(),
      );
    });
  });
}
