import 'package:aiko/core/config/app_config.dart';
import 'package:aiko/core/offline/firestore_sync_state.dart';
import 'package:aiko/core/offline/offline_store.dart';
import 'package:aiko/core/offline/records/records.dart';
import 'package:aiko/core/storage/secure_storage_service.dart';
import 'package:aiko/features/settings/data/profile_repository.dart';
import 'package:aiko/features/settings/domain/profile.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/offline/record_store_harness.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    binding.platformDispatcher.clearPlatformBrightnessTestValue();
  });

  test('resolveInitialTheme returns dark when the device is in dark mode', () {
    binding.platformDispatcher.platformBrightnessTestValue = Brightness.dark;

    expect(ProfileRepository.resolveInitialTheme(), PreferredTheme.dark);
  });

  test(
    'resolveInitialTheme returns light when the device is in light mode',
    () {
      binding.platformDispatcher.platformBrightnessTestValue = Brightness.light;

      expect(ProfileRepository.resolveInitialTheme(), PreferredTheme.light);
    },
  );

  group('signed in, before the profile document reached this device', () {
    const uid = 'user-1';
    late FakeFirebaseFirestore firestore;
    late FirestoreSyncState sync;
    late MemorySecureStorageService device;
    late ProfileRepository repo;

    DocumentReference<Map<String, dynamic>> profileDoc() =>
        firestore.collection('users').doc(uid).collection('profiles').doc(uid);

    Map<String, dynamic> realProfileRow() => RecordCodecs.profiles.toRow(
      OfflineProfile(
        id: uid,
        displayName: 'Mali',
        email: 'mali@example.com',
        baseCurrency: 'USD',
        country: 'US',
        preferredTheme: 'light',
        fullName: 'Mali Srisuk',
      ),
    );

    setUp(() {
      ProfileRepository.resetPlaceholders();
      binding.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      firestore = FakeFirebaseFirestore();
      sync = FirestoreSyncState(firstSnapshotWait: Duration.zero)
        ..beginListening(uid, ['profiles']);
      device = MemorySecureStorageService();
      repo = ProfileRepository(
        store: OfflineStore(firestore: firestore, signedInUserId: () => uid),
        userContext: const FixedUserContext(uid),
        deviceStorage: device,
        sync: sync,
      );
    });

    test('a change to the stand-in profile is kept on the device instead of '
        'replacing the real profile', () async {
      final shown = await repo.load();
      expect(shown.baseCurrency, kDefaultBaseCurrency);

      final saved = await repo.save(
        shown.copyWith(preferredTheme: PreferredTheme.dark),
      );
      expect(saved.preferredTheme, PreferredTheme.dark);
      expect((await profileDoc().get()).exists, isFalse);
      // Shown with the change until the real profile arrives.
      expect((await repo.load()).preferredTheme, PreferredTheme.dark);

      // The real profile syncs down: only the changed field goes on top.
      await profileDoc().set(realProfileRow());
      final real = await repo.load();
      expect(real.preferredTheme, PreferredTheme.dark);
      expect(real.displayName, 'Mali');
      expect(real.baseCurrency, 'USD');
      expect(real.fullName, 'Mali Srisuk');
      final stored = (await profileDoc().get()).data()!;
      expect(stored['preferred_theme'], 'dark');
      expect(stored['display_name'], 'Mali');
      expect(stored['base_currency'], 'USD');
      expect(await device.read('$uid:profile_changes_v1'), isNull);
    });

    test('a save after the real profile arrived changes only what the user '
        'changed', () async {
      final shown = await repo.load();
      await profileDoc().set(realProfileRow());

      final saved = await repo.save(shown.copyWith(baseCurrency: 'JPY'));

      expect(saved.baseCurrency, 'JPY');
      expect(saved.displayName, 'Mali');
      final stored = (await profileDoc().get()).data()!;
      expect(stored['base_currency'], 'JPY');
      expect(stored['preferred_theme'], 'light');
      expect(stored['full_name'], 'Mali Srisuk');
    });

    test('once the server confirmed there is no profile, saving stores the '
        'whole profile', () async {
      sync.markServerSynced('profiles');
      final shown = await repo.load();

      await repo.save(shown.copyWith(displayName: 'New'));

      final stored = (await profileDoc().get()).data()!;
      expect(stored['display_name'], 'New');
      expect(stored['base_currency'], kDefaultBaseCurrency);
    });

    test('profileChanges lists only the stored fields that differ', () {
      const before = Profile(
        id: uid,
        displayName: 'A',
        email: '',
        baseCurrency: 'THB',
        country: 'TH',
        securityStatus: SecurityStatus.notConfigured,
        preferredTheme: PreferredTheme.light,
      );

      expect(
        profileChanges(
          before,
          before.copyWith(
            preferredTheme: PreferredTheme.dark,
            fullName: () => 'Full',
          ),
        ),
        {'preferred_theme': 'dark', 'full_name': 'Full'},
      );
      expect(profileChanges(before, before), isEmpty);
    });
  });
}
