import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import '../../features/settings/domain/profile.dart' show SecurityStatus;
import '../storage/secure_storage_service.dart';

/// The result of entering a PIN ([AppLockStore.check]).
sealed class PinCheck {
  const PinCheck();
}

class PinAccepted extends PinCheck {
  const PinAccepted();
}

/// A wrong PIN; [triesLeft] more before a wait ([PinLockedOut]).
class PinRejected extends PinCheck {
  const PinRejected(this.triesLeft);
  final int triesLeft;
}

/// Too many wrong PINs: none is checked before [until].
class PinLockedOut extends PinCheck {
  const PinLockedOut(this.until);
  final DateTime until;
}

/// This device's app lock: a 4–6 digit PIN, kept as a salted SHA-256 hash in
/// secure storage, and optionally unlocking with fingerprint or face. It is
/// never synced, so each device has its own lock.
///
/// After [maxTries] wrong PINs in a row nothing is checked for 30 seconds,
/// doubling with each further run of wrong PINs (at most an hour). The count
/// survives a restart.
// ponytail: a 4-6 digit PIN has at most a million values, so the hash only
// keeps the PIN out of plain sight; secure storage and the lockout are what
// stop guessing. Use a slow KDF if the PIN ever protects data at rest.
class AppLockStore {
  AppLockStore(this._storage, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  static const _pinKey = 'aiko_app_lock_pin';
  static const _biometricKey = 'aiko_app_lock_biometric';
  static const _failuresKey = 'aiko_app_lock_failures';
  static const _lockedUntilKey = 'aiko_app_lock_until';

  static const maxTries = 5;
  static const _firstWait = Duration(seconds: 30);
  static const _longestWait = Duration(hours: 1);

  final SecureStorageService _storage;
  final DateTime Function() _clock;

  /// Whether [pin] can be a PIN: 4 to 6 digits.
  static bool isValidPin(String pin) => RegExp(r'^\d{4,6}$').hasMatch(pin);

  Future<bool> get isEnabled async => await _storage.read(_pinKey) != null;

  Future<bool> get usesBiometrics async =>
      await isEnabled && await _storage.read(_biometricKey) == 'true';

  /// The lock's state on this device.
  Future<SecurityStatus> status() async {
    if (!await isEnabled) return SecurityStatus.notConfigured;
    final until = await lockedUntil();
    if (until != null) return SecurityStatus.lockedOut;
    return await usesBiometrics
        ? SecurityStatus.biometricEnabled
        : SecurityStatus.pinEnabled;
  }

  /// Turns the lock on with [pin] (or changes it), starting with no wrong
  /// tries. Throws [ArgumentError] when [pin] isn't 4–6 digits.
  Future<void> setPin(String pin) async {
    if (!isValidPin(pin)) throw ArgumentError.value(pin, 'pin');
    final salt = base64Url.encode(
      List<int>.generate(16, (_) => Random.secure().nextInt(256)),
    );
    await _storage.write(_pinKey, '$salt:${_hash(salt, pin)}');
    await _resetTries();
  }

  Future<void> setBiometrics(bool enabled) =>
      _storage.write(_biometricKey, enabled ? 'true' : 'false');

  /// Turns the lock off on this device.
  Future<void> disable() async {
    await _storage.delete(_pinKey);
    await _storage.delete(_biometricKey);
    await _resetTries();
  }

  /// When PINs are checked again after too many wrong ones; null when they
  /// are checked now.
  Future<DateTime?> lockedUntil() async {
    final until = DateTime.tryParse(await _storage.read(_lockedUntilKey) ?? '');
    return until != null && until.isAfter(_clock()) ? until : null;
  }

  /// Checks [pin]. A correct PIN (or biometric unlock, [unlocked]) clears the
  /// wrong tries.
  Future<PinCheck> check(String pin) async {
    final until = await lockedUntil();
    if (until != null) return PinLockedOut(until);
    final stored = await _storage.read(_pinKey);
    if (stored == null) return const PinAccepted();
    final separator = stored.indexOf(':');
    final salt = stored.substring(0, separator);
    if (_hash(salt, pin) == stored.substring(separator + 1)) {
      await _resetTries();
      return const PinAccepted();
    }
    final failures =
        (int.tryParse(await _storage.read(_failuresKey) ?? '') ?? 0) + 1;
    await _storage.write(_failuresKey, '$failures');
    if (failures % maxTries != 0) {
      return PinRejected(maxTries - failures % maxTries);
    }
    final runs = failures ~/ maxTries;
    final wait = _firstWait * pow(2, runs - 1).toInt();
    final lockUntil = _clock().add(wait > _longestWait ? _longestWait : wait);
    await _storage.write(_lockedUntilKey, lockUntil.toIso8601String());
    return PinLockedOut(lockUntil);
  }

  /// Biometric unlock succeeded: wrong PIN tries start over.
  Future<void> unlocked() => _resetTries();

  Future<void> _resetTries() async {
    await _storage.delete(_failuresKey);
    await _storage.delete(_lockedUntilKey);
  }

  static String _hash(String salt, String pin) =>
      sha256.convert(utf8.encode('$salt:$pin')).toString();
}
