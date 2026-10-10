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

  group('budgetPeriodWindow', () {
    // Wednesday 14 October 2026, mid-afternoon.
    final asOf = DateTime(2026, 10, 14, 15, 30);

    test('covers whole days, Monday-start weeks, months and years', () {
      expect(budgetPeriodWindow(CategoryBudgetPeriod.daily, asOf), (
        start: DateTime(2026, 10, 14),
        end: DateTime(2026, 10, 15),
      ));
      expect(budgetPeriodWindow(CategoryBudgetPeriod.weekly, asOf), (
        start: DateTime(2026, 10, 12),
        end: DateTime(2026, 10, 19),
      ));
      expect(budgetPeriodWindow(CategoryBudgetPeriod.monthly, asOf), (
        start: DateTime(2026, 10),
        end: DateTime(2026, 11),
      ));
      expect(budgetPeriodWindow(CategoryBudgetPeriod.yearly, asOf), (
        start: DateTime(2026),
        end: DateTime(2027),
      ));
    });

    test('a week crossing a month boundary', () {
      // Thursday 1 October 2026 belongs to the week of Monday 28 September.
      expect(
        budgetPeriodWindow(CategoryBudgetPeriod.weekly, DateTime(2026, 10, 1)),
        (start: DateTime(2026, 9, 28), end: DateTime(2026, 10, 5)),
      );
    });
  });

  group('budget periods and rollover', () {
    Category budget(
      CategoryBudgetPeriod period, {
      bool rollover = false,
      DateTime? createdAt,
    }) => Category(
      id: 'cat-1',
      userId: 'u',
      name: 'Food',
      type: CategoryType.expense,
      group: CategoryBudgetGroup.needs,
      monthlyLimit: Money.parse('1000', 'THB'),
      budgetPeriod: period,
      rolloverUnused: rollover,
      createdAt: createdAt,
    );

    FinanceTransaction spend(String amount, DateTime date) => postedExpense(
      id: '$amount@$date',
      categoryId: 'cat-1',
      amount: Money.parse(amount, 'THB'),
      date: date,
    );

    test('weekly budgets count the whole current week only', () {
      final result = service.progressFor(budget(CategoryBudgetPeriod.weekly), [
        spend('100', DateTime(2026, 10, 12, 0, 5)), // Monday
        spend('200', DateTime(2026, 10, 18, 23, 50)), // Sunday
        spend('999', DateTime(2026, 10, 11, 23)), // previous Sunday
      ], asOf: DateTime(2026, 10, 14, 15));
      expect(result.used, Money.parse('300', 'THB'));
    });

    test('monthly budgets count the last day of the month', () {
      final result = service.progressFor(budget(CategoryBudgetPeriod.monthly), [
        spend('400', DateTime(2026, 10, 31, 20)),
      ], asOf: DateTime(2026, 10, 31, 8));
      expect(result.used, Money.parse('400', 'THB'));
    });

    test('unused budget from the previous period carries over', () {
      final result = service.progressFor(
        budget(
          CategoryBudgetPeriod.monthly,
          rollover: true,
          createdAt: DateTime(2026, 8, 1),
        ),
        [
          spend('700', DateTime(2026, 9, 10)), // 300 left in September
          spend('100', DateTime(2026, 10, 2)),
        ],
        asOf: DateTime(2026, 10, 14),
      );
      expect(result.carriedOver, Money.parse('300', 'THB'));
      expect(result.limit, Money.parse('1300', 'THB'));
      expect(result.remaining, Money.parse('1200', 'THB'));
    });

    test('nothing carries over without rollover, after overspending, '
        'or into the first period', () {
      final transactions = [spend('700', DateTime(2026, 9, 10))];
      final asOf = DateTime(2026, 10, 14);
      expect(
        service
            .progressFor(
              budget(CategoryBudgetPeriod.monthly, createdAt: DateTime(2026)),
              transactions,
              asOf: asOf,
            )
            .limit,
        Money.parse('1000', 'THB'),
      );
      expect(
        service.progressFor(
          budget(
            CategoryBudgetPeriod.monthly,
            rollover: true,
            createdAt: DateTime(2026),
          ),
          [spend('1500', DateTime(2026, 9, 10))],
          asOf: asOf,
        ).carriedOver,
        isNull,
      );
      expect(
        service
            .progressFor(
              budget(
                CategoryBudgetPeriod.monthly,
                rollover: true,
                createdAt: DateTime(2026, 10, 3),
              ),
              const [],
              asOf: asOf,
            )
            .carriedOver,
        isNull,
      );
    });
  });
}
