import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../../../core/storage/secure_storage_service.dart';

class AuthSession {
  const AuthSession({required this.userId, required this.email});

  final String userId;
  final String email;
}

class AuthRepository {
  AuthRepository({
    SecureStorageService? storage,
    AuthBootstrapGateway? bootstrapGateway,
    AuthOAuthSignInGateway? oauthGateway,
  }) : _storage = storage ?? FlutterSecureStorageService(),
       _bootstrapGateway = bootstrapGateway,
       _oauthGateway = oauthGateway;

  static const _knownAccountKey = 'aiko_known_account';
  static const googleOAuthRedirectUrl = String.fromEnvironment(
    'GOOGLE_OAUTH_REDIRECT_URL',
    defaultValue: 'aiko://login-callback',
  );

  final SecureStorageService _storage;
  final AuthBootstrapGateway? _bootstrapGateway;
  final AuthOAuthSignInGateway? _oauthGateway;
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

  Stream<AuthState> authStateChanges() {
    final gateway = _oauthGateway ?? _trySupabaseOAuthGateway();
    return gateway?.authStateChanges() ?? const Stream.empty();
  }

  Future<bool> signInWithGoogle() {
    final gateway = _oauthGateway ?? _requireSupabaseOAuthGateway();
    return gateway.signInWithOAuth(
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
    try {
      final userId = session.user.id;
      await client.auth.admin.deleteUser(userId);
    } on AuthException {
      await client.from('profiles').delete().eq('id', session.user.id);
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
    final gateway =
        _bootstrapGateway ??
        SupabaseAuthBootstrapGateway(AikoSupabase.requireClient());

    await gateway.upsert('profiles', {
      'id': userId,
      'email': email,
      'display_name': email.contains('@') ? email.split('@').first : email,
      'base_currency': 'THB',
      'country': 'TH',
      'timezone': 'Asia/Bangkok',
      'preferred_theme': 'system',
      'aiko_character_visibility': 'full',
      'aiko_personality_setting': 'supportive',
      'ai_consent_enabled': false,
      'onboarding_status': 'inProgress',
      'security_status': 'notConfigured',
    });

    final accounts = await gateway.selectIds('accounts', userId: userId);
    if (accounts.isEmpty) {
      await gateway.insert('accounts', {
        'user_id': userId,
        'name': 'Cash Wallet',
        'type': 'cash',
        'currency': 'THB',
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

  AuthOAuthSignInGateway? _trySupabaseOAuthGateway() {
    final client = AikoSupabase.tryClient();
    if (client == null) {
      return null;
    }
    return SupabaseAuthOAuthSignInGateway(client);
  }

  AuthOAuthSignInGateway _requireSupabaseOAuthGateway() {
    return SupabaseAuthOAuthSignInGateway(AikoSupabase.requireClient());
  }
}

abstract interface class AuthOAuthSignInGateway {
  Stream<AuthState> authStateChanges();

  Future<bool> signInWithOAuth(OAuthProvider provider, {String? redirectTo});
}

class SupabaseAuthOAuthSignInGateway implements AuthOAuthSignInGateway {
  const SupabaseAuthOAuthSignInGateway(this._client);

  final SupabaseClient _client;

  @override
  Stream<AuthState> authStateChanges() {
    return _client.auth.onAuthStateChange;
  }

  @override
  Future<bool> signInWithOAuth(OAuthProvider provider, {String? redirectTo}) {
    return _client.auth.signInWithOAuth(provider, redirectTo: redirectTo);
  }
}

abstract interface class AuthBootstrapGateway {
  Future<void> upsert(String table, Map<String, Object?> values);

  Future<List<Map<String, dynamic>>> selectIds(
    String table, {
    required String userId,
  });

  Future<void> insert(String table, Object values);
}

class SupabaseAuthBootstrapGateway implements AuthBootstrapGateway {
  const SupabaseAuthBootstrapGateway(this._client);

  final SupabaseClient _client;

  @override
  Future<void> upsert(String table, Map<String, Object?> values) {
    return _client.from(table).upsert(values);
  }

  @override
  Future<List<Map<String, dynamic>>> selectIds(
    String table, {
    required String userId,
  }) {
    return _client.from(table).select('id').eq('user_id', userId);
  }

  @override
  Future<void> insert(String table, Object values) {
    return _client.from(table).insert(values);
  }
}
