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

  Future<AuthSession> signUp({
    required String email,
    required String password,
  }) async {
    final client = AikoSupabase.tryClient();
    if (client == null) {
      await _markKnownAccount();
      _session = AuthSession(userId: 'test-user-id', email: email);
      return _session!;
    }

    final response = await client.auth.signUp(email: email, password: password);
    final user = response.user;
    if (user == null) {
      throw const AuthException('Unable to create account right now.');
    }

    await _ensureProfileAndDefaultsExist(user.id, user.email ?? email);
    await _markKnownAccount();
    _session = AuthSession(userId: user.id, email: user.email ?? email);
    return _session!;
  }

  Future<AuthSession> signIn({
    required String email,
    required String password,
  }) async {
    final client = AikoSupabase.tryClient();
    if (client == null) {
      await _markKnownAccount();
      _session = AuthSession(userId: 'test-user-id', email: email);
      return _session!;
    }

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
    final client = AikoSupabase.tryClient();
    if (client == null) {
      throw StateError(
        'Supabase is not initialized. Run with --dart-define-from-file=.env.',
      );
    }

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
      await _ensureProfileAndDefaultsExist(user.id, user.email ?? '');
      await _markKnownAccount();
      _session = AuthSession(
        userId: user.id,
        email: user.email ?? _session?.email ?? '',
      );
    }
    return _session;
  }

  Future<void> _ensureProfileAndDefaultsExist(
    String userId,
    String email,
  ) async {
    final client = AikoSupabase.tryClient();
    if (client != null) {
      try {
        // 1. Ensure Profile
        await client.from('profiles').upsert({
          'id': userId,
          'email': email,
          'display_name': email.split('@').first,
          'base_currency': 'USD',
          'country': 'US',
          'timezone': 'UTC',
          'preferred_theme': 'system',
          'aiko_character_visibility': 'full',
          'aiko_personality_setting': 'supportive',
          'ai_consent_enabled': true,
          'onboarding_status': 'completed',
          'security_status': 'notConfigured',
        });

        // 2. Ensure Default Categories
        final categories = await client
            .from('categories')
            .select()
            .eq('user_id', userId);
        if ((categories as List).isEmpty) {
          await client.from('categories').insert([
            {
              'id': '20000000-0000-0000-0000-000000000001',
              'user_id': userId,
              'name': 'Food and Dining',
              'type': 'expense',
              'group': 'needs',
            },
            {
              'id': '20000000-0000-0000-0000-000000000002',
              'user_id': userId,
              'name': 'Salary',
              'type': 'income',
              'group': 'custom',
            },
          ]);
        }

        // 3. Ensure Default Account
        final accounts = await client
            .from('accounts')
            .select()
            .eq('user_id', userId);
        if ((accounts as List).isEmpty) {
          await client.from('accounts').insert({
            'id': '10000000-0000-0000-0000-000000000001',
            'user_id': userId,
            'name': 'Cash Wallet',
            'type': 'cash',
            'currency': 'USD',
            'opening_balance': 1000.0,
            'current_balance': 1000.0,
            'include_in_net_worth': true,
            'is_active': true,
          });
        }
      } catch (e) {
        // Silent error fallback for offline/sandbox
      }
    }
  }
}
