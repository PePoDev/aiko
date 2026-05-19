import 'package:aiko/features/devices/application/device_session_service.dart';
import 'package:aiko/features/devices/domain/device_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('trusts and revokes device sessions', () {
    const session = DeviceSession(deviceId: '1', deviceName: 'Phone');
    final trusted = const DeviceSessionService().trust(session);
    final revoked = const DeviceSessionService().revoke(trusted);

    expect(trusted.canSync, isTrue);
    expect(revoked.canSync, isFalse);
  });
}
