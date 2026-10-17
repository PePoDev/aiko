import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../features/transactions/domain/transaction.dart';
import '../../l10n/domain_labels.dart';
import '../../l10n/l10n.dart';
import '../formatting/money_formatter.dart';

/// How a reminder should repeat. An open-ended series maps onto the plugin's
/// native [DateTimeComponents] matching, so one scheduled notification recurs
/// forever; a series with an end date or an occurrence limit books one slot
/// per upcoming occurrence instead (see [upcomingReminderTimes]).
enum ReminderRepeat { none, daily, weekly, monthly, yearly }

/// Occurrence times of a reminder series that starts at [first], after
/// [now], in order and at most [limit] of them. The series stops after
/// [maxOccurrences] occurrences (counted from [first]) and after the day of
/// [endDate]. Monthly and yearly occurrences keep [first]'s day, clamped to
/// shorter months (31 January → 28 February).
List<DateTime> upcomingReminderTimes({
  required DateTime first,
  required ReminderRepeat repeat,
  required DateTime now,
  DateTime? endDate,
  int? maxOccurrences,
  int limit = 24,
}) {
  final stopAfter = endDate == null
      ? null
      : DateTime(endDate.year, endDate.month, endDate.day + 1);
  DateTime occurrence(int k) {
    int clampDay(int year, int month) =>
        first.day.clamp(1, DateTime(year, month + 1, 0).day);
    return switch (repeat) {
      ReminderRepeat.none => first,
      ReminderRepeat.daily => DateTime(
        first.year,
        first.month,
        first.day + k,
        first.hour,
        first.minute,
      ),
      ReminderRepeat.weekly => DateTime(
        first.year,
        first.month,
        first.day + 7 * k,
        first.hour,
        first.minute,
      ),
      ReminderRepeat.monthly => () {
        final month = DateTime(first.year, first.month + k);
        return DateTime(
          month.year,
          month.month,
          clampDay(month.year, month.month),
          first.hour,
          first.minute,
        );
      }(),
      ReminderRepeat.yearly => DateTime(
        first.year + k,
        first.month,
        clampDay(first.year + k, first.month),
        first.hour,
        first.minute,
      ),
    };
  }

  final times = <DateTime>[];
  final count = repeat == ReminderRepeat.none ? 1 : (maxOccurrences ?? 100000);
  for (var k = 0; k < count && times.length < limit; k++) {
    final time = occurrence(k);
    if (stopAfter != null && !time.isBefore(stopAfter)) break;
    if (time.isAfter(now)) times.add(time);
  }
  return times;
}

/// Notifications booked ahead for a bounded series; topped up on each launch
/// by [TransactionReminderService.resyncBounded]. iOS keeps at most 64
/// pending per app.
const int _boundedSlots = 12;

/// Stable non-negative 31-bit id derived from [key], so re-saving a
/// transaction reschedules the same notification slot.
int _reminderId(String key) => key.hashCode & 0x7fffffff;

/// Every notification id a transaction's reminder can use: its own slot, then
/// the per-occurrence slots of a bounded series.
List<int> reminderNotificationIds(String transactionId) => [
  _reminderId(transactionId),
  for (var i = 0; i < _boundedSlots; i++) _reminderId('$transactionId#$i'),
];

/// Which booked reminders ([booked] notification ids) to cancel and which
/// transactions to re-book after [removedIds] were deleted and [changed] were
/// edited elsewhere. Only transactions with a reminder in [booked] count.
({List<String> cancel, List<FinanceTransaction> reschedule})
planReminderFollowUp({
  required Set<int> booked,
  Iterable<String> removedIds = const [],
  Iterable<FinanceTransaction> changed = const [],
}) {
  bool isBooked(String id) => reminderNotificationIds(id).any(booked.contains);
  return (
    cancel: [
      for (final id in removedIds)
        if (isBooked(id)) id,
    ],
    reschedule: [
      for (final transaction in changed)
        if (isBooked(transaction.id)) transaction,
    ],
  );
}

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

  bool _resynced = false;

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

  int _notificationId(String transactionId) => _reminderId(transactionId);

  /// Ids of the per-occurrence slots of a bounded series.
  Iterable<int> _slotIds(String transactionId) =>
      reminderNotificationIds(transactionId).skip(1);

  /// The notification ids booked on this device; empty when unknown.
  Future<Set<int>> _bookedIds() async {
    try {
      final pending = await _plugin.pendingNotificationRequests();
      return {for (final request in pending) request.id};
    } catch (error) {
      debugPrint('[reminders] pending lookup failed: $error');
      return {};
    }
  }

  /// Follows transactions deleted ([removedIds]) or edited ([changed]) on
  /// another device: a reminder booked here is cancelled or re-booked to
  /// match. Transactions without a reminder booked here are left alone, so
  /// someone else's edit never prompts for notification permission.
  Future<void> followRemoteChanges({
    Iterable<String> removedIds = const [],
    Iterable<FinanceTransaction> changed = const [],
  }) async {
    if (kIsWeb) return;
    await init();
    if (!_ready) return;
    final plan = planReminderFollowUp(
      booked: await _bookedIds(),
      removedIds: removedIds,
      changed: changed,
    );
    for (final id in plan.cancel) {
      await cancel(id);
    }
    if (plan.reschedule.isEmpty) return;
    final l10n = currentL10n();
    for (final transaction in plan.reschedule) {
      await scheduleFor(transaction, l10n);
    }
  }

  /// (Re)schedules [transaction]'s reminder, or cancels it when it has none.
  /// A recurring transaction's reminder recurs with it, within the series'
  /// end date and occurrence limit; a one-off reminds once.
  Future<void> scheduleFor(
    FinanceTransaction transaction,
    AppLocalizations l10n,
  ) async {
    final when = transaction.reminderAt;
    if (when == null) {
      await cancel(transaction.id);
      return;
    }
    final label = transaction.merchant?.trim().isNotEmpty == true
        ? transaction.merchant!.trim()
        : l10n.txReminderDefaultTitle;
    final repeat = transaction.isRecurring
        ? switch (transaction.recurringFrequency) {
            RecurringFrequency.daily => ReminderRepeat.daily,
            RecurringFrequency.weekly => ReminderRepeat.weekly,
            RecurringFrequency.monthly => ReminderRepeat.monthly,
            RecurringFrequency.annually => ReminderRepeat.yearly,
            RecurringFrequency.once || null => ReminderRepeat.none,
          }
        : ReminderRepeat.none;
    await schedule(
      transactionId: transaction.id,
      title: label,
      body: l10n.txReminderBody(
        transaction.amount.format(),
        transaction.type.label(l10n),
      ),
      when: when,
      repeat: repeat,
      endDate: transaction.recurringSettings?.endDate,
      maxOccurrences: transaction.recurringSettings?.maxOccurrences,
    );
  }

  /// Books the next slots of every bounded reminder series, once per launch,
  /// so a series longer than [_boundedSlots] keeps reminding.
  Future<void> resyncBounded(List<FinanceTransaction> transactions) async {
    if (kIsWeb || _resynced) return;
    _resynced = true;
    final bounded = transactions.where((transaction) {
      final settings = transaction.recurringSettings;
      return transaction.reminderAt != null &&
          transaction.isRecurring &&
          settings != null &&
          (settings.endDate != null || settings.maxOccurrences != null);
    }).toList();
    if (bounded.isEmpty) return;
    try {
      final l10n = currentL10n();
      for (final transaction in bounded) {
        await scheduleFor(transaction, l10n);
      }
    } catch (error) {
      debugPrint('[reminders] resync failed: $error');
    }
  }

  /// (Re)schedules the reminder for [transactionId].
  ///
  /// With [repeat] == none, a past [when] only cancels any existing reminder.
  /// With a repeat and no bounds, the plugin matches the relevant date/time
  /// components and rolls forward to the next occurrence even if [when] is
  /// already past. With an [endDate] or [maxOccurrences], each upcoming
  /// occurrence within them is booked on its own.
  Future<void> schedule({
    required String transactionId,
    required String title,
    required String body,
    required DateTime when,
    ReminderRepeat repeat = ReminderRepeat.none,
    DateTime? endDate,
    int? maxOccurrences,
  }) async {
    await init();
    if (!_ready) return;
    await cancel(transactionId);

    try {
      if (repeat != ReminderRepeat.none &&
          (endDate != null || maxOccurrences != null)) {
        final times = upcomingReminderTimes(
          first: when,
          repeat: repeat,
          now: DateTime.now(),
          endDate: endDate,
          maxOccurrences: maxOccurrences,
          limit: _boundedSlots,
        );
        if (times.isEmpty) return;
        await _requestPermission();
        final ids = _slotIds(transactionId).toList();
        for (var i = 0; i < times.length; i++) {
          await _zonedSchedule(ids[i], title, body, times[i], null);
        }
        return;
      }

      final components = _componentsFor(repeat);
      if (components == null && !when.isAfter(DateTime.now())) return;
      await _requestPermission();
      await _zonedSchedule(
        _notificationId(transactionId),
        title,
        body,
        when,
        components,
      );
    } catch (error) {
      debugPrint('[reminders] schedule failed: $error');
    }
  }

  Future<void> _zonedSchedule(
    int id,
    String title,
    String body,
    DateTime when,
    DateTimeComponents? components,
  ) {
    final l10n = currentL10n();
    return _plugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(when, tz.local),
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          l10n.reminderChannelName,
          channelDescription: l10n.reminderChannelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: components,
    );
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

  /// Cancels every reminder on this device, for example when the user signs
  /// out, so the next user doesn't get them.
  Future<void> cancelAll() async {
    await init();
    if (!_ready) return;
    _resynced = false;
    try {
      await _plugin.cancelAll();
    } catch (error) {
      debugPrint('[reminders] cancelAll failed: $error');
    }
  }

  Future<void> cancel(String transactionId) async {
    await init();
    if (!_ready) return;
    try {
      await _plugin.cancel(_notificationId(transactionId));
      for (final id in _slotIds(transactionId)) {
        await _plugin.cancel(id);
      }
    } catch (error) {
      debugPrint('[reminders] cancel failed: $error');
    }
  }
}
