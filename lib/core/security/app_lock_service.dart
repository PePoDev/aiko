enum AppLockStatus { notConfigured, unlocked, locked, lockedOut }

abstract interface class AppLockService {
  Future<AppLockStatus> currentStatus();

  Future<void> configurePin(String pin);

  Future<bool> unlockWithPin(String pin);

  Future<void> lock();
}

class InMemoryAppLockService implements AppLockService {
  String? _pin;
  var _status = AppLockStatus.notConfigured;

  @override
  Future<void> configurePin(String pin) async {
    if (pin.length < 4) {
      throw ArgumentError('PIN must be at least 4 digits.');
    }
    _pin = pin;
    _status = AppLockStatus.unlocked;
  }

  @override
  Future<AppLockStatus> currentStatus() async => _status;

  @override
  Future<void> lock() async {
    if (_pin != null) {
      _status = AppLockStatus.locked;
    }
  }

  @override
  Future<bool> unlockWithPin(String pin) async {
    final success = _pin == pin;
    _status = success ? AppLockStatus.unlocked : AppLockStatus.locked;
    return success;
  }
}
