import 'package:flutter/foundation.dart';

import '../../../core/firebase/firebase_backend.dart';
import '../../../core/offline/offline_user_context.dart';
import '../../../core/storage/secure_storage_service.dart';
import 'guest_preferences.dart';

/// A cloud build used without an account ("guest"): the app runs on the
/// local record store under the anonymous local owner, offline included,
/// until the guest signs in and their records are claimed into Firestore
/// (`AuthRepository` then leaves guest mode).
///
/// The choice is kept on the device so that app starts, and AikoApp's
/// handling of signed-out auth events, don't send a guest back to Welcome.
/// Local-only builds never use it: they have no account to sign in to.
abstract final class GuestMode {
  static const _key = 'aiko_guest_mode';

  static bool _active = false;

  /// Whether this device is used without an account, as of the last
  /// [restore], [enter] or [leave].
  static bool get isActive => _active;

  /// Whether the app is used as a guest right now: a cloud build in guest
  /// mode with nobody signed in. Screens offer signing in then.
  static bool get isCurrent =>
      _active && FirebaseBackend.isConfigured && FirebaseBackend.userId == null;

  /// Reads the stored choice. Call once at startup, before the first frame.
  static Future<bool> restore([SecureStorageService? storage]) async {
    try {
      _active =
          await (storage ?? FlutterSecureStorageService()).read(_key) == 'true';
    } catch (error) {
      debugPrint('[auth] guest mode unreadable: $error');
      _active = false;
    }
    return _active;
  }

  /// Starts using the app without an account. A previous account's owner id
  /// is replaced by an anonymous one first, so guest records never mix with
  /// it; a new owner starts without earlier guest preferences too. Entering
  /// again as the same guest keeps their records and preferences.
  static Future<void> enter(SecureStorageService storage) async {
    // Active for this run even if storing the choice fails.
    _active = true;
    final context = OfflineUserContext(
      storage: storage,
      signedInUserId: () => null,
    );
    final before = await context.resolveUserId();
    await OfflineUserContext.leaveSignedInOwner(storage);
    if (await context.resolveUserId() != before) {
      await GuestPreferences(device: storage).clear();
    }
    await storage.write(_key, 'true');
  }

  /// Ends guest mode (the guest signed in).
  static Future<void> leave(SecureStorageService storage) async {
    _active = false;
    await storage.delete(_key);
  }

  @visibleForTesting
  static void resetForTesting() => _active = false;
}
