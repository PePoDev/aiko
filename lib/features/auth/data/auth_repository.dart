import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
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

  /// Browser-redirect callback for the OAuth flows that still need it:
  /// `linkGoogle` (identity linking has no native equivalent) and web sign-in.
  static const googleOAuthRedirectUrl = String.fromEnvironment(
    'GOOGLE_OAUTH_REDIRECT_URL',
    defaultValue: 'aiko://login-callback',
  );

  /// Google "Web application" OAuth client id. Passed as `serverClientId` so
  /// the native sign-in returns an ID token whose audience Supabase trusts —
  /// it must match the Client ID configured on Supabase's Google provider.
  /// Injected at build time: `--dart-define=GOOGLE_WEB_CLIENT_ID=...`.
  static const googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
  );

  /// Google "iOS" OAuth client id. Required on iOS/macOS; ignored on Android.
  /// Injected at build time: `--dart-define=GOOGLE_IOS_CLIENT_ID=...`.
  static const googleIosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
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

  /// Signs in with Google using the platform's native account picker (no
  /// browser hop) on Android/iOS: it obtains a Google ID token and exchanges it
  /// for a Supabase session via [GoTrueClient.signInWithIdToken].
  ///
  /// Returns the established [AuthSession], or `null` when nothing was signed
  /// in — either the user dismissed the native picker, or (on web) a full-page
  /// redirect took over and the session will be restored on reload. Throws an
  /// [AuthException]/[StateError] on a real failure.
  Future<AuthSession?> signInWithGoogle() async {
    final client = AikoSupabase.requireClient();

    if (kIsWeb) {
      // Web has no native picker; fall back to the redirect flow. This
      // navigates the page away, so nothing after it runs — the session is
      // detected when the app reloads at the callback URL.
      await client.auth.signInWithOAuth(OAuthProvider.google);
      return null;
    }

    if (googleWebClientId.isEmpty) {
      throw StateError(
        'Google sign-in is not configured (missing GOOGLE_WEB_CLIENT_ID).',
      );
    }

    final googleSignIn = GoogleSignIn.instance;
    await _ensureGoogleSignInInitialized();
    if (!googleSignIn.supportsAuthenticate()) {
      throw StateError(
        'Native Google sign-in is not supported on this platform.',
      );
    }

    final GoogleSignInAccount account;
    try {
      // Interactive sign-in; surfaces the native account picker. `scopeHint`
      // asks Google to include the email so the returned ID token carries it.
      account = await googleSignIn.authenticate(scopeHint: const ['email']);
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) {
        return null; // User dismissed the account picker.
      }
      rethrow;
    }

    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw const AuthException('Google sign-in did not return an ID token.');
    }

    final response = await client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
    );
    final user = response.user;
    if (user == null) {
      throw const AuthException('Google sign-in failed.');
    }

    final email = user.email ?? '';
    await _ensureProfileAndDefaultsExist(user.id, email);
    await _prepareOfflineDataForSync(user.id);
    await _markKnownAccount();
    _session = AuthSession(userId: user.id, email: email);
    return _session!;
  }

  /// `GoogleSignIn.instance` is a process-wide singleton that must be
  /// initialized exactly once before [GoogleSignIn.authenticate]. The future is
  /// memoized so repeated sign-in attempts (or multiple [AuthRepository]
  /// instances) share a single initialize call; a failed init is cleared so a
  /// later attempt can retry.
  static Future<void>? _googleInitFuture;

  Future<void> _ensureGoogleSignInInitialized() {
    final existing = _googleInitFuture;
    if (existing != null) return existing;

    final future = GoogleSignIn.instance.initialize(
      serverClientId: googleWebClientId,
      clientId: googleIosClientId.isNotEmpty ? googleIosClientId : null,
    );
    _googleInitFuture = future;
    return future.catchError((Object error) {
      _googleInitFuture = null;
      throw error;
    });
  }

  /// Links a Google identity to the already signed-in account (e.g. an
  /// email/password user adding Google sign-in). Opens the OAuth flow; the
  /// deep-link callback returns to the app and fires [authStateChanges].
  /// Requires "Manual linking" enabled in Supabase Auth settings.
  Future<bool> linkGoogle() {
    final client = AikoSupabase.requireClient();
    return client.auth.linkIdentity(
      OAuthProvider.google,
      redirectTo: kIsWeb ? null : googleOAuthRedirectUrl,
    );
  }

  /// Whether the signed-in user already has a Google identity linked. Reads the
  /// cached user (no network call); false when signed out.
  bool isGoogleLinked() {
    final identities = AikoSupabase.tryClient()?.auth.currentUser?.identities;
    return identities?.any((i) => i.provider == 'google') ?? false;
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
    if (client.auth.currentSession == null) {
      throw AuthException('No active session found.');
    }
    // Immediate, permanent. The `delete_account` RPC (SECURITY DEFINER) removes
    // the profile (cascades finance data) and the auth login in one shot.
    await client.rpc('delete_account');
    await client.auth.signOut();
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

/// True when the signed-in user has a Google identity linked. Emits the current
/// state immediately, then re-emits on every auth change so the Profile entry
/// flips to "connected" once the OAuth link callback returns.
final googleLinkedProvider = StreamProvider<bool>((ref) async* {
  final repo = AuthRepository();
  yield repo.isGoogleLinked();
  yield* repo.authStateChanges().map((_) => repo.isGoogleLinked());
});
