import '../../../core/notifications/transaction_reminder_service.dart';
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/config/app_config.dart';
import '../../../core/firebase/firebase_backend.dart';
import '../../../core/offline/offline_data_migrator.dart';
import '../../../core/offline/offline_user_context.dart';
import '../../../core/offline/records/records.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../../categories/domain/category_defaults.dart';
import 'defaults_seed_marker.dart';

class AuthSession {
  const AuthSession({
    required this.userId,
    required this.email,
    this.isNewUser = false,
  });
  final String userId;
  final String email;

  /// The sign-in created the account (a sign-up, or a first Google sign-in),
  /// so the app seeds its first-run defaults.
  final bool isNewUser;
}

class AuthRepository {
  AuthRepository({SecureStorageService? storage, FirebaseAuth? auth})
    : _storage = storage ?? FlutterSecureStorageService(),
      _auth = auth;
  final SecureStorageService _storage;
  final FirebaseAuth? _auth;
  FirebaseAuth get _requiredAuth =>
      _auth ??
      FirebaseBackend.auth ??
      (throw StateError('Firebase is not configured.'));
  static const _knownAccountKey = 'aiko_known_account';
  static const googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
  );
  static const googleIosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
  );
  static Future<void>? _googleInitFuture;

  Future<bool> hasKnownAccount() async =>
      await _storage.read(_knownAccountKey) == 'true';
  bool hasActiveSession() =>
      (_auth ?? FirebaseBackend.auth)?.currentUser != null;
  AuthSession? cachedSession() {
    final user = (_auth ?? FirebaseBackend.auth)?.currentUser;
    return user == null
        ? null
        : AuthSession(userId: user.uid, email: user.email ?? '');
  }

  Stream<User?> authStateChanges() =>
      (_auth ?? FirebaseBackend.auth)?.userChanges() ?? const Stream.empty();

  Future<AuthSession> _finish(UserCredential credential) async {
    final user = credential.user;
    if (user == null) throw StateError('Sign-in did not return a user.');
    // The user is signed in at this point; failing to seed defaults must not
    // report the sign-in as failed (restoreSession retries it).
    try {
      await _ensureDefaultsOnce(user.uid, user.email ?? '');
    } catch (error) {
      debugPrint('[auth] defaults seeding failed: $error');
    }
    await OfflineDataMigrator().claimAnonymousData(user.uid);
    await _storage.write(_knownAccountKey, 'true');
    return AuthSession(
      userId: user.uid,
      email: user.email ?? '',
      isNewUser: credential.additionalUserInfo?.isNewUser ?? false,
    );
  }

  Future<AuthSession> signUp({
    required String email,
    required String password,
  }) async => _finish(
    await _requiredAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    ),
  );
  Future<AuthSession> signIn({
    required String email,
    required String password,
  }) async => _finish(
    await _requiredAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    ),
  );

  Future<AuthSession?> signInWithGoogle() async {
    if (kIsWeb) {
      return _finish(await _requiredAuth.signInWithPopup(GoogleAuthProvider()));
    }
    _googleInitFuture ??= GoogleSignIn.instance
        .initialize(
          serverClientId: googleWebClientId.isEmpty ? null : googleWebClientId,
          clientId: googleIosClientId.isEmpty ? null : googleIosClientId,
        )
        .catchError((Object error) {
          _googleInitFuture = null;
          throw error;
        });
    await _googleInitFuture;
    try {
      final account = await GoogleSignIn.instance.authenticate(
        scopeHint: ['email'],
      );
      final token = account.authentication.idToken;
      if (token == null) throw StateError('Google did not return an ID token.');
      return await _finish(
        await _requiredAuth.signInWithCredential(
          GoogleAuthProvider.credential(idToken: token),
        ),
      );
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) return null;
      rethrow;
    }
  }

  Future<bool> linkGoogle() async {
    final user = _requiredAuth.currentUser;
    if (user == null) throw StateError('Sign in first.');
    if (kIsWeb) {
      await user.linkWithPopup(GoogleAuthProvider());
    } else {
      await user.linkWithProvider(GoogleAuthProvider());
    }
    return true;
  }

  /// Whether the signed-in user has an email-and-password sign-in, and so a
  /// password to change.
  bool hasPasswordSignIn() =>
      (_auth ?? FirebaseBackend.auth)?.currentUser?.providerData.any(
        (provider) => provider.providerId == 'password',
      ) ??
      false;

  bool isGoogleLinked() =>
      (_auth ?? FirebaseBackend.auth)?.currentUser?.providerData.any(
        (provider) => provider.providerId == 'google.com',
      ) ??
      false;

  Future<void> signOut() async {
    final auth = _auth ?? FirebaseBackend.auth;
    // Local-only builds have no account to leave; starting a new anonymous
    // owner would hide everything the user recorded.
    if (auth == null) return;
    // Reminders name merchants and amounts; the next user mustn't get them.
    await TransactionReminderService.instance.cancelAll();
    await auth.signOut();
    await OfflineUserContext.startAnonymousSession(_storage);
  }

  /// Cleans up when the session ended elsewhere: like [signOut], without
  /// signing out again or replacing an anonymous owner [signOut] just made.
  Future<void> handleSessionEnded() async {
    await TransactionReminderService.instance.cancelAll();
    await OfflineUserContext.leaveSignedInOwner(_storage);
  }

  Future<void> resetPassword(String email) =>
      _requiredAuth.sendPasswordResetEmail(email: email);
  Future<void> deleteAccount() async {
    await FirebaseBackend.functions.httpsCallable('deleteAccount').call<void>();
    // A deleted account is no longer "known": the next launch shows Welcome.
    await _storage.delete(_knownAccountKey);
    await signOut();
  }

  Future<AuthSession?> restoreSession() async {
    final session = cachedSession();
    if (session != null) {
      try {
        await _ensureDefaultsOnce(session.userId, session.email);
      } catch (_) {
        // Existing Firebase cache remains available while disconnected.
      }
      await OfflineDataMigrator().claimAnonymousData(session.userId);
    }
    return session;
  }

  void restoreSessionInBackground() {
    unawaited(restoreSession());
  }

  /// Runs [ensureProfileAndDefaultsExist] once per user on this device instead
  /// of on every launch ([DefaultsSeedMarker]).
  Future<void> _ensureDefaultsOnce(String uid, String email) async {
    final marker = DefaultsSeedMarker(_storage);
    if (await marker.isSeeded(uid)) return;
    await ensureProfileAndDefaultsExist(uid, email);
    await marker.markSeeded(uid);
  }

  /// A single transaction only inserts missing defaults. Signing in on another
  /// device never resets a profile, budget, or existing category clone.
  Future<void> ensureProfileAndDefaultsExist(String uid, String email) async {
    final root = FirebaseBackend.firestore.collection('users').doc(uid);
    final rows =
        <DocumentReference<Map<String, dynamic>>, Map<String, dynamic>>{
          root.collection('profiles').doc(uid): {
            'id': uid,
            'email': email,
            'display_name': email.contains('@')
                ? email.split('@').first
                : email,
            'base_currency': kDefaultBaseCurrency,
            'country': kDefaultCountry,
            'timezone': 'Asia/Bangkok',
            'preferred_theme': 'system',
            'aiko_character_visibility': 'full',
            'aiko_personality_setting': 'supportive',
            'security_status': 'notConfigured',
            'gender': 'preferNotToSay',
            'updated_at': DateTime.now().toUtc().toIso8601String(),
            'version': 1,
          },
        };
    for (final template in CategoryGroupDefaults.all) {
      final group = CategoryGroupDefaults.cloneForUser(
        userId: uid,
        template: template,
      ).toOffline(userId: uid);
      rows[root.collection('category_groups').doc(group.id)] = RecordCodecs
          .categoryGroups
          .toRow(group);
    }
    for (final template in CategoryDefaults.all) {
      final category = CategoryDefaults.cloneForUser(
        userId: uid,
        template: template,
      ).toOffline(userId: uid);
      rows[root.collection('categories').doc(category.id)] = RecordCodecs
          .categories
          .toRow(category);
    }
    await FirebaseBackend.firestore.runTransaction((transaction) async {
      final refs = rows.keys.toList();
      final snapshots = await Future.wait(refs.map(transaction.get));
      for (var i = 0; i < refs.length; i++) {
        if (!snapshots[i].exists) transaction.set(refs[i], rows[refs[i]]!);
      }
    });
  }
}

final googleLinkedProvider = StreamProvider<bool>((ref) async* {
  final repository = AuthRepository();
  yield repository.isGoogleLinked();
  yield* repository.authStateChanges().map((_) => repository.isGoogleLinked());
});
