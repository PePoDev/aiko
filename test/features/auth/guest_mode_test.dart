import 'package:aiko/app/locale_controller.dart';
import 'package:aiko/core/offline/offline_user_context.dart';
import 'package:aiko/core/storage/secure_storage_service.dart';
import 'package:aiko/features/auth/data/auth_repository.dart';
import 'package:aiko/features/auth/data/guest_mode.dart';
import 'package:aiko/features/auth/data/guest_preferences.dart';
import 'package:aiko/features/transactions/data/transaction_rule_store.dart';
import 'package:flutter_test/flutter_test.dart';

class _BrokenStorage extends MemorySecureStorageService {
  @override
  Future<String?> read(String key) async => throw StateError('locked');
}

void main() {
  setUp(() {
    GuestMode.resetForTesting();
    OfflineUserContext.resetPersistedUserIdCache();
  });
  tearDown(GuestMode.resetForTesting);

  test('a fresh device is not a guest', () async {
    expect(await GuestMode.restore(MemorySecureStorageService()), isFalse);
    expect(GuestMode.isActive, isFalse);
  });

  test('the choice survives a restart until the guest signs in', () async {
    final storage = MemorySecureStorageService();

    await GuestMode.enter(storage);
    expect(GuestMode.isActive, isTrue);

    GuestMode.resetForTesting(); // a new app start
    expect(await GuestMode.restore(storage), isTrue);

    await GuestMode.leave(storage);
    expect(GuestMode.isActive, isFalse);
    expect(await GuestMode.restore(storage), isFalse);
  });

  test('unreadable storage starts on Welcome', () async {
    expect(await GuestMode.restore(_BrokenStorage()), isFalse);
  });

  test('guest records never use a previous account owner', () async {
    final storage = MemorySecureStorageService();
    final signedIn = OfflineUserContext(
      storage: storage,
      signedInUserId: () => 'real-uid',
    );
    expect(await signedIn.resolveUserId(), 'real-uid');

    await GuestMode.enter(storage);

    final guestId = await OfflineUserContext(
      storage: storage,
      signedInUserId: () => null,
    ).resolveUserId();
    expect(guestId, startsWith(OfflineUserContext.localUserIdPrefix));
  });

  test('entering again keeps the guest owner and their records', () async {
    final storage = MemorySecureStorageService();
    final context = OfflineUserContext(
      storage: storage,
      signedInUserId: () => null,
    );
    await GuestMode.enter(storage);
    final first = await context.resolveUserId();
    await storage.write(TransactionRuleStore.storageKey, '{}');

    await GuestMode.enter(storage);

    expect(await context.resolveUserId(), first);
    expect(await storage.read(TransactionRuleStore.storageKey), '{}');
  });

  test('a new guest starts without earlier guest preferences, in the '
      'language picked on Welcome', () async {
    final storage = MemorySecureStorageService();
    await OfflineUserContext(
      storage: storage,
      signedInUserId: () => 'real-uid',
    ).resolveUserId();
    await storage.write(TransactionRuleStore.storageKey, '{}');
    await storage.write(GuestPreferences.travelKey, '{}');
    await storage.write(AppLocaleController.languageKey, 'th');

    await GuestMode.enter(storage);

    expect(await storage.read(TransactionRuleStore.storageKey), isNull);
    expect(await storage.read(GuestPreferences.travelKey), isNull);
    expect(await storage.read(AppLocaleController.languageKey), 'th');
  });

  group('AuthRepository', () {
    test('continueAsGuest enters guest mode', () async {
      final storage = MemorySecureStorageService();

      await AuthRepository(storage: storage).continueAsGuest();

      expect(GuestMode.isActive, isTrue);
      GuestMode.resetForTesting();
      expect(await GuestMode.restore(storage), isTrue);
    });

    test('a guest keeps reminders and records when Firebase reports no '
        'user', () async {
      final storage = MemorySecureStorageService();
      var cancelled = 0;
      final repository = AuthRepository(
        storage: storage,
        cancelReminders: () async => cancelled++,
      );
      await repository.continueAsGuest();
      final context = OfflineUserContext(
        storage: storage,
        signedInUserId: () => null,
      );
      final owner = await context.resolveUserId();

      await repository.handleSessionEnded();

      expect(cancelled, 0);
      expect(await context.resolveUserId(), owner);
    });

    test(
      'an ended session cancels reminders and leaves the account owner',
      () async {
        final storage = MemorySecureStorageService();
        var cancelled = 0;
        await OfflineUserContext(
          storage: storage,
          signedInUserId: () => 'real-uid',
        ).resolveUserId();

        await AuthRepository(
          storage: storage,
          cancelReminders: () async => cancelled++,
        ).handleSessionEnded();

        expect(cancelled, 1);
        final owner = await OfflineUserContext(
          storage: storage,
          signedInUserId: () => null,
        ).resolveUserId();
        expect(owner, startsWith(OfflineUserContext.localUserIdPrefix));
      },
    );
  });
}
