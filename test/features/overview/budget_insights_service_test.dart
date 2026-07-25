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
}
