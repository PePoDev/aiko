import 'package:uuid/uuid.dart';

import '../storage/secure_storage_service.dart';
import '../firebase/firebase_backend.dart';

class OfflineUserContext {
  OfflineUserContext({SecureStorageService? storage})
    : _storage = storage ?? FlutterSecureStorageService();

  static const _knownUserIdKey = 'aiko_offline_user_id';

  /// Public prefix so callers (e.g. `OfflineDataMigrator`) don't have to
  /// redeclare their own copy. Local-only anonymous ids start with
  /// this string and are reassigned to the real Firebase user id on sign-in.
  static const localUserIdPrefix = 'local:';

  final SecureStorageService _storage;

  static Future<String> startAnonymousSession(
    SecureStorageService storage,
  ) async {
    final localUserId = '$localUserIdPrefix${const Uuid().v4()}';
    await storage.write(_knownUserIdKey, localUserId);
    return localUserId;
  }

  Future<String> resolveUserId() async {
    final remoteUserId = FirebaseBackend.userId;
    if (remoteUserId != null && remoteUserId.isNotEmpty) {
      await _storage.write(_knownUserIdKey, remoteUserId);
      return remoteUserId;
    }

    final cachedUserId = await _storage.read(_knownUserIdKey);
    if (cachedUserId != null && cachedUserId.isNotEmpty) {
      return cachedUserId;
    }

    return startAnonymousSession(_storage);
  }
}
