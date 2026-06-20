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
}
