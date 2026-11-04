import 'package:aiko/core/security/app_lock.dart';
import 'package:aiko/core/storage/secure_storage_service.dart';
import 'package:aiko/features/settings/domain/profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late MemorySecureStorageService storage;
  late DateTime now;
  late AppLockStore store;

  setUp(() {
    storage = MemorySecureStorageService();
    now = DateTime(2026, 10, 19, 12);
    store = AppLockStore(storage, clock: () => now);
  });

  test('off until a PIN is set; the PIN is not stored as typed', () async {
    expect(await store.status(), SecurityStatus.notConfigured);
    await store.setPin('2580');
    expect(await store.status(), SecurityStatus.pinEnabled);
    expect(await storage.read('aiko_app_lock_pin'), isNot(contains('2580')));
    expect(await store.check('2580'), isA<PinAccepted>());
  });

  test('only 4 to 6 digits make a PIN', () {
    expect(AppLockStore.isValidPin('1234'), isTrue);
    expect(AppLockStore.isValidPin('123456'), isTrue);
    expect(AppLockStore.isValidPin('123'), isFalse);
    expect(AppLockStore.isValidPin('1234567'), isFalse);
    expect(AppLockStore.isValidPin('12a4'), isFalse);
    expect(() => store.setPin('12'), throwsArgumentError);
  });

  test(
    'five wrong PINs lock out, longer each time, and survive a restart',
    () async {
      await store.setPin('2580');
      for (var left = 4; left >= 1; left--) {
        final result = await store.check('0000');
        expect((result as PinRejected).triesLeft, left);
      }
      final first = await store.check('0000');
      expect(
        (first as PinLockedOut).until,
        now.add(const Duration(seconds: 30)),
      );
      // Even the right PIN waits, also in a new run of the app.
      final restarted = AppLockStore(storage, clock: () => now);
      expect(await restarted.check('2580'), isA<PinLockedOut>());
      expect(await restarted.status(), SecurityStatus.lockedOut);

      now = now.add(const Duration(seconds: 31));
      for (var i = 0; i < 4; i++) {
        await store.check('0000');
      }
      final second = await store.check('0000');
      expect(
        (second as PinLockedOut).until,
        now.add(const Duration(minutes: 1)),
      );
    },
  );

  test('the right PIN or biometrics clears wrong tries', () async {
    await store.setPin('2580');
    await store.check('0000');
    await store.check('2580');
    expect((await store.check('0000') as PinRejected).triesLeft, 4);
    await store.unlocked();
    expect((await store.check('0000') as PinRejected).triesLeft, 4);
  });

  test('biometrics count only while the lock is on', () async {
    await store.setPin('2580');
    await store.setBiometrics(true);
    expect(await store.status(), SecurityStatus.biometricEnabled);
    await store.disable();
    expect(await store.usesBiometrics, isFalse);
    expect(await store.status(), SecurityStatus.notConfigured);
  });
}
