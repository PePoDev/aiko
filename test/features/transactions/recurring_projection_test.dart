import 'package:aiko/core/money/money.dart';
import 'package:aiko/features/transactions/application/recurring_projection.dart';
import 'package:aiko/features/transactions/domain/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

FinanceTransaction _template({
  required DateTime date,
  required RecurringFrequency frequency,
  RecurringSettings settings = RecurringSettings.empty,
}) {
  return FinanceTransaction(
    id: 'tmpl',
    userId: 'u1',
    accountId: 'a1',
    type: TransactionType.expense,
    amount: Money.parse('10', 'USD'),
    date: date,
    isRecurring: true,
    recurringFrequency: frequency,
    recurringSettings: settings,
  );
}

void main() {
  const projection = RecurringProjection();

  test('daily series fills the rest of the month after the anchor', () {
    final t = _template(
      date: DateTime(2026, 6, 28),
      frequency: RecurringFrequency.daily,
    );
    final ghosts = projection.occurrencesInMonth(t, 2026, 6);
    // 29th and 30th only (June has 30 days), anchor itself excluded.
    expect(ghosts.map((g) => g.date.day), [29, 30]);
    expect(ghosts.every(RecurringProjection.isPreview), isTrue);
    expect(RecurringProjection.sourceId(ghosts.first), 'tmpl');
  });

  test('monthly series clamps Jan 31 anchor to Feb 28', () {
    final t = _template(
      date: DateTime(2026, 1, 31),
      frequency: RecurringFrequency.monthly,
    );
    final feb = projection.occurrencesInMonth(t, 2026, 2);
    expect(feb.single.date, DateTime(2026, 2, 28));
  });

  test('once and non-recurring produce nothing', () {
    final once = _template(
      date: DateTime(2026, 6, 1),
      frequency: RecurringFrequency.once,
    );
    expect(projection.occurrencesInMonth(once, 2026, 6), isEmpty);
  });

  test('end date stops the series', () {
    final t = _template(
      date: DateTime(2026, 6, 1),
      frequency: RecurringFrequency.daily,
      settings: RecurringSettings(endDate: DateTime(2026, 6, 3)),
    );
    final ghosts = projection.occurrencesInMonth(t, 2026, 6);
    expect(ghosts.map((g) => g.date.day), [2, 3]);
  });

  test('maxOccurrences caps the series (anchor counts as #1)', () {
    final t = _template(
      date: DateTime(2026, 6, 1),
      frequency: RecurringFrequency.daily,
      settings: const RecurringSettings(maxOccurrences: 3),
    );
    final ghosts = projection.occurrencesInMonth(t, 2026, 6);
    // #1 anchor + #2, #3 previews.
    expect(ghosts.map((g) => g.date.day), [2, 3]);
  });

  group('anchored occurrences', () {
    List<DateTime> datesIn(FinanceTransaction t, int year, int month) =>
        projection
            .occurrencesInMonth(t, year, month)
            .map((g) => g.date)
            .toList();

    test('monthly Jan 31 does not drift: Feb 28, Mar 31, Apr 30', () {
      final t = _template(
        date: DateTime(2026, 1, 31, 9, 30),
        frequency: RecurringFrequency.monthly,
      );
      expect(datesIn(t, 2026, 2), [DateTime(2026, 2, 28, 9, 30)]);
      expect(datesIn(t, 2026, 3), [DateTime(2026, 3, 31, 9, 30)]);
      expect(datesIn(t, 2026, 4), [DateTime(2026, 4, 30, 9, 30)]);
    });

    test('monthly honours dayOfMonth from the settings', () {
      final t = _template(
        date: DateTime(2026, 1, 5),
        frequency: RecurringFrequency.monthly,
        settings: const RecurringSettings(dayOfMonth: 20),
      );
      // The 20th is still ahead in the anchor's month, so it counts.
      expect(datesIn(t, 2026, 1), [DateTime(2026, 1, 20)]);
      expect(datesIn(t, 2026, 2), [DateTime(2026, 2, 20)]);
    });

    test('monthly dayOfMonth before the anchor day starts next month', () {
      final t = _template(
        date: DateTime(2026, 1, 20),
        frequency: RecurringFrequency.monthly,
        settings: const RecurringSettings(dayOfMonth: 5),
      );
      expect(datesIn(t, 2026, 1), isEmpty);
      expect(datesIn(t, 2026, 2), [DateTime(2026, 2, 5)]);
    });

    test('monthly crosses the year boundary', () {
      final t = _template(
        date: DateTime(2026, 11, 30),
        frequency: RecurringFrequency.monthly,
      );
      expect(datesIn(t, 2027, 2), [DateTime(2027, 2, 28)]);
    });

    test('weekly honours dayOfWeek from the settings', () {
      // 2026-06-01 is a Monday; the series runs on Fridays (5).
      final t = _template(
        date: DateTime(2026, 6, 1),
        frequency: RecurringFrequency.weekly,
        settings: const RecurringSettings(dayOfWeek: 5),
      );
      expect(datesIn(t, 2026, 6).map((d) => d.day), [5, 12, 19, 26]);
      expect(datesIn(t, 2026, 6).every((d) => d.weekday == 5), isTrue);
    });

    test('weekly without a dayOfWeek repeats the anchor weekday', () {
      final t = _template(
        date: DateTime(2026, 6, 1),
        frequency: RecurringFrequency.weekly,
      );
      expect(datesIn(t, 2026, 6).map((d) => d.day), [8, 15, 22, 29]);
    });

    test('annual honours monthOfYear and dayOfMonth', () {
      final t = _template(
        date: DateTime(2026, 1, 10),
        frequency: RecurringFrequency.annually,
        settings: const RecurringSettings(monthOfYear: 3, dayOfMonth: 15),
      );
      expect(datesIn(t, 2026, 3), [DateTime(2026, 3, 15)]);
      expect(datesIn(t, 2027, 3), [DateTime(2027, 3, 15)]);
    });

    test('annual leap-day anchor clamps then returns to Feb 29', () {
      final t = _template(
        date: DateTime(2024, 2, 29),
        frequency: RecurringFrequency.annually,
      );
      expect(datesIn(t, 2025, 2), [DateTime(2025, 2, 28)]);
      expect(datesIn(t, 2028, 2), [DateTime(2028, 2, 29)]);
    });

    test('maxOccurrences counts from the anchor for monthly series', () {
      final t = _template(
        date: DateTime(2026, 1, 15),
        frequency: RecurringFrequency.monthly,
        settings: const RecurringSettings(maxOccurrences: 3),
      );
      // #1 Jan (anchor), #2 Feb, #3 Mar, then stop.
      expect(datesIn(t, 2026, 3), [DateTime(2026, 3, 15)]);
      expect(datesIn(t, 2026, 4), isEmpty);
    });
  });
}
