import 'package:aiko/core/storage/secure_storage_service.dart';
import 'package:aiko/core/offline/offline_user_context.dart';
import 'package:aiko/features/auth/data/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('hasKnownAccount returns false on fresh storage', () async {
    final repository = AuthRepository(storage: MemorySecureStorageService());

    expect(await repository.hasKnownAccount(), isFalse);
  });

  test('signOut without cloud sign-in keeps the local data owner', () async {
    // Local-only builds have no account to leave; a new anonymous owner would
    // hide everything the user recorded.
    final storage = MemorySecureStorageService();
    final context = OfflineUserContext(storage: storage);
    final previousId = await context.resolveUserId();
    final repository = AuthRepository(storage: storage);

    await repository.signOut();

    expect(await context.resolveUserId(), previousId);
  });
}
