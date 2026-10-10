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
  /// Each occurrence is computed from the anchor (never from the previous
  /// occurrence), so a month-end day doesn't drift: Jan 31 → Feb 28 → Mar 31.
  /// `dayOfWeek` / `dayOfMonth` / `monthOfYear` from the settings pick the
  /// cadence day when set; otherwise the anchor's own day is used.
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
    // The anchor itself is occurrence #1; previews start at #2.
    for (var n = 1; n <= maxSteps; n++) {
      final occurrence = n + 1;
      if (settings.maxOccurrences != null &&
          occurrence > settings.maxOccurrences!) {
        break;
      }
      final date = nthOccurrenceAfterAnchor(
        template.date,
        frequency,
        settings,
        n,
      );
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

  /// The [n]th occurrence (n ≥ 1) after [anchor] for [frequency], at the
  /// anchor's time of day. The first one is the earliest cadence day strictly
  /// after the anchor; later ones step whole days/weeks/months/years from it.
  /// Days past a month's end clamp to its last day (31 → Feb 28/29).
  static DateTime nthOccurrenceAfterAnchor(
    DateTime anchor,
    RecurringFrequency frequency,
    RecurringSettings settings,
    int n,
  ) {
    DateTime at(int y, int m, int d) =>
        DateTime(y, m, d, anchor.hour, anchor.minute);

    switch (frequency) {
      case RecurringFrequency.once:
        return anchor;
      case RecurringFrequency.daily:
        return at(anchor.year, anchor.month, anchor.day + n);
      case RecurringFrequency.weekly:
        final weekday = settings.dayOfWeek ?? anchor.weekday;
        var offset = (weekday - anchor.weekday) % 7;
        if (offset == 0) offset = 7;
        return at(anchor.year, anchor.month, anchor.day + offset + 7 * (n - 1));
      case RecurringFrequency.monthly:
        final day = settings.dayOfMonth ?? anchor.day;
        // Same month counts when its cadence day is still ahead of the anchor.
        final startsThisMonth =
            _clampedDay(anchor.year, anchor.month, day) > anchor.day;
        final targetMonth = anchor.month + n - (startsThisMonth ? 1 : 0);
        return at(
          anchor.year,
          targetMonth,
          _clampedDay(anchor.year, targetMonth, day),
        );
      case RecurringFrequency.annually:
        final monthOfYear = settings.monthOfYear ?? anchor.month;
        final day = settings.dayOfMonth ?? anchor.day;
        final thisYear = at(
          anchor.year,
          monthOfYear,
          _clampedDay(anchor.year, monthOfYear, day),
        );
        final targetYear = anchor.year + n - (thisYear.isAfter(anchor) ? 1 : 0);
        return at(
          targetYear,
          monthOfYear,
          _clampedDay(targetYear, monthOfYear, day),
        );
    }
  }

  /// [day] limited to the length of [month] in [year] (month may overflow 12;
  /// DateTime normalises it).
  static int _clampedDay(int year, int month, int day) {
    final lastDay = DateTime(year, month + 1, 0).day;
    return day > lastDay ? lastDay : day;
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
