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
import '../../../core/storage/file_sync_queue.dart';
import '../../../core/storage/local_file_cache.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../../settings/application/profile_avatar_service.dart';
import 'account_file_jobs.dart';
import 'connection_errors.dart';
import 'defaults_seed_marker.dart';
import 'defaults_seeder.dart';
import 'guest_defaults.dart';
import 'guest_mode.dart';
import 'guest_preferences.dart';

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

/// Where a guest's sign-in brings what they made on this device: into the
/// account it created (their profile and accounts become the account's), or
/// into one they already had (the unused Cash and Bank stay behind).
enum GuestClaim { newAccount, existingAccount }

class AuthRepository {
  /// [cancelReminders] defaults to cancelling every scheduled transaction
  /// reminder and [fileQueue] to the app's upload queue; tests replace them.
  AuthRepository({
    SecureStorageService? storage,
    FirebaseAuth? auth,
    Future<void> Function()? cancelReminders,
    FileSyncQueue? fileQueue,
  }) : _storage = storage ?? FlutterSecureStorageService(),
       _auth = auth,
       _cancelRemindersOverride = cancelReminders,
       _fileQueue = fileQueue;
  final SecureStorageService _storage;
  final FirebaseAuth? _auth;
  final Future<void> Function()? _cancelRemindersOverride;
  final FileSyncQueue? _fileQueue;
  AccountFileJobs get _fileJobs =>
      AccountFileJobs(_fileQueue ?? FileSyncQueue.instance);
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
    final guestClaim = GuestMode.isActive
        ? (isNewUser ? GuestClaim.newAccount : GuestClaim.existingAccount)
        : null;
    // Should the app stop before the guest is brought in, restoreSession
    // finishes it the same way.
    if (guestClaim != null) await _writeGuestClaim(user.uid, guestClaim);
    final claimed = await _bringInDeviceData(
      user.uid,
      user.email ?? '',
      isNewUser: isNewUser,
      guestClaim: guestClaim,
      // Also a language picked on Welcome before signing in.
      claimPreferences: true,
    );
    await _storage.write(_knownAccountKey, 'true');
    await _leaveGuestMode();
    await _clearGuestClaim(user.uid);
    return AuthSession(
      userId: user.uid,
      email: user.email ?? '',
      isNewUser: isNewUser,
      claimedRecords: claimed,
    );
  }

  /// After a sign-in: seeds the defaults the account is missing, then moves
  /// in what was made on this device without an account ([guestClaim]: a
  /// guest signing in), and returns how many records were moved. The user
  /// is signed in already, so nothing here fails the sign-in; restoreSession
  /// retries what couldn't be done.
  Future<int> _bringInDeviceData(
    String uid,
    String email, {
    required bool isNewUser,
    required GuestClaim? guestClaim,
    required bool claimPreferences,
  }) async {
    final guestProfile = guestClaim == GuestClaim.newAccount
        ? await _latestGuestProfile()
        : null;
    try {
      await _ensureDefaultsOnce(
        uid,
        email,
        isNewUser: isNewUser,
        guestProfile: guestProfile,
        guestDefaults: guestClaim == null
            ? const GuestDefaults()
            : await _guestDefaults(),
      );
    } catch (error) {
      debugPrint('[auth] defaults seeding failed: $error');
    }
    if (guestClaim == GuestClaim.existingAccount) {
      await _dropUnusedGuestDefaults();
    }
    final migrator = OfflineDataMigrator();
    final claimed = await migrator.claimAnonymousData(uid);
    if (claimPreferences) {
      await GuestPreferences(
        device: _storage,
      ).claim(uid, categoryId: (id) => migrator.claimedCategoryId(uid, id));
    }
    if (guestProfile != null) await _uploadGuestPhoto(uid, guestProfile);
    return claimed;
  }

  /// Queues uploading the photo a guest who signed up picked: it stays the
  /// account's photo ([defaultSeedDocs] keeps its device path), and other
  /// devices get it once uploaded.
  Future<void> _uploadGuestPhoto(String uid, OfflineProfile guest) async {
    final path = guest.avatarPath;
    final url = guest.avatarUrl;
    if (path == null || !LocalFileCache.isDevicePath(path)) return;
    if (url != null && url.isNotEmpty) return;
    try {
      final name = path.substring(path.lastIndexOf('/') + 1);
      final extension = name.contains('.')
          ? name.substring(name.lastIndexOf('.') + 1).toLowerCase()
          : '';
      await ProfileAvatarService().queueUpload(
        ProfileAvatar(
          ownerId: uid,
          localPath: path,
          remotePath: 'users/$uid/avatars/$name',
          contentType: switch (extension) {
            'png' => 'image/png',
            'webp' => 'image/webp',
            _ => 'image/jpeg',
          },
        ),
      );
    } catch (error) {
      debugPrint('[auth] guest photo not queued: $error');
    }
  }

  static String _guestClaimKey(String uid) => 'aiko_guest_claim:$uid';

  Future<void> _writeGuestClaim(String uid, GuestClaim claim) async {
    try {
      await _storage.write(_guestClaimKey(uid), claim.name);
    } catch (error) {
      debugPrint('[auth] guest sign-in not noted: $error');
    }
  }

  Future<GuestClaim?> _readGuestClaim(String uid) async {
    try {
      final stored = await _storage.read(_guestClaimKey(uid));
      return GuestClaim.values.asNameMap()[stored];
    } catch (_) {
      return null;
    }
  }

  Future<void> _clearGuestClaim(String uid) async {
    try {
      await _storage.delete(_guestClaimKey(uid));
    } catch (_) {
      // A stale note only matters while guest mode is on, and it is off.
    }
  }

  /// The defaults the guest gave a budget (see [GuestDefaults]).
  Future<GuestDefaults> _guestDefaults() async {
    try {
      final store = OfflineStore();
      bool guest(OfflineRecord row) =>
          (row.ownerId ?? '').startsWith(OfflineUserContext.localUserIdPrefix);
      return GuestDefaults(
        categories: [
          for (final row in await store.get<OfflineCategory>(localOnly: true))
            if (guest(row) && row.toDomain().isDefault) row.toDomain(),
        ],
        groups: [
          for (final row in await store.get<OfflineCategoryGroup>(
            localOnly: true,
          ))
            if (guest(row) && row.toDomain().isDefault) row.toDomain(),
        ],
      );
    } catch (error) {
      debugPrint('[auth] guest budgets unreadable: $error');
      return const GuestDefaults();
    }
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
    // Nor any guest preference a sign-in couldn't move into its account.
    await GuestPreferences(device: _storage).clear();
  }

  /// Cleans up when the session ended elsewhere: like [signOut], without
  /// signing out again or replacing an anonymous owner [signOut] just made.
  /// A guest has no session to end (Firebase reports "no user" at every
  /// launch), so their reminders, records and preferences stay.
  Future<void> handleSessionEnded() async {
    if (GuestMode.isActive) return;
    await _cancelReminders();
    await OfflineUserContext.leaveSignedInOwner(_storage);
    await GuestPreferences(device: _storage).clear();
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

  /// [hasPendingWrites], counting files too: attachments and the profile
  /// photo wait in the upload queue ([FileSyncQueue]), which runs only while
  /// their owner is signed in on this device. Both get [timeout] to upload.
  Future<bool> hasUnsyncedChanges({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final uid = (_auth ?? FirebaseBackend.auth)?.currentUser?.uid;
    final waiting = await Future.wait([
      hasPendingWrites(timeout: timeout),
      if (uid != null) _fileJobs.waiting(uid, timeout: timeout),
    ]);
    return waiting.contains(true);
  }

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
    // Files waiting to upload would be put back after the server deleted
    // everything: take them off the queue first (a running upload finishes,
    // and its record joins the pending writes checked next).
    final fileJobs = _fileJobs;
    final heldFiles = await fileJobs.hold(uid);
    if (heldFiles == null) throw const NeedsConnectionException();
    try {
      // Changes still queued on this device would be uploaded after the
      // server deleted everything, re-creating documents: upload them first.
      if (await hasPendingWrites(timeout: const Duration(seconds: 15))) {
        throw const NeedsConnectionException();
      }
      await FirebaseBackend.functions
          .httpsCallable('deleteAccount')
          .call<void>();
    } catch (error) {
      // Not deleted: the files upload after all.
      await fileJobs.release(heldFiles);
      if (error is FirebaseFunctionsException && isNetworkError(error)) {
        throw const NeedsConnectionException();
      }
      rethrow;
    }
    // Queued meanwhile (a finished upload deleting the photo it replaced).
    await fileJobs.drop(uid);
    // A deleted account is no longer "known": the next launch shows Welcome.
    await _storage.delete(_knownAccountKey);
    await signOut();
  }

  Future<AuthSession?> restoreSession() async {
    final session = cachedSession();
    if (session != null) {
      // A guest's sign-in that stopped before it finished (the app was
      // closed): finish bringing the guest in the way it started.
      final guest = GuestMode.isActive;
      await _bringInDeviceData(
        session.userId,
        session.email,
        isNewUser: false,
        guestClaim: guest ? await _readGuestClaim(session.userId) : null,
        claimPreferences: guest,
      );
      // Signed in, so not a guest any more.
      await _leaveGuestMode();
      if (guest) await _clearGuestClaim(session.userId);
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
    OfflineProfile? guestProfile,
    GuestDefaults guestDefaults = const GuestDefaults(),
  }) async {
    final marker = DefaultsSeedMarker(_storage);
    if (await marker.isSeeded(uid)) return;
    final complete = await ensureProfileAndDefaultsExist(
      uid,
      email,
      isNewUser: isNewUser,
      guestProfile: guestProfile,
      guestDefaults: guestDefaults,
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

  /// Creates the profile and default category clones that are missing
  /// ([DefaultsSeeder]; offline too). Existing documents are never written:
  /// signing in on another device never resets a profile, budget, or
  /// existing category clone. Returns whether every default is now known to
  /// exist.
  Future<bool> ensureProfileAndDefaultsExist(
    String uid,
    String email, {
    bool isNewUser = false,
    OfflineProfile? guestProfile,
    GuestDefaults guestDefaults = const GuestDefaults(),
  }) => DefaultsSeeder().seed(
    uid,
    defaultSeedDocs(
      uid,
      email,
      guestProfile: guestProfile,
      guestDefaults: guestDefaults,
    ),
    isNewUser: isNewUser,
  );
}

final googleLinkedProvider = StreamProvider<bool>((ref) async* {
  final repository = AuthRepository();
  yield repository.isGoogleLinked();
  yield* repository.authStateChanges().map((_) => repository.isGoogleLinked());
});
