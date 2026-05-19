import 'package:aiko/core/notifications/notification_schedule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'only schedules notifications when enabled and permission is granted',
    () {
      const schedule = NotificationSchedule(
        type: 'billDue',
        timing: NotificationTiming.threeDaysBefore,
        permissionState: NotificationPermissionState.granted,
      );

      expect(schedule.canSchedule, isTrue);
      expect(schedule.leadTime, const Duration(days: 3));
    },
  );

  test('blocks scheduling when permission is denied', () {
    const schedule = NotificationSchedule(
      type: 'budgetThreshold',
      timing: NotificationTiming.sameDay,
      permissionState: NotificationPermissionState.denied,
    );

    expect(schedule.canSchedule, isFalse);
  });
}
