import '../../../core/security/app_lock_service.dart';

class AppLockController {
  AppLockController(this._service);

  final AppLockService _service;

  Future<AppLockStatus> currentStatus() => _service.currentStatus();

  Future<void> enablePin(String pin) => _service.configurePin(pin);

  Future<bool> unlock(String pin) => _service.unlockWithPin(pin);

  Future<void> lock() => _service.lock();
}
