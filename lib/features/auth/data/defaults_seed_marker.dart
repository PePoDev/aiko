import '../../../core/storage/secure_storage_service.dart';
import '../../categories/domain/category_defaults.dart';

/// Remembers, per device and user, that the profile and default categories
/// were ensured in Firestore. That check looks up every default document (in
/// the device cache first; on a device that hasn't cached them yet, about 95
/// billed server reads), and the documents can't be deleted by clients, so it
/// only needs to run once per user on each device, plus again when new
/// defaults ship (the stamp includes the template counts). It is set only
/// once every default is known to exist (`DefaultsSeeder`).
class DefaultsSeedMarker {
  const DefaultsSeedMarker(this._storage);

  final SecureStorageService _storage;

  /// Bump to force every device to re-check its defaults once.
  static const version = 1;

  static String _key(String uid) => 'aiko_defaults_seeded:$uid';

  static String get stamp =>
      '$version:${CategoryGroupDefaults.all.length}:${CategoryDefaults.all.length}';

  Future<bool> isSeeded(String uid) async =>
      await _storage.read(_key(uid)) == stamp;

  Future<void> markSeeded(String uid) => _storage.write(_key(uid), stamp);
}
