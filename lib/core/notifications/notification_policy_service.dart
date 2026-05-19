import 'notification_schedule.dart';

class NotificationPolicyService {
  const NotificationPolicyService();

  bool shouldSchedule(NotificationSchedule schedule) => schedule.canSchedule;

  DateTime scheduledAt(DateTime dueAt, NotificationSchedule schedule) {
    return dueAt.subtract(schedule.leadTime);
  }
}
