import 'app_lock_service.dart';
import '../storage/secure_storage_service.dart';

class PersistentSecureAppLockService implements AppLockService {
  PersistentSecureAppLockService({required SecureStorageService storage})
      : _storage = storage;

  final SecureStorageService _storage;
  static const _pinKey = 'aiko_secure_pin';
  static const _statusKey = 'aiko_lock_status';

  @override
  Future<AppLockStatus> currentStatus() async {
    final pin = await _storage.read(_pinKey);
    if (pin == null || pin.isEmpty) {
      return AppLockStatus.notConfigured;
    }
    final statusStr = await _storage.read(_statusKey);
    return AppLockStatus.values.firstWhere(
      (e) => e.name == statusStr,
      orElse: () => AppLockStatus.locked,
    );
  }

  @override
  Future<void> configurePin(String pin) async {
    if (pin.length < 4) {
      throw ArgumentError('PIN must be at least 4 digits.');
    }
    await _storage.write(_pinKey, pin);
    await _storage.write(_statusKey, AppLockStatus.unlocked.name);
  }

  @override
  Future<bool> unlockWithPin(String pin) async {
    final savedPin = await _storage.read(_pinKey);
    final success = savedPin == pin;
    if (success) {
      await _storage.write(_statusKey, AppLockStatus.unlocked.name);
    }
    return success;
  }

  @override
  Future<void> lock() async {
    final pin = await _storage.read(_pinKey);
    if (pin != null && pin.isNotEmpty) {
      await _storage.write(_statusKey, AppLockStatus.locked.name);
    }
  }

  Future<void> disablePin() async {
    await _storage.delete(_pinKey);
    await _storage.delete(_statusKey);
  }
}
