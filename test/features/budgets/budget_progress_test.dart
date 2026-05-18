import 'package:aiko/core/money/money.dart';
import 'package:aiko/features/budgets/application/budget_progress_service.dart';
import 'package:aiko/features/budgets/domain/budget.dart';
import 'package:aiko/features/transactions/domain/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('budget progress sums category spending', () {
    final budget = Budget(
      id: 'b1',
      userId: 'user',
      name: 'Food',
      categoryId: 'food',
      amount: Money.parse('100', 'USD'),
      periodStart: DateTime(2026),
      periodEnd: DateTime(2026, 1, 31),
    );
    final progress = const BudgetProgressService().progressFor(budget, [
      FinanceTransaction(
        id: 't1',
        userId: 'user',
        accountId: 'cash',
        type: TransactionType.expense,
        amount: Money.parse('25', 'USD'),
        date: DateTime(2026, 1, 10),
        categoryId: 'food',
      ),
    ]);

    expect(progress.percentUsed, 25);
  });
}
