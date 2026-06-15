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

  /// One-time local cleanup run on every sign-in/restore (idempotent once done).
  /// See [PostSigninDataPreparer] for the full step list — this method just
  /// delegates so the auth repository stays free of brick / migrator concerns
  ///
  Future<void> _prepareOfflineDataForSync(String userId) {
    return const PostSigninDataPreparer().prepareForSync(userId);
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

  /// Requests account deletion. The server (`delete-account` Edge Function)
  /// schedules a hard delete after a 3-day grace period and emails the user;
  /// the actual purge — which needs the secret key the app never holds — is done
  /// later by the `purge-deleted-accounts` job. We sign out so the next sign-in
  /// is what cancels the deletion (see [_cancelPendingDeletion]). Local data is
  /// intentionally left in place: it re-syncs on a cancel-login, and is removed
  /// server-side if the grace period elapses.
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

  /// Cancels a pending account deletion by clearing `deletion_scheduled_at`.
  /// Called on every successful sign-in/restore: logging back in within the
  /// 3-day grace period undoes the deletion. Best-effort and idempotent — a
  /// no-op when nothing is scheduled.
  Future<void> _cancelPendingDeletion(String userId) async {
    try {
      final gateway =
          _bootstrapGateway ??
          SupabaseAuthBootstrapGateway(AikoSupabase.requireClient());
      await gateway.clearDeletionSchedule(userId);
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
    // Restoring a session counts as logging in — cancel any pending deletion so
    // a user who returns within the grace period keeps their account.
    await _cancelPendingDeletion(session.userId);
    // Seed default categories and reclaim any data still orphaned under an
    // anonymous `local:` id from a session where the user used the app before
    // signing in, so both reach Supabase.
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
    final gateway =
        _bootstrapGateway ??
        SupabaseAuthBootstrapGateway(AikoSupabase.requireClient());

    await gateway.upsert('profiles', {
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

    final accounts = await gateway.selectIds('accounts', userId: userId);
    if (accounts.isEmpty) {
      await gateway.insert('accounts', {
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

  /// Clears `profiles.deletion_scheduled_at` for [userId], cancelling a pending
  /// account deletion. No-op if nothing is scheduled.
  Future<void> clearDeletionSchedule(String userId);
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

  @override
  Future<void> clearDeletionSchedule(String userId) {
    return _client
        .from('profiles')
        .update({'deletion_scheduled_at': null})
        .eq('id', userId);
  }
}
