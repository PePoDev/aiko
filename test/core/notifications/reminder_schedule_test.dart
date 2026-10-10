import 'package:aiko/core/notifications/transaction_reminder_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 10, 12);

  test('a one-off reminder is booked only when it is still ahead', () {
    expect(
      upcomingReminderTimes(
        first: DateTime(2026, 10, 11, 9),
        repeat: ReminderRepeat.none,
        now: now,
      ),
      [DateTime(2026, 10, 11, 9)],
    );
    expect(
      upcomingReminderTimes(
        first: DateTime(2026, 10, 9, 9),
        repeat: ReminderRepeat.none,
        now: now,
      ),
      isEmpty,
    );
  });

  test('stops after the end date, including that whole day', () {
    final times = upcomingReminderTimes(
      first: DateTime(2026, 10, 8, 9),
      repeat: ReminderRepeat.daily,
      now: now,
      endDate: DateTime(2026, 10, 13),
    );
    expect(times, [
      DateTime(2026, 10, 11, 9),
      DateTime(2026, 10, 12, 9),
      DateTime(2026, 10, 13, 9),
    ]);
  });

  test('counts occurrences from the first one, past ones included', () {
    final times = upcomingReminderTimes(
      first: DateTime(2026, 9, 26, 9),
      repeat: ReminderRepeat.weekly,
      now: now,
      maxOccurrences: 4,
    );
    // 26 Sep and 3 Oct have passed; 10 Oct 09:00 is before now.
    expect(times, [DateTime(2026, 10, 17, 9)]);
  });

  test('monthly keeps the day, clamped to shorter months', () {
    final times = upcomingReminderTimes(
      first: DateTime(2027, 1, 31, 8),
      repeat: ReminderRepeat.monthly,
      now: now,
      maxOccurrences: 3,
    );
    expect(times, [
      DateTime(2027, 1, 31, 8),
      DateTime(2027, 2, 28, 8),
      DateTime(2027, 3, 31, 8),
    ]);
  });

  test('yearly on 29 February falls on 28 February otherwise', () {
    final times = upcomingReminderTimes(
      first: DateTime(2028, 2, 29, 8),
      repeat: ReminderRepeat.yearly,
      now: now,
      maxOccurrences: 2,
    );
    expect(times, [DateTime(2028, 2, 29, 8), DateTime(2029, 2, 28, 8)]);
  });

  test('books at most the limit', () {
    expect(
      upcomingReminderTimes(
        first: DateTime(2026, 10, 11),
        repeat: ReminderRepeat.daily,
        now: now,
        endDate: DateTime(2027, 12, 31),
        limit: 12,
      ),
      hasLength(12),
    );
  });
}
