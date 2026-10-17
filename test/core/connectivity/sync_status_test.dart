import 'dart:async';

import 'package:aiko/core/connectivity/network_status.dart';
import 'package:aiko/core/connectivity/sync_status.dart';
import 'package:aiko/core/offline/firestore_sync_state.dart';
import 'package:aiko/core/storage/secure_storage_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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

    ProviderContainer container() {
      final container = ProviderContainer(
        overrides: [
          firestoreSyncStateProvider.overrideWithValue(sync),
          networkMonitorProvider.overrideWithValue(monitor),
          syncStatusStorageProvider.overrideWithValue(storage),
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

    setUp(() {
      sync = FirestoreSyncState();
      monitor = _FakeMonitor(true);
      storage = MemorySecureStorageService();
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
