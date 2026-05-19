enum DeviceTrustStatus { trusted, untrusted, revoked }

class DeviceSession {
  const DeviceSession({
    required this.deviceId,
    required this.deviceName,
    this.status = DeviceTrustStatus.untrusted,
  });

  final String deviceId;
  final String deviceName;
  final DeviceTrustStatus status;

  bool get canSync => status == DeviceTrustStatus.trusted;
}
