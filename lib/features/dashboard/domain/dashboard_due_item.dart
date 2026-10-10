import '../../../core/money/money.dart';
import '../../../l10n/app_localizations.dart';
import '../../accounts/domain/account.dart';
import '../../accounts/domain/account_details.dart';

class DashboardDueItem {
  const DashboardDueItem({
    required this.id,
    required this.title,
    required this.amount,
    required this.dueDate,
  });

  /// The credit-card account the bill belongs to.
  final String id;
  final String title;
  final Money amount;
  final DateTime dueDate;

  /// Calendar days from [asOf]'s date to [dueDate]'s date: 0 when it's due
  /// today and 1 tomorrow, whatever the time of day.
  int daysUntil(DateTime asOf) => calendarDaysBetween(asOf, dueDate);
}

/// Whole calendar days from [from]'s date to [to]'s date, ignoring the time of
/// day (UTC dates, so a daylight-saving change can't shave off a day).
int calendarDaysBetween(DateTime from, DateTime to) => DateTime.utc(
  to.year,
  to.month,
  to.day,
).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

/// What's owed on a credit card right now: its minimum payment when one is
/// set (capped at the balance owed), else the balance owed. Card balances are
/// signed, so a used card has a negative balance; null when nothing is owed
/// and no minimum payment is set.
Money? creditCardAmountDue(Account account, CreditCardDetails details) {
  final balance = account.currentBalance;
  final owed = balance.isNegative
      ? Money(amount: -balance.amount, currency: balance.currency)
      : null;
  final minimum = details.minimumPayment;
  if (minimum != null && minimum.isPositive) {
    if (owed != null &&
        owed.currency == minimum.currency &&
        owed.compareTo(minimum) < 0) {
      return owed;
    }
    return minimum;
  }
  return owed;
}

List<DashboardDueItem> buildDashboardDueItems({
  required List<Account> accounts,
  required DateTime asOf,
  required AppLocalizations l10n,
}) {
  final today = DateTime(asOf.year, asOf.month, asOf.day);
  final cutoff = DateTime(today.year, today.month, today.day + 30);
  final items = <DashboardDueItem>[];

  for (final account in accounts) {
    if (!account.isActive || account.type != AccountType.creditCard) {
      continue;
    }
    final details = account.resolvedDetails;
    if (details is! CreditCardDetails) {
      continue;
    }

    final amount = creditCardAmountDue(account, details);
    if (amount == null || !amount.isPositive) {
      continue;
    }

    final due = _nextDateForDay(today, details.dueDay);
    if (due.isAfter(cutoff)) {
      continue;
    }

    items.add(
      DashboardDueItem(
        id: account.id,
        title: l10n.dueItemPayment(account.name),
        amount: amount,
        dueDate: due,
      ),
    );
  }

  items.sort((a, b) => a.dueDate.compareTo(b.dueDate));
  return items;
}

/// The next date (today included) falling on [requestedDay] of the month,
/// clamped to the month's length. [today] is a date without a time.
DateTime _nextDateForDay(DateTime today, int requestedDay) {
  final day = requestedDay.clamp(1, 31);
  var candidate = DateTime(
    today.year,
    today.month,
    day.clamp(1, DateTime(today.year, today.month + 1, 0).day).toInt(),
  );
  if (candidate.isBefore(today)) {
    final nextMonthLastDay = DateTime(today.year, today.month + 2, 0).day;
    candidate = DateTime(
      today.year,
      today.month + 1,
      day.clamp(1, nextMonthLastDay).toInt(),
    );
  }
  return candidate;
}
