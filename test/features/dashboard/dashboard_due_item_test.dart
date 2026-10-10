import 'package:aiko/core/money/money.dart';
import 'package:aiko/features/accounts/domain/account.dart';
import 'package:aiko/features/accounts/domain/account_details.dart';
import 'package:aiko/features/dashboard/domain/dashboard_due_item.dart';
import 'package:aiko/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final english = lookupAppLocalizations(const Locale('en'));
  Money thb(String v) => Money.parse(v, 'THB');

  Account card({
    required String balance,
    int dueDay = 23,
    Money? minimumPayment,
    bool isActive = true,
  }) => Account(
    id: 'cc',
    userId: 'u',
    name: 'Visa',
    type: AccountType.creditCard,
    currentBalance: thb(balance),
    isActive: isActive,
    details: CreditCardDetails(
      statementDay: 5,
      dueDay: dueDay,
      minimumPayment: minimumPayment,
    ),
  );

  List<DashboardDueItem> build(List<Account> accounts, DateTime asOf) =>
      buildDashboardDueItems(accounts: accounts, asOf: asOf, l10n: english);

  group('amount due', () {
    test('a used card (negative balance) owes its balance', () {
      final items = build([card(balance: '-1500')], DateTime(2026, 6, 20));
      expect(items.single.amount, thb('1500'));
    });

    test('the minimum payment wins when set, capped at the balance owed', () {
      expect(
        build([
          card(balance: '-1500', minimumPayment: thb('300')),
        ], DateTime(2026, 6, 20)).single.amount,
        thb('300'),
      );
      expect(
        build([
          card(balance: '-100', minimumPayment: thb('300')),
        ], DateTime(2026, 6, 20)).single.amount,
        thb('100'),
      );
    });

    test('a card with nothing owed and no minimum payment has no bill', () {
      expect(build([card(balance: '0')], DateTime(2026, 6, 20)), isEmpty);
      expect(build([card(balance: '250')], DateTime(2026, 6, 20)), isEmpty);
    });

    test('inactive cards are skipped', () {
      expect(
        build([card(balance: '-500', isActive: false)], DateTime(2026, 6, 20)),
        isEmpty,
      );
    });
  });

  group('due dates', () {
    test('a bill due today stays this month, whatever the time', () {
      final items = build([
        card(balance: '-500', dueDay: 20),
      ], DateTime(2026, 6, 20, 18, 30));
      expect(items.single.dueDate, DateTime(2026, 6, 20));
      expect(items.single.daysUntil(DateTime(2026, 6, 20, 18, 30)), 0);
    });

    test('a due day already past rolls to next month, clamped', () {
      final items = build([
        card(balance: '-500', dueDay: 31),
      ], DateTime(2026, 2, 28, 9));
      // February 2026 has 28 days, so day 31 falls on the 28th: today.
      expect(items.single.dueDate, DateTime(2026, 2, 28));

      final later = build([
        card(balance: '-500', dueDay: 5),
      ], DateTime(2026, 1, 31, 9));
      expect(later.single.dueDate, DateTime(2026, 2, 5));
    });
  });

  group('daysUntil counts calendar days', () {
    final item = DashboardDueItem(
      id: 'cc',
      title: 'Visa payment',
      amount: thb('100'),
      dueDate: DateTime(2026, 6, 21),
    );

    test('tomorrow is 1 even late in the evening', () {
      expect(item.daysUntil(DateTime(2026, 6, 20, 23, 59)), 1);
      expect(item.daysUntil(DateTime(2026, 6, 20, 0, 1)), 1);
    });

    test('today is 0 and yesterday is negative', () {
      expect(item.daysUntil(DateTime(2026, 6, 21, 12)), 0);
      expect(item.daysUntil(DateTime(2026, 6, 22, 8)), -1);
    });

    test('calendarDaysBetween ignores the time of day', () {
      expect(
        calendarDaysBetween(DateTime(2026, 3, 1, 23), DateTime(2026, 3, 8, 1)),
        7,
      );
    });
  });
}
