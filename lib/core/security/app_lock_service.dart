enum AppLockStatus { notConfigured, unlocked, locked, lockedOut }

class InMemoryAppLockService {
  String? _pin;
  var _status = AppLockStatus.notConfigured;

  Future<void> configurePin(String pin) async {
    if (pin.length < 4) {
      throw ArgumentError('PIN must be at least 4 digits.');
    }
    _pin = pin;
    _status = AppLockStatus.unlocked;
  }

  Future<AppLockStatus> currentStatus() async => _status;

  Future<void> lock() async {
    if (_pin != null) {
      _status = AppLockStatus.locked;
    }
  }

  Future<bool> unlockWithPin(String pin) async {
    final success = _pin == pin;
    _status = success ? AppLockStatus.unlocked : AppLockStatus.locked;
    return success;
  }
}
