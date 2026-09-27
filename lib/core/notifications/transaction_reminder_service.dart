import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// How a reminder should repeat. Maps a recurring cadence onto the plugin's
/// native [DateTimeComponents] matching, so one scheduled notification recurs
/// forever instead of us booking one slot per occurrence.
enum ReminderRepeat { none, daily, weekly, monthly, yearly }

/// Schedules local notifications reminding the user about a transaction at a
/// configured time. Best-effort: any platform/permission failure is swallowed
/// so saving a transaction never fails because of a reminder.
class TransactionReminderService {
  TransactionReminderService._();

  static final TransactionReminderService instance =
      TransactionReminderService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'transaction_reminders';
  static const String _channelName = 'Transaction reminders';

  bool _ready = false;

  Future<void> init() async {
    if (kIsWeb || _ready) return;
    try {
      tz_data.initializeTimeZones();
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (error) {
      // Leaves tz.local as UTC — reminders may fire at the wrong wall-clock
      // time, but the app keeps working.
      debugPrint('[reminders] timezone init failed: $error');
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    try {
      await _plugin.initialize(
        const InitializationSettings(
          android: android,
          iOS: darwin,
          macOS: darwin,
        ),
      );
      _ready = true;
    } catch (error) {
      debugPrint('[reminders] plugin init failed: $error');
    }
  }

  Future<void> _requestPermission() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  /// Stable non-negative 31-bit id derived from the transaction id, so
  /// re-saving a transaction reschedules the same notification slot.
  int _notificationId(String transactionId) =>
      transactionId.hashCode & 0x7fffffff;

  /// (Re)schedules the reminder for [transactionId].
  ///
  /// With [repeat] == none, a past [when] only cancels any existing reminder.
  /// With a repeat set, the plugin matches the relevant date/time components
  /// and rolls forward to the next occurrence even if [when] is already past.
  ///
  // ponytail: native repeat fires forever — it ignores the recurring series'
  // end date / max occurrences. Good enough (the user can clear the reminder);
  // gate on those bounds here if a hard stop is ever needed.
  Future<void> schedule({
    required String transactionId,
    required String title,
    required String body,
    required DateTime when,
    ReminderRepeat repeat = ReminderRepeat.none,
  }) async {
    await init();
    if (!_ready) return;
    await cancel(transactionId);
    final components = _componentsFor(repeat);
    if (components == null && !when.isAfter(DateTime.now())) return;

    try {
      await _requestPermission();
      await _plugin.zonedSchedule(
        _notificationId(transactionId),
        title,
        body,
        tz.TZDateTime.from(when, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: 'Reminders for upcoming transactions',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: components,
      );
    } catch (error) {
      debugPrint('[reminders] schedule failed: $error');
    }
  }

  DateTimeComponents? _componentsFor(ReminderRepeat repeat) {
    return switch (repeat) {
      ReminderRepeat.none => null,
      ReminderRepeat.daily => DateTimeComponents.time,
      ReminderRepeat.weekly => DateTimeComponents.dayOfWeekAndTime,
      ReminderRepeat.monthly => DateTimeComponents.dayOfMonthAndTime,
      ReminderRepeat.yearly => DateTimeComponents.dateAndTime,
    };
  }

  Future<void> cancel(String transactionId) async {
    await init();
    if (!_ready) return;
    try {
      await _plugin.cancel(_notificationId(transactionId));
    } catch (error) {
      debugPrint('[reminders] cancel failed: $error');
    }
  }
}
