import '../domain/device_session.dart';

class DeviceSessionService {
  const DeviceSessionService();

  DeviceSession trust(DeviceSession session) => DeviceSession(
    deviceId: session.deviceId,
    deviceName: session.deviceName,
    status: DeviceTrustStatus.trusted,
  );

  DeviceSession revoke(DeviceSession session) => DeviceSession(
    deviceId: session.deviceId,
    deviceName: session.deviceName,
    status: DeviceTrustStatus.revoked,
  );
}
