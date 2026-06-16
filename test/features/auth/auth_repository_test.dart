import 'package:aiko/core/storage/secure_storage_service.dart';
import 'package:aiko/features/auth/data/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('hasKnownAccount returns false on fresh storage', () async {
    final repository = AuthRepository(storage: MemorySecureStorageService());

    expect(await repository.hasKnownAccount(), isFalse);
  });
}
