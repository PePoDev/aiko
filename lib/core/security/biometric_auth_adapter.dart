import 'package:local_auth/local_auth.dart';

abstract interface class BiometricAuthAdapter {
  Future<bool> canAuthenticate();

  Future<bool> authenticate({required String reason});
}

class LocalBiometricAuthAdapter implements BiometricAuthAdapter {
  LocalBiometricAuthAdapter({LocalAuthentication? auth})
    : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  @override
  Future<bool> authenticate({required String reason}) {
    return _auth.authenticate(localizedReason: reason);
  }

  @override
  Future<bool> canAuthenticate() async {
    return await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
  }
}

class FakeBiometricAuthAdapter implements BiometricAuthAdapter {
  FakeBiometricAuthAdapter({this.available = true, this.result = true});

  final bool available;
  final bool result;

  @override
  Future<bool> authenticate({required String reason}) async => result;

  @override
  Future<bool> canAuthenticate() async => available;
}
