import 'package:aiko/core/money/money.dart';
import 'package:aiko/features/accounts/domain/account.dart';
import 'package:aiko/features/aiko_assistant/application/financial_context.dart';
import 'package:aiko/features/budgets/domain/budget.dart';
import 'package:aiko/features/goals/domain/goal.dart';
import 'package:aiko/features/transactions/domain/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Fixed clock so month-window filtering is deterministic.
  final now = DateTime(2026, 6, 14);

  Account account(String name, AccountType type, String balance) => Account(
    id: name,
    userId: 'u',
    name: name,
    type: type,
    currentBalance: Money.parse(balance, 'USD'),
  );

  FinanceTransaction tx(
    String id,
    TransactionType type,
    String amount,
    DateTime date, {
    String? categoryId,
  }) => FinanceTransaction(
    id: id,
    userId: 'u',
    accountId: 'acc',
    type: type,
    amount: Money.parse(amount, 'USD'),
    date: date,
    categoryId: categoryId,
  );

  test('net worth subtracts credit/loan/liability balances', () {
    final ctx = AikoFinancialContext.from(
      baseCurrency: 'USD',
      accounts: [
        account('Checking', AccountType.bank, '1000'),
        account('Visa', AccountType.creditCard, '200'),
      ],
      budgets: const [],
      goals: const [],
      transactions: const [],
      now: now,
    );

    expect(ctx.netWorth, 800.0);
    expect(ctx.accounts, hasLength(2));
  });

  test('this-month income/spending only counts the current month', () {
    final ctx = AikoFinancialContext.from(
      baseCurrency: 'USD',
      accounts: const [],
      budgets: const [],
      goals: const [],
      transactions: [
        tx('a', TransactionType.income, '500', DateTime(2026, 6, 14)),
        tx('b', TransactionType.expense, '120', DateTime(2026, 6, 13)),
        tx(
          'c',
          TransactionType.expense,
          '999',
          DateTime(2026, 5, 30),
        ), // last month
      ],
      now: now,
    );

    expect(ctx.monthIncome, 500.0);
    expect(ctx.monthSpending, 120.0);
    expect(ctx.toJson()['thisMonth'], {
      'income': 500.0,
      'spending': 120.0,
      'net': 380.0,
    });
  });

  test('budget pace flags over-limit categories', () {
    final ctx = AikoFinancialContext.from(
      baseCurrency: 'USD',
      accounts: const [],
      budgets: [
        Budget(
          id: 'bud',
          userId: 'u',
          name: 'Groceries',
          categoryId: 'cat-groceries',
          amount: Money.parse('100', 'USD'),
          periodStart: DateTime(2026, 6, 1),
          periodEnd: DateTime(2026, 6, 30),
        ),
      ],
      goals: const [],
      transactions: [
        tx(
          'b',
          TransactionType.expense,
          '120',
          DateTime(2026, 6, 13),
          categoryId: 'cat-groceries',
        ),
      ],
      now: now,
    );

    expect(ctx.budgets.single.pace, 'over');
    expect(ctx.budgets.single.spent, 120.0);
    expect(ctx.budgets.single.limit, 100.0);
  });

  test('goals report progress and recent transactions sort newest first', () {
    final ctx = AikoFinancialContext.from(
      baseCurrency: 'USD',
      accounts: const [],
      budgets: const [],
      goals: [
        Goal(
          id: 'g',
          userId: 'u',
          name: 'Emergency',
          purpose: GoalPurpose.emergencyFund,
          targetAmount: Money.parse('1000', 'USD'),
          currentAmount: Money.parse('250', 'USD'),
          targetDate: DateTime(2026, 12, 1),
        ),
      ],
      transactions: [
        tx('older', TransactionType.expense, '10', DateTime(2026, 6, 10)),
        tx('newer', TransactionType.income, '20', DateTime(2026, 6, 14)),
      ],
      now: now,
    );

    expect(ctx.goals.single.pct, 0.25);
    expect(ctx.recentTransactions.first.type, 'income');
    expect(ctx.recentTransactions.last.type, 'expense');
  });
}
