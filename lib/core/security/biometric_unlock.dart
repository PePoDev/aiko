import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:local_auth/local_auth.dart';

/// Fingerprint or face unlock through the platform (Android, iOS); never on
/// the web.
class BiometricUnlock {
  const BiometricUnlock();

  /// Whether this device has a fingerprint or face enrolled.
  Future<bool> get isAvailable async {
    if (kIsWeb) return false;
    try {
      final auth = LocalAuthentication();
      return await auth.canCheckBiometrics &&
          (await auth.getAvailableBiometrics()).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Shows the platform prompt with [reason]; true when it confirmed the
  /// user. Cancelling, failing or any platform error is false, so the PIN
  /// is always the way back in.
  Future<bool> authenticate(String reason) async {
    if (kIsWeb) return false;
    try {
      return await LocalAuthentication().authenticate(
        localizedReason: reason,
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      return false;
    }
  }
}
