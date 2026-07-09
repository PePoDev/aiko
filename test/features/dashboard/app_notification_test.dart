import 'package:aiko/core/money/money.dart';
import 'package:decimal/decimal.dart';
import 'package:aiko/features/accounts/domain/account.dart';
import 'package:aiko/features/categories/domain/category.dart';
import 'package:aiko/features/dashboard/domain/app_notification.dart';
import 'package:aiko/features/dashboard/domain/dashboard_due_item.dart';
import 'package:aiko/features/transactions/domain/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 6, 20);
  Money usd(String v) => Money(amount: Decimal.parse(v), currency: 'USD');

  test('budget alert fires when this-month spend crosses a threshold', () {
    final category = Category(
      id: 'c1',
      userId: 'u1',
      name: 'Food',
      type: CategoryType.expense,
      group: CategoryBudgetGroup.needs,
      monthlyLimit: usd('100'),
      alertThresholds: const [50, 75, 90, 100],
    );
    final spend = FinanceTransaction(
      id: 't1',
      userId: 'u1',
      accountId: 'a1',
      type: TransactionType.expense,
      amount: usd('80'),
      date: now,
      categoryId: 'c1',
    );

    final result = buildNotifications(
      transactions: [spend],
      categories: [category],
      accounts: const [],
      dueItems: const [],
      asOf: now,
    );

    expect(result, hasLength(1));
    expect(result.single.group, AppNotificationGroup.budget);
    expect(result.single.subtitle, contains('80%'));
    expect(result.single.severity, AppNotificationSeverity.warning);
  });

  test('no notifications when nothing is noteworthy', () {
    expect(
      buildNotifications(
        transactions: const [],
        categories: const [],
        accounts: const [],
        dueItems: const [],
        asOf: now,
      ),
      isEmpty,
    );
  });

  test('upcoming bill within a week and goal milestone are surfaced', () {
    final bill = DashboardDueItem(
      id: 'cc1',
      title: 'Visa payment',
      amount: usd('200'),
      dueDate: now.add(const Duration(days: 3)),
    );
    final goal = Account(
      id: 'g1',
      userId: 'u1',
      name: 'Vacation',
      type: AccountType.goal,
      currentBalance: usd('500'),
      targetAmount: usd('1000'),
    );

    final result = buildNotifications(
      transactions: const [],
      categories: const [],
      accounts: [goal],
      dueItems: [bill],
      asOf: now,
    );

    expect(result.map((n) => n.group), [
      AppNotificationGroup.bills,
      AppNotificationGroup.goals,
    ]);
    expect(result[0].subtitle, contains('in 3 days'));
    expect(result[1].subtitle, contains('50%'));
  });
}
