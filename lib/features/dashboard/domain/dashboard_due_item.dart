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

  final String id;
  final String title;
  final Money amount;
  final DateTime dueDate;

  int daysUntil(DateTime asOf) => dueDate.difference(asOf).inDays;
}

List<DashboardDueItem> buildDashboardDueItems({
  required List<Account> accounts,
  required DateTime asOf,
  required AppLocalizations l10n,
}) {
  final cutoff = asOf.add(const Duration(days: 30));
  final items = <DashboardDueItem>[];

  for (final account in accounts) {
    if (!account.isActive || account.type != AccountType.creditCard) {
      continue;
    }
    final details = account.resolvedDetails;
    if (details is! CreditCardDetails) {
      continue;
    }

    final amount = details.minimumPayment ?? account.currentBalance;
    if (!amount.isPositive) {
      continue;
    }

    final due = _nextDateForDay(asOf, details.dueDay);
    if (due.isBefore(asOf) || due.isAfter(cutoff)) {
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

DateTime _nextDateForDay(DateTime asOf, int requestedDay) {
  final day = requestedDay.clamp(1, 31);
  var candidate = DateTime(
    asOf.year,
    asOf.month,
    day.clamp(1, DateTime(asOf.year, asOf.month + 1, 0).day).toInt(),
  );
  if (candidate.isBefore(asOf)) {
    final nextMonthLastDay = DateTime(asOf.year, asOf.month + 2, 0).day;
    candidate = DateTime(
      asOf.year,
      asOf.month + 1,
      day.clamp(1, nextMonthLastDay).toInt(),
    );
  }
  return candidate;
}
