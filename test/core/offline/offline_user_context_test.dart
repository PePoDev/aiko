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

    test('isLocalOnlyUser is true for a freshly-minted id', () async {
      final context = OfflineUserContext(storage: MemorySecureStorageService());
      // ignore: unused_local_variable
      final id = await context.resolveUserId();
      expect(await context.isLocalOnlyUser, isTrue);
    });
  });
}
