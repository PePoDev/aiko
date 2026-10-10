import '../../../core/storage/secure_storage_service.dart';
import '../../categories/domain/category_defaults.dart';

/// Remembers, per device and user, that the profile and default categories
/// were ensured in Firestore. That check reads every default document (about
/// 95 billed reads), and the documents can't be deleted by clients, so it only
/// needs to run once per user on each device, plus again when new defaults
/// ship (the stamp includes the template counts).
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
