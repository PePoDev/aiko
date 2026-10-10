import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../storage/secure_storage_service.dart';
import '../firebase/firebase_backend.dart';

class OfflineUserContext {
  /// [signedInUserId] defaults to the Firebase user; tests replace it.
  OfflineUserContext({
    SecureStorageService? storage,
    String? Function()? signedInUserId,
  }) : _storage = storage ?? FlutterSecureStorageService(),
       _signedInUserId = signedInUserId ?? (() => FirebaseBackend.userId);

  static const _knownUserIdKey = 'aiko_offline_user_id';

  /// Public prefix so callers (e.g. `OfflineDataMigrator`) don't have to
  /// redeclare their own copy. Local-only anonymous ids start with
  /// this string and are reassigned to the real Firebase user id on sign-in.
  static const localUserIdPrefix = 'local:';

  /// The id last written under [_knownUserIdKey] by this process. Every
  /// repository call resolves the user id; while signed in that would rewrite
  /// secure storage (a keychain / keystore round trip) each time.
  static String? _persistedUserId;

  @visibleForTesting
  static void resetPersistedUserIdCache() => _persistedUserId = null;

  final SecureStorageService _storage;
  final String? Function() _signedInUserId;

  static Future<String> startAnonymousSession(
    SecureStorageService storage,
  ) async {
    final localUserId = '$localUserIdPrefix${const Uuid().v4()}';
    _persistedUserId = null;
    await storage.write(_knownUserIdKey, localUserId);
    _persistedUserId = localUserId;
    return localUserId;
  }

  Future<String> resolveUserId() async {
    final remoteUserId = _signedInUserId();
    if (remoteUserId != null && remoteUserId.isNotEmpty) {
      if (_persistedUserId != remoteUserId) {
        // Claimed before the write so concurrent calls write once.
        _persistedUserId = remoteUserId;
        try {
          await _storage.write(_knownUserIdKey, remoteUserId);
        } catch (_) {
          _persistedUserId = null;
          rethrow;
        }
      }
      return remoteUserId;
    }

    final cachedUserId = await _storage.read(_knownUserIdKey);
    if (cachedUserId != null && cachedUserId.isNotEmpty) {
      return cachedUserId;
    }

    return startAnonymousSession(_storage);
  }
}
