import 'package:aiko/core/money/money.dart';
import 'package:aiko/features/categories/application/category_budget_progress_service.dart';
import 'package:aiko/features/categories/domain/category.dart';
import 'package:aiko/features/transactions/domain/transaction.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aiko/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';

void main() {
  final english = lookupAppLocalizations(const Locale('en'));

  const service = CategoryBudgetProgressService();

  Category categoryWithBudget(Money limit) {
    return Category(
      id: 'cat-1',
      userId: 'u',
      name: 'Groceries',
      type: CategoryType.expense,
      group: CategoryBudgetGroup.needs,
      icon: 'cart',
      color: '#000000',
      budgetEnabled: true,
      monthlyLimit: limit,
    );
  }

  FinanceTransaction postedExpense({
    required String id,
    required String categoryId,
    required Money amount,
    DateTime? date,
  }) {
    return FinanceTransaction(
      id: id,
      userId: 'u',
      accountId: 'acc',
      type: TransactionType.expense,
      amount: amount,
      date: date ?? DateTime.utc(2026, 6, 15),
      categoryId: categoryId,
    );
  }

  group('CategoryBudgetProgressService.progressFor', () {
    test('sums posted expenses for the matching category in the window', () {
      final category = categoryWithBudget(Money.parse('200', 'USD'));
      final txns = [
        postedExpense(
          id: 't1',
          categoryId: 'cat-1',
          amount: Money.parse('30', 'USD'),
        ),
        postedExpense(
          id: 't2',
          categoryId: 'cat-1',
          amount: Money.parse('20', 'USD'),
        ),
        postedExpense(
          id: 't3',
          categoryId: 'cat-other',
          amount: Money.parse('999', 'USD'),
        ),
      ];
      final result = service.progressFor(
        category,
        txns,
        periodStart: DateTime.utc(2026, 6, 1),
        periodEnd: DateTime.utc(2026, 6, 30, 23, 59, 59),
      );
      expect(result.used.amount.toString(), '50');
      expect(result.ratio, closeTo(0.25, 0.001));
    });

    test('ignores income and non-posted transactions', () {
      final category = categoryWithBudget(Money.parse('200', 'USD'));
      final txns = [
        FinanceTransaction(
          id: 't1',
          userId: 'u',
          accountId: 'acc',
          type: TransactionType.income,
          amount: Money.parse('100', 'USD'),
          date: DateTime.utc(2026, 6, 15),
          categoryId: 'cat-1',
        ),
      ];
      final result = service.progressFor(
        category,
        txns,
        periodStart: DateTime.utc(2026, 6, 1),
        periodEnd: DateTime.utc(2026, 6, 30, 23, 59, 59),
      );
      expect(result.used.amount.toString(), '0');
    });
  });

  group('CategoryBudgetProgress', () {
    test('remaining is null when no limit is set', () {
      final category = Category(
        id: 'cat-1',
        userId: 'u',
        name: 'X',
        type: CategoryType.expense,
        group: CategoryBudgetGroup.needs,
        icon: 'x',
        color: '#000000',
      );
      final result = CategoryBudgetProgress(
        category: category,
        used: Money.parse('10', 'USD'),
      );
      expect(result.limit, isNull);
      expect(result.remaining, isNull);
    });

    test('remaining caps at zero when over-budget', () {
      final category = categoryWithBudget(Money.parse('50', 'USD'));
      final result = CategoryBudgetProgress(
        category: category,
        used: Money.parse('100', 'USD'),
      );
      expect(result.isOverBudget, isTrue);
      expect(result.remaining?.amount.toString(), '0');
    });
  });

  group('CategoryBudgetProgressService.recommendation', () {
    test('returns the no-budget message when the category has no limit', () {
      final category = Category(
        id: 'cat-1',
        userId: 'u',
        name: 'X',
        type: CategoryType.expense,
        group: CategoryBudgetGroup.needs,
        icon: 'x',
        color: '#000000',
      );
      final result = service.progressFor(category, const []);
      expect(service.recommendation(result, 7, english), contains('No budget'));
    });

    test('offers a daily-limit suggestion when on track', () {
      final category = categoryWithBudget(Money.parse('300', 'USD'));
      final result = service.progressFor(category, [
        postedExpense(
          id: 't1',
          categoryId: 'cat-1',
          amount: Money.parse('50', 'USD'),
        ),
      ]);
      final message = service.recommendation(result, 10, english);
      expect(message, contains('Keep this category under'));
      expect(message, contains('USD/day'));
    });
  });
}
