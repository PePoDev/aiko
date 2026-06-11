import 'package:aiko/core/storage/secure_storage_service.dart';
import 'package:aiko/features/auth/data/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('cloud bootstrap does not seed system categories', () async {
    final gateway = _FakeAuthBootstrapGateway();
    final repository = AuthRepository(
      storage: MemorySecureStorageService(),
      bootstrapGateway: gateway,
    );

    await repository.ensureProfileAndDefaultsExistForTesting(
      'user-id',
      'user@example.com',
    );

    expect(gateway.insertedTables, isNot(contains('categories')));
    expect(gateway.insertedTables, contains('accounts'));
    expect(gateway.upsertedTables, contains('profiles'));
  });

  test('google sign in starts Supabase OAuth with app callback', () async {
    final gateway = _FakeOAuthSignInGateway();
    final repository = AuthRepository(
      storage: MemorySecureStorageService(),
      oauthGateway: gateway,
    );

    final launched = await repository.signInWithGoogle();

    expect(launched, isTrue);
    expect(gateway.provider, OAuthProvider.google);
    expect(gateway.redirectTo, AuthRepository.googleOAuthRedirectUrl);
  });
}

class _FakeAuthBootstrapGateway implements AuthBootstrapGateway {
  final insertedTables = <String>[];
  final upsertedTables = <String>[];

  @override
  Future<void> insert(String table, Object values) async {
    insertedTables.add(table);
  }

  @override
  Future<List<Map<String, dynamic>>> selectIds(
    String table, {
    required String userId,
  }) async {
    return const [];
  }

  @override
  Future<void> upsert(String table, Map<String, Object?> values) async {
    upsertedTables.add(table);
  }
}

class _FakeOAuthSignInGateway implements AuthOAuthSignInGateway {
  OAuthProvider? provider;
  String? redirectTo;

  @override
  Stream<AuthState> authStateChanges() => const Stream.empty();

  @override
  Future<bool> signInWithOAuth(
    OAuthProvider provider, {
    String? redirectTo,
  }) async {
    this.provider = provider;
    this.redirectTo = redirectTo;
    return true;
  }
}
