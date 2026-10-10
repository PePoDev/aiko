import '../../../core/storage/secure_storage_service.dart';

/// Remembers, per user on this device, that the default Cash and Bank
/// accounts were created. Local-only builds run onboarding on every launch;
/// without the marker an account the user deleted or renamed would come
/// back each time.
class DefaultAccountsSeedMarker {
  const DefaultAccountsSeedMarker(this._storage);

  final SecureStorageService _storage;

  static String _key(String uid) => 'aiko_default_accounts_seeded:$uid';

  Future<bool> isSeeded(String uid) async =>
      await _storage.read(_key(uid)) == 'true';

  Future<void> markSeeded(String uid) => _storage.write(_key(uid), 'true');
}
