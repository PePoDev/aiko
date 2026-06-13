import 'package:aiko/core/storage/secure_storage_service.dart';
import 'package:aiko/features/auth/data/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
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
