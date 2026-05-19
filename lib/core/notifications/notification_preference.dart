import 'notification_schedule.dart';

class NotificationPreference {
  const NotificationPreference({
    required this.type,
    required this.permissionState,
    this.enabled = true,
  });

  final String type;
  final NotificationPermissionState permissionState;
  final bool enabled;

  bool get canNotify =>
      enabled && permissionState == NotificationPermissionState.granted;
}
