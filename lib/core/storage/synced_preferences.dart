import '../firebase/firebase_backend.dart';
import '../offline/offline_store.dart';
import 'secure_storage_service.dart';

/// Only explicit user preferences are shared; auth keys and OS permissions
/// always remain in device storage.
class SyncedPreferences implements SecureStorageService {
  SyncedPreferences({SecureStorageService? local})
    : _local = local ?? FlutterSecureStorageService();
  final SecureStorageService _local;
  String _localKey(String key) => '${FirebaseBackend.userId ?? 'local'}:$key';

  @override
  Future<String?> read(String key) async {
    if (FirebaseBackend.userId == null) return _local.read(key);
    final doc = await FirebaseBackend.collection('preferences').doc(key).get();
    return doc.data()?['value'] as String?;
  }

  @override
  Future<void> write(String key, String value) async {
    if (FirebaseBackend.userId == null) return _local.write(key, value);
    await _local.write(_localKey(key), value);
    await OfflineStore.acceptWrite(
      FirebaseBackend.collection('preferences').doc(key).set({'value': value}),
    );
  }

  @override
  Future<void> delete(String key) async {
    if (FirebaseBackend.userId == null) return _local.delete(key);
    await _local.delete(_localKey(key));
    await OfflineStore.acceptWrite(
      FirebaseBackend.collection('preferences').doc(key).delete(),
    );
  }

  @override
  Future<void> deleteAll() async =>
      throw UnsupportedError('Delete named preferences explicitly.');
}
