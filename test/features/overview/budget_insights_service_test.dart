import 'package:aiko/core/money/money.dart';
import 'package:aiko/features/categories/domain/category.dart';
import 'package:aiko/features/overview/application/budget_insights_service.dart';
import 'package:aiko/features/transactions/domain/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = BudgetInsightsService();
  final asOf = DateTime(2026, 6, 15); // mid-month: 15/30 elapsed.

  FinanceTransaction expense(String amount, DateTime date, String categoryId) =>
      FinanceTransaction(
        id: '$amount-${date.day}',
        userId: 'u',
        accountId: 'a',
        type: TransactionType.expense,
        amount: Money.parse(amount, 'USD'),
        date: date,
        categoryId: categoryId,
      );

  FinanceTransaction income(String amount, DateTime date) => FinanceTransaction(
    id: 'inc-$amount-${date.day}',
    userId: 'u',
    accountId: 'a',
    type: TransactionType.income,
    amount: Money.parse(amount, 'USD'),
    date: date,
  );

  Category budgeted(String id, String limit) => Category(
    id: id,
    userId: 'u',
    name: id,
    type: CategoryType.expense,
    group: CategoryBudgetGroup.needs,
    monthlyLimit: Money.parse(limit, 'USD'),
  );

  test('pace sums spending against limits and ranks by fraction used', () {
    final pace = service.pace(
      transactions: [
        expense('900', DateTime(2026, 6, 5), 'food'), // 90% of 1000
        expense('200', DateTime(2026, 6, 6), 'fun'), // 40% of 500
      ],
      categories: [budgeted('food', '1000'), budgeted('fun', '500')],
      asOf: asOf,
    );

    expect(pace.totalSpent, Money.parse('1100', 'USD'));
    expect(pace.totalBudget, Money.parse('1500', 'USD'));
    expect(pace.categories.first.name, 'food'); // highest fraction first
    expect(pace.categories.first.fraction, closeTo(0.9, 0.001));
    expect(pace.hasBudgets, isTrue);
  });

  test('pace flags ahead-of-pace when usage outruns the calendar', () {
    final pace = service.pace(
      transactions: [expense('800', DateTime(2026, 6, 5), 'food')],
      categories: [budgeted('food', '1000')],
      asOf: asOf,
    );
    // 80% used at 50% of the month -> ahead of pace.
    expect(pace.isAheadOfPace, isTrue);
  });

  test('safe to spend = income - spent - unspent budget', () {
    final safe = service.safeToSpend(
      transactions: [
        income('5000', DateTime(2026, 6, 1)),
        expense('300', DateTime(2026, 6, 5), 'food'),
      ],
      categories: [budgeted('food', '1000')], // 700 still reserved
      asOf: asOf,
    );

    expect(safe.income, Money.parse('5000', 'USD'));
    expect(safe.spent, Money.parse('300', 'USD'));
    expect(safe.reserved, Money.parse('700', 'USD'));
    expect(safe.leftover, Money.parse('4000', 'USD'));
    expect(safe.daysRemaining, 16); // 30 - 15 + 1
  });

  test('no budgets -> pace reports no budgets', () {
    final pace = service.pace(transactions: [], categories: [], asOf: asOf);
    expect(pace.hasBudgets, isFalse);
  });
}
