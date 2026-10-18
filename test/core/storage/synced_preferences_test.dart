import 'dart:convert';

import 'package:aiko/core/offline/firestore_sync_state.dart';
import 'package:aiko/core/storage/secure_storage_service.dart';
import 'package:aiko/core/storage/synced_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'offline_firestore.dart';

const _uid = 'user-1';

FirestoreSyncState _sync() => FirestoreSyncState(
  firstSnapshotWait: Duration.zero,
  serverWait: const Duration(milliseconds: 50),
);

void main() {
  group('signed out', () {
    test('values and items live in device storage', () async {
      final device = MemorySecureStorageService();
      final prefs = SyncedPreferences(local: device, userId: () => null);

      await prefs.write('aiko_language_code', 'th');
      expect(await prefs.read('aiko_language_code'), 'th');
      expect(await device.read('aiko_language_code'), 'th');

      await prefs.writeItems('list', {'a': '1', 'b': '2'});
      await prefs.writeItems('list', {'a': null});
      expect(await prefs.readItems('list'), {'b': '2'});
      expect(jsonDecode((await device.read('list'))!), {'b': '2'});

      await prefs.delete('aiko_language_code');
      expect(await prefs.read('aiko_language_code'), isNull);
    });
  });

  group('signed in', () {
    late FakeFirebaseFirestore firestore;
    late MemorySecureStorageService device;
    late SyncedPreferences prefs;

    DocumentReference<Map<String, dynamic>> doc(String key) => firestore
        .collection('users')
        .doc(_uid)
        .collection('preferences')
        .doc(key);

    SyncedPreferences onDevice(MemorySecureStorageService storage) =>
        SyncedPreferences(
          local: storage,
          firestore: firestore,
          userId: () => _uid,
          sync: _sync(),
        );

    setUp(() {
      firestore = FakeFirebaseFirestore();
      device = MemorySecureStorageService();
      prefs = onDevice(device);
    });

    test(
      'a value is stored in its document and copied to the device',
      () async {
        await prefs.write('aiko_language_code', 'th');

        expect((await doc('aiko_language_code').get()).data(), {'value': 'th'});
        expect(await prefs.read('aiko_language_code'), 'th');
        expect(await device.read('$_uid:aiko_language_code'), 'th');
      },
    );

    test('a preference that does not exist reads as no value', () async {
      expect(await prefs.read('aiko_language_code'), isNull);
      expect(await prefs.readItems('dismissed'), isNull);
    });

    test('deleting removes the document and remembers it is gone', () async {
      await prefs.write('aiko_language_code', 'en');
      await prefs.delete('aiko_language_code');

      expect((await doc('aiko_language_code').get()).exists, isFalse);
      expect(await prefs.read('aiko_language_code'), isNull);
      expect(await device.read('$_uid:aiko_language_code'), isNot('en'));
    });

    test('items written on two devices merge instead of replacing each '
        'other', () async {
      final phone = onDevice(MemorySecureStorageService());
      final tablet = onDevice(MemorySecureStorageService());

      await phone.writeItems('rules', {'r1': 'phone rule'});
      await tablet.writeItems('rules', {'r2': 'tablet rule'});
      expect(await phone.readItems('rules'), {
        'r1': 'phone rule',
        'r2': 'tablet rule',
      });

      await tablet.writeItems('rules', {'r1': null});
      expect((await doc('rules').get()).data(), {
        'items': {'r2': 'tablet rule'},
      });
      expect(await phone.readItems('rules'), {'r2': 'tablet rule'});
    });
  });

  group('ItemizedPreference', () {
    Map<String, String> legacyList(String raw) => {
      for (final id in jsonDecode(raw) as List) id as String: '',
    };

    test('reads the legacy value until the items are written, then carries '
        'it over', () async {
      final storage = MemorySecureStorageService();
      await storage.write('ids_v1', jsonEncode(['a', 'b']));
      final preference = ItemizedPreference(
        storage,
        key: 'ids_v2',
        legacyKey: 'ids_v1',
        legacyItems: legacyList,
      );

      expect((await preference.read()).keys, unorderedEquals(['a', 'b']));

      final next = await preference.write({'c': '', 'a': null});
      expect(next.keys, unorderedEquals(['b', 'c']));
      expect((await preference.read()).keys, unorderedEquals(['b', 'c']));
      // The legacy value stays for older app versions.
      expect(await storage.read('ids_v1'), jsonEncode(['a', 'b']));
    });

    test('removing the last legacy item still records the items', () async {
      final storage = MemorySecureStorageService();
      await storage.write('ids_v1', jsonEncode(['a']));
      final preference = ItemizedPreference(
        storage,
        key: 'ids_v2',
        legacyKey: 'ids_v1',
        legacyItems: legacyList,
      );

      expect(await preference.write({'a': null}), isEmpty);
      expect(await preference.read(), isEmpty);
    });

    test('an unreadable legacy value counts as no items', () async {
      final storage = MemorySecureStorageService();
      await storage.write('ids_v1', 'not json');
      final preference = ItemizedPreference(
        storage,
        key: 'ids_v2',
        legacyKey: 'ids_v1',
        legacyItems: legacyList,
      );

      expect(await preference.read(), isEmpty);
    });

    test('signed in, the first write merges with items another device '
        'already wrote', () async {
      final firestore = FakeFirebaseFirestore();
      SyncedPreferences device() => SyncedPreferences(
        local: MemorySecureStorageService(),
        firestore: firestore,
        userId: () => _uid,
        sync: _sync(),
      );
      await device().writeItems('ids_v2', {'tablet': ''});

      final preference = ItemizedPreference(
        device(),
        key: 'ids_v2',
        legacyKey: 'ids_v1',
        legacyItems: legacyList,
      );
      await preference.write({'phone': ''});

      expect(
        (await preference.read()).keys,
        unorderedEquals(['tablet', 'phone']),
      );
    });
  });

  group('ItemizedPreference, while the device cannot tell whether the items '
      'exist', () {
    Map<String, String> legacyList(String raw) => {
      for (final id in jsonDecode(raw) as List) id as String: '',
    };

    test('a change waits on the device, shown over the legacy items, and '
        'goes out alone once the items turn out to exist', () async {
      final storage = _UnsureItems();
      await storage.write('ids_v1', jsonEncode(['r', 's']));
      // Another device moved to the items and removed `r`.
      storage.items['ids_v2'] = {'s': ''};
      storage.known = false;
      final preference = ItemizedPreference(
        storage,
        key: 'ids_v2',
        legacyKey: 'ids_v1',
        legacyItems: legacyList,
      );

      final next = await preference.write({'t': ''});

      expect(next.keys, unorderedEquals(['r', 's', 't']));
      expect(storage.written, isEmpty);
      expect((await preference.read()).keys, unorderedEquals(['r', 's', 't']));

      storage.known = true;
      expect((await preference.read()).keys, unorderedEquals(['s', 't']));
      expect(storage.written, [
        {'t': ''},
      ]);
      expect(await storage.readDeferred('ids_v2'), isNull);
    });

    test('once the items turn out to be missing, the legacy items are carried '
        'over with the waiting changes', () async {
      final storage = _UnsureItems();
      await storage.write('ids_v1', jsonEncode(['r', 's']));
      storage.known = false;
      final preference = ItemizedPreference(
        storage,
        key: 'ids_v2',
        legacyKey: 'ids_v1',
        legacyItems: legacyList,
      );
      await preference.write({'r': null});
      await preference.write({'t': ''});

      storage.known = true;
      final next = await preference.write({'u': ''});

      expect(next.keys, unorderedEquals(['s', 't', 'u']));
      expect(storage.items['ids_v2']!.keys, unorderedEquals(['s', 't', 'u']));
      expect(await storage.readDeferred('ids_v2'), isNull);
    });

    test('signed in and offline, the waiting changes are kept for this user '
        'and written once the server can be asked', () async {
      final device = MemorySecureStorageService();
      final offline = SyncedPreferences(
        local: device,
        firestore: OfflineFirestore(),
        userId: () => _uid,
        sync: _sync(),
      );
      await ItemizedPreference(offline, key: 'rules').write({'r1': 'rule'});

      expect(jsonDecode((await device.read('$_uid:rules:deferred'))!), {
        'r1': 'rule',
      });
      expect(await ItemizedPreference(offline, key: 'rules').read(), {
        'r1': 'rule',
      });

      final firestore = FakeFirebaseFirestore();
      await firestore
          .collection('users')
          .doc(_uid)
          .collection('preferences')
          .doc('rules')
          .set({
            'items': {'r0': 'other device'},
          });
      final online = SyncedPreferences(
        local: device,
        firestore: firestore,
        userId: () => _uid,
        sync: _sync(),
      );
      expect(await ItemizedPreference(online, key: 'rules').read(), {
        'r0': 'other device',
        'r1': 'rule',
      });
      expect(await device.read('$_uid:rules:deferred'), isNull);
    });
  });

  group('offline, with documents the cache has never seen', () {
    late OfflineFirestore firestore;
    late MemorySecureStorageService device;
    late SyncedPreferences prefs;

    setUp(() {
      firestore = OfflineFirestore();
      device = MemorySecureStorageService();
      prefs = SyncedPreferences(
        local: device,
        firestore: firestore,
        userId: () => _uid,
        sync: _sync(),
      );
    });

    test("reads fall back to the device's copy", () async {
      await device.write('$_uid:aiko_language_code', 'th');
      await device.write('$_uid:rules', jsonEncode({'r1': 'rule'}));

      expect(await prefs.read('aiko_language_code'), 'th');
      expect(await prefs.readItems('rules'), {'r1': 'rule'});
      expect(firestore.serverReads, 0);
    });

    test('without a copy they are "no value" after a brief server try, never '
        'an error', () async {
      final stopwatch = Stopwatch()..start();
      expect(await prefs.read('aiko_language_code'), isNull);
      expect(await prefs.readItems('rules'), isNull);
      expect(stopwatch.elapsedMilliseconds, lessThan(2000));
    });

    test(
      'a copy that remembers the preference is gone answers at once',
      () async {
        await prefs.write('aiko_language_code', 'en');
        firestore.forgetCache();
        await prefs.delete('aiko_language_code');
        firestore.forgetCache();

        expect(await prefs.read('aiko_language_code'), isNull);
        expect(firestore.serverReads, 0);
      },
    );

    test(
      'writes return without waiting for the server and are read back',
      () async {
        await prefs
            .write('aiko_language_code', 'th')
            .timeout(const Duration(seconds: 1));
        await prefs
            .writeItems('rules', {'r1': 'rule'})
            .timeout(const Duration(seconds: 1));

        expect(await prefs.read('aiko_language_code'), 'th');
        expect(await prefs.readItems('rules'), {'r1': 'rule'});

        // Even when the SDK cache is gone (a reinstall that kept the session).
        firestore.forgetCache();
        expect(await prefs.read('aiko_language_code'), 'th');
        expect(await prefs.readItems('rules'), {'r1': 'rule'});
      },
    );
  });
}

/// Item storage that can be told it doesn't know whether items exist, as a
/// signed-in device offline with nothing cached; notes every items write.
class _UnsureItems extends MemorySecureStorageService
    implements PreferenceItemStorage {
  final items = <String, Map<String, String>>{};
  final written = <Map<String, String?>>[];
  final _deferred = <String, Map<String, String?>>{};
  var known = true;

  @override
  Future<Map<String, String>?> readItems(String key) async =>
      (await readItemsState(key)).items;

  @override
  Future<PreferenceItemsRead> readItemsState(String key) async => known
      ? (items: items[key] == null ? null : {...items[key]!}, known: true)
      : (items: null, known: false);

  @override
  Future<void> writeItems(String key, Map<String, String?> changes) async {
    written.add(changes);
    applyPreferenceItemChanges(items.putIfAbsent(key, () => {}), changes);
  }

  @override
  Future<Map<String, String?>?> readDeferred(String key) async =>
      _deferred[key];

  @override
  Future<void> writeDeferred(String key, Map<String, String?>? changes) async {
    if (changes == null) {
      _deferred.remove(key);
    } else {
      _deferred[key] = changes;
    }
  }
}
