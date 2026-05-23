import 'package:uuid/uuid.dart';

import '../storage/secure_storage_service.dart';
import '../supabase/supabase_client_provider.dart';

class OfflineUserContext {
  OfflineUserContext({SecureStorageService? storage})
    : _storage = storage ?? FlutterSecureStorageService();

  static const _knownUserIdKey = 'aiko_offline_user_id';
  static const _localUserIdPrefix = 'local:';

  final SecureStorageService _storage;

  Future<String> resolveUserId() async {
    final remoteUserId = AikoSupabase.tryClient()?.auth.currentUser?.id;
    if (remoteUserId != null && remoteUserId.isNotEmpty) {
      await _storage.write(_knownUserIdKey, remoteUserId);
      return remoteUserId;
    }

    final cachedUserId = await _storage.read(_knownUserIdKey);
    if (cachedUserId != null && cachedUserId.isNotEmpty) {
      return cachedUserId;
    }

    final localUserId = '$_localUserIdPrefix${const Uuid().v4()}';
    await _storage.write(_knownUserIdKey, localUserId);
    return localUserId;
  }

  Future<bool> get isLocalOnlyUser async {
    final userId = await resolveUserId();
    return userId.startsWith(_localUserIdPrefix);
  }
}
