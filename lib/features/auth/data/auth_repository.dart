import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../../../core/storage/secure_storage_service.dart';

class AuthSession {
  const AuthSession({required this.userId, required this.email});

  final String userId;
  final String email;
}

class AuthRepository {
  AuthRepository({SecureStorageService? storage})
    : _storage = storage ?? FlutterSecureStorageService();

  static const _knownAccountKey = 'aiko_known_account';

  final SecureStorageService _storage;
  AuthSession? _session;

  Future<bool> hasKnownAccount() async {
    return await _storage.read(_knownAccountKey) == 'true';
  }

  Future<void> _markKnownAccount() {
    return _storage.write(_knownAccountKey, 'true');
  }

  bool hasActiveSession() {
    final client = AikoSupabase.tryClient();
    return client?.auth.currentSession != null;
  }

  AuthSession? cachedSession() {
    final session = AikoSupabase.tryClient()?.auth.currentSession;
    final user = session?.user;
    if (user == null) {
      return null;
    }

    _session = AuthSession(
      userId: user.id,
      email: user.email ?? _session?.email ?? '',
    );
    return _session;
  }

  void restoreSessionInBackground() {
    final session = cachedSession();
    if (session == null) {
      return;
    }

    unawaited(_restoreSessionDefaults(session));
  }

  Future<AuthSession> signUp({
    required String email,
    required String password,
  }) async {
    final client = AikoSupabase.requireClient();

    final response = await client.auth.signUp(email: email, password: password);
    final user = response.user;
    if (user == null) {
      throw const AuthException('Unable to create account right now.');
    }

    if (client.auth.currentSession != null) {
      await _ensureProfileAndDefaultsExist(user.id, user.email ?? email);
    }
    await _markKnownAccount();
    _session = AuthSession(userId: user.id, email: user.email ?? email);
    return _session!;
  }

  Future<AuthSession> signIn({
    required String email,
    required String password,
  }) async {
    final client = AikoSupabase.requireClient();

    final response = await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    final user = response.user;
    if (user == null) {
      throw const AuthException('Invalid email or password.');
    }

    await _ensureProfileAndDefaultsExist(user.id, user.email ?? email);
    await _markKnownAccount();
    _session = AuthSession(userId: user.id, email: user.email ?? email);
    return _session!;
  }

  Future<void> signInWithGoogle() async {
    final client = AikoSupabase.requireClient();
    await client.auth.signInWithOAuth(OAuthProvider.google);
  }

  Future<void> signOut() async {
    final client = AikoSupabase.tryClient();
    if (client != null) {
      await client.auth.signOut();
    }
    _session = null;
  }

  Future<void> resetPassword(String email) async {
    final client = AikoSupabase.requireClient();
    await client.auth.resetPasswordForEmail(email);
  }

  Future<AuthSession?> restoreSession() async {
    final session = cachedSession();
    if (session != null) {
      await _restoreSessionDefaults(session);
    }
    return _session;
  }

  Future<void> _restoreSessionDefaults(AuthSession session) async {
    try {
      await _ensureProfileAndDefaultsExist(session.userId, session.email);
    } catch (_) {
      // A cached Supabase session is enough to continue offline. Local data
      // will be read from Brick and queued writes will sync when online.
    }
    try {
      await _markKnownAccount();
    } catch (_) {
      // Remembering a known account should not block startup.
    }
  }

  Future<void> _ensureProfileAndDefaultsExist(
    String userId,
    String email,
  ) async {
    final client = AikoSupabase.requireClient();
    await client.from('profiles').upsert({
      'id': userId,
      'email': email,
      'display_name': email.contains('@') ? email.split('@').first : email,
      'base_currency': 'USD',
      'country': 'US',
      'timezone': 'UTC',
      'preferred_theme': 'system',
      'aiko_character_visibility': 'full',
      'aiko_personality_setting': 'supportive',
      'ai_consent_enabled': false,
      'onboarding_status': 'inProgress',
      'security_status': 'notConfigured',
    });

    final categories = await client
        .from('categories')
        .select('id')
        .eq('user_id', userId);
    if (categories.isEmpty) {
      await client.from('categories').insert([
        {
          'user_id': userId,
          'name': 'Food and Dining',
          'type': 'expense',
          'group': 'needs',
        },
        {
          'user_id': userId,
          'name': 'Salary',
          'type': 'income',
          'group': 'custom',
        },
      ]);
    }

    final accounts = await client
        .from('accounts')
        .select('id')
        .eq('user_id', userId);
    if (accounts.isEmpty) {
      await client.from('accounts').insert({
        'user_id': userId,
        'name': 'Cash Wallet',
        'type': 'cash',
        'currency': 'USD',
        'opening_balance': '0',
        'current_balance': '0',
        'include_in_net_worth': true,
        'is_active': true,
      });
    }
  }
}
