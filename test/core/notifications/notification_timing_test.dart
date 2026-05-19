import 'package:aiko/core/notifications/notification_policy_service.dart';
import 'package:aiko/core/notifications/notification_schedule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('notification policy schedules before source due date', () {
    const schedule = NotificationSchedule(
      type: 'billDue',
      timing: NotificationTiming.threeDaysBefore,
      permissionState: NotificationPermissionState.granted,
    );

    final scheduled = const NotificationPolicyService().scheduledAt(
      DateTime.utc(2026, 5, 22),
      schedule,
    );

    expect(scheduled, DateTime.utc(2026, 5, 19));
  });
}
