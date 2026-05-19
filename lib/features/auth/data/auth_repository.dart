import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client_provider.dart';

class AuthSession {
  const AuthSession({required this.userId, required this.email});

  final String userId;
  final String email;
}

class AuthRepository {
  AuthSession? _session;

  bool hasActiveSession() {
    final client = AikoSupabase.tryClient();
    return client?.auth.currentSession != null;
  }

  Future<AuthSession> signUp({
    required String email,
    required String password,
  }) async {
    final client = AikoSupabase.tryClient();
    if (client == null) {
      throw StateError(
        'Supabase is not initialized. Run with --dart-define-from-file=.env.',
      );
    }

    final response = await client.auth.signUp(email: email, password: password);
    final user = response.user;
    if (user == null) {
      throw const AuthException('Unable to create account right now.');
    }

    _session = AuthSession(userId: user.id, email: user.email ?? email);
    return _session!;
  }

  Future<AuthSession> signIn({
    required String email,
    required String password,
  }) async {
    final client = AikoSupabase.tryClient();
    if (client == null) {
      throw StateError(
        'Supabase is not initialized. Run with --dart-define-from-file=.env.',
      );
    }

    final response = await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    final user = response.user;
    if (user == null) {
      throw const AuthException('Invalid email or password.');
    }

    _session = AuthSession(userId: user.id, email: user.email ?? email);
    return _session!;
  }

  Future<void> signOut() async {
    final client = AikoSupabase.tryClient();
    if (client != null) {
      await client.auth.signOut();
    }
    _session = null;
  }

  Future<void> resetPassword(String email) async {
    final client = AikoSupabase.tryClient();
    if (client == null) {
      throw StateError(
        'Supabase is not initialized. Run with --dart-define-from-file=.env.',
      );
    }
    await client.auth.resetPasswordForEmail(email);
  }

  Future<AuthSession?> restoreSession() async {
    final user = AikoSupabase.tryClient()?.auth.currentUser;
    if (user != null) {
      _session = AuthSession(
        userId: user.id,
        email: user.email ?? _session?.email ?? '',
      );
    }
    return _session;
  }
}
