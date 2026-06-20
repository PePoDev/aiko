import '../domain/transaction.dart';

/// Generates display-only future occurrences of a recurring transaction.
///
/// These "preview" rows are never persisted — they let the list show what a
/// recurring series will add on upcoming dates. Each preview is a copy of the
/// source template re-dated to a future occurrence, with a synthetic id of the
/// form `<sourceId>#preview#<iso-date>`.
class RecurringProjection {
  const RecurringProjection();

  static const String _marker = '#preview#';

  /// True when [transaction] is one of our synthetic preview rows.
  static bool isPreview(FinanceTransaction transaction) =>
      transaction.id.contains(_marker);

  /// The source template id a preview row was generated from.
  static String sourceId(FinanceTransaction preview) =>
      preview.id.split(_marker).first;

  /// Occurrences of [template] that fall inside the calendar month
  /// (`year`/`month`), strictly after the template's own anchor date and
  /// before the series ends (end date / max occurrences).
  ///
  /// `maxSteps` is a safety valve so an open-ended daily series can't loop
  /// forever while we scan toward the window.
  // ponytail: O(steps) walk from the anchor — fine for one-per-day worst case
  // within a month. Jump-to-window math if a series ever needs decades of skip.
  List<FinanceTransaction> occurrencesInMonth(
    FinanceTransaction template,
    int year,
    int month, {
    int maxSteps = 4000,
  }) {
    final frequency = template.recurringFrequency;
    if (!template.isRecurring ||
        frequency == null ||
        frequency == RecurringFrequency.once) {
      return const [];
    }

    final settings = template.recurringSettings ?? RecurringSettings.empty;
    final windowStart = DateTime(year, month);
    final windowEnd = DateTime(year, month + 1, 0, 23, 59, 59);

    final result = <FinanceTransaction>[];
    var date = template.date;
    var occurrence = 1; // the anchor itself is occurrence #1
    for (var step = 0; step < maxSteps; step++) {
      date = _advance(date, frequency);
      occurrence++;
      if (settings.maxOccurrences != null &&
          occurrence > settings.maxOccurrences!) {
        break;
      }
      if (settings.endDate != null && date.isAfter(settings.endDate!)) {
        break;
      }
      if (date.isAfter(windowEnd)) {
        break;
      }
      if (date.isBefore(windowStart)) {
        continue;
      }
      result.add(_preview(template, date));
    }
    return result;
  }

  DateTime _advance(DateTime from, RecurringFrequency frequency) {
    switch (frequency) {
      case RecurringFrequency.daily:
        return from.add(const Duration(days: 1));
      case RecurringFrequency.weekly:
        return from.add(const Duration(days: 7));
      case RecurringFrequency.monthly:
        return _clampDay(from.year, from.month + 1, from.day, from);
      case RecurringFrequency.annually:
        return _clampDay(from.year + 1, from.month, from.day, from);
      case RecurringFrequency.once:
        return from;
    }
  }

  /// Same day-of-month/time as [anchor] in the target month, clamped to that
  /// month's last day (so Jan 31 → Feb 28/29, not Mar 3).
  DateTime _clampDay(int year, int month, int day, DateTime anchor) {
    final lastDay = DateTime(year, month + 1, 0).day;
    return DateTime(
      year,
      month,
      day > lastDay ? lastDay : day,
      anchor.hour,
      anchor.minute,
    );
  }

  FinanceTransaction _preview(FinanceTransaction template, DateTime date) {
    return FinanceTransaction(
      id: '${template.id}$_marker${date.toIso8601String()}',
      userId: template.userId,
      accountId: template.accountId,
      type: template.type,
      amount: template.amount,
      date: date,
      categoryId: template.categoryId,
      merchant: template.merchant,
      note: template.note,
      tags: template.tags,
      splits: template.splits,
      status: template.status,
      isRecurring: template.isRecurring,
      recurringFrequency: template.recurringFrequency,
      recurringSettings: template.recurringSettings,
    );
  }
}
