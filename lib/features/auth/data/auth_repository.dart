import '../../../core/notifications/transaction_reminder_service.dart';
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/firebase/firebase_backend.dart';
import '../../../core/offline/offline_data_migrator.dart';
import '../../../core/offline/offline_store.dart';
import '../../../core/offline/offline_user_context.dart';
import '../../../core/offline/records/records.dart';
import '../../../core/storage/secure_storage_service.dart';
import 'connection_errors.dart';
import 'defaults_seed_marker.dart';
import 'defaults_seeder.dart';
import 'guest_defaults.dart';
import 'guest_mode.dart';

class AuthSession {
  const AuthSession({
    required this.userId,
    required this.email,
    this.isNewUser = false,
    this.claimedRecords = 0,
  });
  final String userId;
  final String email;

  /// The sign-in created the account (a sign-up, or a first Google sign-in),
  /// so the app seeds its first-run defaults.
  final bool isNewUser;

  /// Records made on this device without an account that the sign-in moved
  /// into it. A guest who signs up keeps their own accounts instead of
  /// getting the default ones.
  final int claimedRecords;
}

class AuthRepository {
  /// [cancelReminders] defaults to cancelling every scheduled transaction
  /// reminder; tests replace it.
  AuthRepository({
    SecureStorageService? storage,
    FirebaseAuth? auth,
    Future<void> Function()? cancelReminders,
  }) : _storage = storage ?? FlutterSecureStorageService(),
       _auth = auth,
       _cancelRemindersOverride = cancelReminders;
  final SecureStorageService _storage;
  final FirebaseAuth? _auth;
  final Future<void> Function()? _cancelRemindersOverride;
  Future<void> _cancelReminders() =>
      (_cancelRemindersOverride ??
      TransactionReminderService.instance.cancelAll)();
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
    final isNewUser = credential.additionalUserInfo?.isNewUser ?? false;
    // The user is signed in at this point; failing to seed defaults must not
    // report the sign-in as failed (restoreSession retries it). Defaults go
    // first so the guest records claimed next win over them.
    try {
      await _ensureDefaultsOnce(
        user.uid,
        user.email ?? '',
        isNewUser: isNewUser,
      );
    } catch (error) {
      debugPrint('[auth] defaults seeding failed: $error');
    }
    if (!isNewUser && GuestMode.isActive) await _dropUnusedGuestDefaults();
    final claimed = await OfflineDataMigrator().claimAnonymousData(user.uid);
    await _storage.write(_knownAccountKey, 'true');
    await _leaveGuestMode();
    return AuthSession(
      userId: user.uid,
      email: user.email ?? '',
      isNewUser: isNewUser,
      claimedRecords: claimed,
    );
  }

  /// Uses the app without an account: on this device only, offline
  /// included, until the guest signs in ([GuestMode]).
  Future<void> continueAsGuest() => GuestMode.enter(_storage);

  /// A guest signing in to an account they already have: the Cash and Bank
  /// accounts guest mode started with, if never used, aren't brought into it
  /// ([unusedGuestDefaultAccounts]).
  Future<void> _dropUnusedGuestDefaults() async {
    try {
      final store = OfflineStore();
      final unused = unusedGuestDefaultAccounts(
        await store.get<OfflineAccount>(localOnly: true),
        await store.get<OfflineTransaction>(localOnly: true),
      );
      final batch = RecordBatch();
      for (final account in unused) {
        batch.delete(account);
      }
      await store.commit(batch, localOnly: true);
    } catch (error) {
      debugPrint('[auth] unused guest accounts kept: $error');
    }
  }

  Future<void> _leaveGuestMode() async {
    if (!GuestMode.isActive) return;
    try {
      await GuestMode.leave(_storage);
    } catch (error) {
      debugPrint('[auth] leaving guest mode failed: $error');
    }
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
    await _cancelReminders();
    await auth.signOut();
    await OfflineUserContext.startAnonymousSession(_storage);
  }

  /// Cleans up when the session ended elsewhere: like [signOut], without
  /// signing out again or replacing an anonymous owner [signOut] just made.
  /// A guest has no session to end (Firebase reports "no user" at every
  /// launch), so their reminders and records stay.
  Future<void> handleSessionEnded() async {
    if (GuestMode.isActive) return;
    await _cancelReminders();
    await OfflineUserContext.leaveSignedInOwner(_storage);
  }

  /// Whether changes made on this device are still waiting to upload after
  /// giving them [timeout] to reach the server; offline they stay queued.
  /// The SDK keeps them per user across sign-outs and uploads them the next
  /// time that user signs in on this device.
  Future<bool> hasPendingWrites({
    Duration timeout = const Duration(seconds: 3),
  }) => pendingWritesRemain(
    FirebaseBackend.firestore.waitForPendingWrites,
    timeout: timeout,
  );

  Future<void> resetPassword(String email) =>
      _requiredAuth.sendPasswordResetEmail(email: email);

  /// Deletes the account on the server, then signs out. Throws
  /// [NeedsConnectionException] when the server can't be reached.
  Future<void> deleteAccount() async {
    final uid = (_auth ?? FirebaseBackend.auth)?.currentUser?.uid;
    if (uid == null) throw StateError('Sign in first.');
    try {
      // One read from the server tells "offline" apart from other failures
      // before anything is deleted.
      await FirebaseBackend.firestore
          .collection('users')
          .doc(uid)
          .collection('profiles')
          .doc(uid)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 10));
    } catch (error) {
      if (isNetworkError(error)) throw const NeedsConnectionException();
      rethrow;
    }
    // Changes still queued on this device would be uploaded after the server
    // deleted everything, re-creating documents: upload them first.
    if (await hasPendingWrites(timeout: const Duration(seconds: 15))) {
      throw const NeedsConnectionException();
    }
    try {
      await FirebaseBackend.functions
          .httpsCallable('deleteAccount')
          .call<void>();
    } on FirebaseFunctionsException catch (error) {
      if (isNetworkError(error)) throw const NeedsConnectionException();
      rethrow;
    }
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
      // Signed in, so not a guest any more (a sign-in can stop before it
      // leaves guest mode, e.g. when the app is closed).
      await _leaveGuestMode();
    }
    return session;
  }

  void restoreSessionInBackground() {
    unawaited(restoreSession());
  }

  /// Runs [ensureProfileAndDefaultsExist] once per user on this device instead
  /// of on every launch ([DefaultsSeedMarker]). The marker is only set once
  /// every default is known to exist, so a run that couldn't check (offline,
  /// on a device that hasn't cached them yet) is retried at the next start.
  Future<void> _ensureDefaultsOnce(
    String uid,
    String email, {
    bool isNewUser = false,
  }) async {
    final marker = DefaultsSeedMarker(_storage);
    if (await marker.isSeeded(uid)) return;
    final complete = await ensureProfileAndDefaultsExist(
      uid,
      email,
      isNewUser: isNewUser,
      guestProfile: isNewUser && GuestMode.isActive
          ? await _latestGuestProfile()
          : null,
    );
    if (complete) await marker.markSeeded(uid);
  }

  /// The profile a guest set up on this device, if any: the most recently
  /// saved one of the anonymous owners.
  Future<OfflineProfile?> _latestGuestProfile() async {
    try {
      final profiles = await OfflineStore().get<OfflineProfile>(
        localOnly: true,
      );
      OfflineProfile? latest;
      for (final profile in profiles) {
        if (!profile.id.startsWith(OfflineUserContext.localUserIdPrefix)) {
          continue;
        }
        if (latest == null || profile.updatedAt.isAfter(latest.updatedAt)) {
          latest = profile;
        }
      }
      return latest;
    } catch (error) {
      debugPrint('[auth] guest profile unreadable: $error');
      return null;
    }
  }

  /// Creates the profile and default category clones that are missing, in
  /// one batch that works offline ([DefaultsSeeder]). Existing documents are
  /// never written: signing in on another device never resets a profile,
  /// budget, or existing category clone. Returns whether every default is
  /// now known to exist.
  Future<bool> ensureProfileAndDefaultsExist(
    String uid,
    String email, {
    bool isNewUser = false,
    OfflineProfile? guestProfile,
  }) => DefaultsSeeder().seed(
    uid,
    defaultSeedDocs(uid, email, guestProfile: guestProfile),
    isNewUser: isNewUser,
  );
}

final googleLinkedProvider = StreamProvider<bool>((ref) async* {
  final repository = AuthRepository();
  yield repository.isGoogleLinked();
  yield* repository.authStateChanges().map((_) => repository.isGoogleLinked());
});
