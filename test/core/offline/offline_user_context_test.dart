import 'package:aiko/core/offline/offline_user_context.dart';
import 'package:aiko/core/storage/secure_storage_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OfflineUserContext.localUserIdPrefix', () {
    test('is the documented anonymous prefix', () {
      expect(OfflineUserContext.localUserIdPrefix, 'local:');
    });
  });

  group('OfflineUserContext.resolveUserId', () {
    test('mints a local-prefixed UUID when nothing is cached', () async {
      final storage = MemorySecureStorageService();
      final context = OfflineUserContext(storage: storage);

      final id = await context.resolveUserId();

      expect(id, startsWith(OfflineUserContext.localUserIdPrefix));
      // The stored value round-trips on the next read.
      expect(await context.resolveUserId(), equals(id));
    });

    test('returns the same cached id across calls', () async {
      final storage = MemorySecureStorageService();
      final context = OfflineUserContext(storage: storage);
      final first = await context.resolveUserId();
      final second = await context.resolveUserId();

      expect(first, second);
    });

    test('persists the signed-in id only when it changes', () async {
      OfflineUserContext.resetPersistedUserIdCache();
      addTearDown(OfflineUserContext.resetPersistedUserIdCache);
      final storage = _CountingStorage();
      String? signedIn = 'user-a';
      final context = OfflineUserContext(
        storage: storage,
        signedInUserId: () => signedIn,
      );

      await Future.wait([context.resolveUserId(), context.resolveUserId()]);
      expect(await context.resolveUserId(), 'user-a');
      expect(storage.writes, 1);

      signedIn = 'user-b';
      expect(await context.resolveUserId(), 'user-b');
      expect(storage.writes, 2);

      // Signing out starts a local session; signing back in persists again.
      signedIn = null;
      await OfflineUserContext.startAnonymousSession(storage);
      final local = await context.resolveUserId();
      expect(local, startsWith(OfflineUserContext.localUserIdPrefix));
      signedIn = 'user-b';
      await context.resolveUserId();
      expect(await storage.read('aiko_offline_user_id'), 'user-b');
      expect(storage.writes, 4);
    });
  });
}

class _CountingStorage extends MemorySecureStorageService {
  int writes = 0;

  @override
  Future<void> write(String key, String value) {
    writes++;
    return super.write(key, value);
  }
}
