import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../../../core/sync/post_signin_data_preparer.dart';

class AuthSession {
  const AuthSession({required this.userId, required this.email});

  final String userId;
  final String email;
}

class AuthRepository {
  AuthRepository({SecureStorageService? storage})
    : _storage = storage ?? FlutterSecureStorageService();

  static const _knownAccountKey = 'aiko_known_account';
  static const googleOAuthRedirectUrl = String.fromEnvironment(
    'GOOGLE_OAUTH_REDIRECT_URL',
    defaultValue: 'aiko://login-callback',
  );

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
      await _cancelPendingDeletion(user.id);
      await _prepareOfflineDataForSync(user.id);
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
    await _cancelPendingDeletion(user.id);
    await _prepareOfflineDataForSync(user.id);
    await _markKnownAccount();
    _session = AuthSession(userId: user.id, email: user.email ?? email);
    return _session!;
  }

  Future<void> _prepareOfflineDataForSync(String userId) {
    return const PostSigninDataPreparer().prepareForSync(userId);
  }

  Stream<AuthState> authStateChanges() {
    final client = AikoSupabase.tryClient();
    return client?.auth.onAuthStateChange ?? const Stream.empty();
  }

  Future<bool> signInWithGoogle() {
    final client = AikoSupabase.requireClient();
    return client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: kIsWeb ? null : googleOAuthRedirectUrl,
    );
  }

  Future<void> signOut() async {
    final client = AikoSupabase.tryClient();
    if (client != null) {
      await client.auth.signOut();
    }
  }

  Future<void> resetPassword(String email) async {
    final client = AikoSupabase.requireClient();
    await client.auth.resetPasswordForEmail(email);
  }

  Future<void> deleteAccount() async {
    final client = AikoSupabase.requireClient();
    final session = client.auth.currentSession;
    if (session == null) {
      throw AuthException('No active session found.');
    }
    final response = await client.functions.invoke('delete-account');
    if (response.status != 200) {
      final data = response.data;
      final message = data is Map && data['error'] is String
          ? data['error'] as String
          : 'Failed to delete account. Please try again.';
      throw AuthException(message);
    }
    await client.auth.signOut();
  }

  Future<void> _cancelPendingDeletion(String userId) async {
    try {
      final client = AikoSupabase.requireClient();
      await client
          .from('profiles')
          .update({'deletion_scheduled_at': null})
          .eq('id', userId);
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[aiko-auth] cancel pending deletion skipped: $error');
      }
    }
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
    await _cancelPendingDeletion(session.userId);
    await _prepareOfflineDataForSync(session.userId);
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
      'base_currency': kDefaultBaseCurrency,
      'country': kDefaultCountry,
      'timezone': 'Asia/Bangkok',
      'preferred_theme': 'system',
      'aiko_character_visibility': 'full',
      'aiko_personality_setting': 'supportive',
      'onboarding_status': 'inProgress',
      'security_status': 'notConfigured',
    });

    final List<Map<String, dynamic>> accounts = await client
        .from('accounts')
        .select('id')
        .eq('user_id', userId);
    if (accounts.isEmpty) {
      await client.from('accounts').insert({
        'user_id': userId,
        'name': 'Cash Wallet',
        'type': 'cash',
        'currency': kDefaultBaseCurrency,
        'current_balance': '0',
        'include_in_net_worth': true,
        'is_active': true,
      });
    }
  }

  Future<void> ensureProfileAndDefaultsExistForTesting(
    String userId,
    String email,
  ) {
    return _ensureProfileAndDefaultsExist(userId, email);
  }
}
