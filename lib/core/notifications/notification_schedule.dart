enum NotificationPermissionState { unknown, granted, denied }

enum NotificationTiming {
  sameDay,
  oneDayBefore,
  threeDaysBefore,
  oneWeekBefore,
}

class NotificationSchedule {
  const NotificationSchedule({
    required this.type,
    required this.timing,
    required this.permissionState,
    this.enabled = true,
  });

  final String type;
  final NotificationTiming timing;
  final NotificationPermissionState permissionState;
  final bool enabled;

  bool get canSchedule =>
      enabled && permissionState == NotificationPermissionState.granted;

  Duration get leadTime {
    return switch (timing) {
      NotificationTiming.sameDay => Duration.zero,
      NotificationTiming.oneDayBefore => const Duration(days: 1),
      NotificationTiming.threeDaysBefore => const Duration(days: 3),
      NotificationTiming.oneWeekBefore => const Duration(days: 7),
    };
  }
}
