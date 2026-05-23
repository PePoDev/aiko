import 'package:aiko/app/providers.dart';
import 'package:aiko/core/money/money.dart';
import 'package:aiko/features/budgets/data/budget_repository.dart';
import 'package:aiko/features/budgets/domain/budget.dart';
import 'package:aiko/features/budgets/presentation/budget_overview_screen.dart';
import 'package:aiko/features/categories/data/category_repository.dart';
import 'package:aiko/features/categories/domain/category.dart';
import 'package:aiko/theme/aiko_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('budget overview shows recommendation', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          budgetRepositoryProvider.overrideWithValue(
            _FakeBudgetRepository([
              Budget(
                id: 'groceries-budget',
                userId: 'user',
                name: 'Groceries',
                categoryId: 'groceries',
                amount: Money.parse('500', 'USD'),
                periodStart: DateTime(2026, 5),
                periodEnd: DateTime(2026, 5, 31),
              ),
            ]),
          ),
        ],
        child: MaterialApp(
          theme: AikoTheme.light(),
          home: const BudgetOverviewScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Aiko recommendation'), findsOneWidget);
  });

  testWidgets('budget form saves a new monthly budget', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          budgetRepositoryProvider.overrideWithValue(_FakeBudgetRepository([])),
          categoryRepositoryProvider.overrideWithValue(
            const _FakeCategoryRepository([
              Category(
                id: 'groceries',
                userId: 'user',
                name: 'Groceries',
                type: CategoryType.expense,
                group: CategoryGroup.needs,
              ),
            ]),
          ),
        ],
        child: MaterialApp(
          theme: AikoTheme.light(),
          home: const BudgetOverviewScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('Budget').last);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'Groceries');
    await tester.enterText(find.byType(TextField).at(1), '500');
    await tester.tap(find.text('Save budget'));
    await tester.pumpAndSettle();

    expect(find.text('Groceries'), findsOneWidget);
    expect(find.textContaining('500.00'), findsOneWidget);
  });

  testWidgets('preset budgets skip duplicates for current month', (
    tester,
  ) async {
    final now = DateTime.now();
    final periodStart = DateTime(now.year, now.month);
    final periodEnd = DateTime(now.year, now.month + 1, 0);
    final budgetRepository = _FakeBudgetRepository([
      Budget(
        id: 'needs-existing',
        userId: 'user',
        name: 'Needs',
        categoryId: 'needs',
        amount: Money.parse('1500', 'THB'),
        periodStart: periodStart,
        periodEnd: periodEnd,
      ),
      Budget(
        id: 'wants-existing',
        userId: 'user',
        name: 'Wants',
        categoryId: 'wants',
        amount: Money.parse('900', 'THB'),
        periodStart: periodStart,
        periodEnd: periodEnd,
      ),
      Budget(
        id: 'savings-existing',
        userId: 'user',
        name: 'Savings',
        categoryId: 'savings',
        amount: Money.parse('600', 'THB'),
        periodStart: periodStart,
        periodEnd: periodEnd,
      ),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          budgetRepositoryProvider.overrideWithValue(budgetRepository),
          categoryRepositoryProvider.overrideWithValue(
            const _FakeCategoryRepository([
              Category(
                id: 'needs',
                userId: 'user',
                name: 'Needs',
                type: CategoryType.expense,
                group: CategoryGroup.needs,
              ),
              Category(
                id: 'wants',
                userId: 'user',
                name: 'Wants',
                type: CategoryType.expense,
                group: CategoryGroup.wants,
              ),
              Category(
                id: 'savings',
                userId: 'user',
                name: 'Savings',
                type: CategoryType.expense,
                group: CategoryGroup.savings,
              ),
            ]),
          ),
        ],
        child: MaterialApp(
          theme: AikoTheme.light(),
          home: const BudgetOverviewScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('Budget').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aiko Presets'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Save Preset Budgets'),
      320,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Save Preset Budgets'));
    await tester.pumpAndSettle();

    expect(budgetRepository.savedCount, 0);
    expect(
      find.text('These preset budgets already exist for this month.'),
      findsOneWidget,
    );
  });

  testWidgets('budget card opens details, edits, and deletes', (tester) async {
    final repository = _FakeBudgetRepository([
      Budget(
        id: 'groceries-budget',
        userId: 'user',
        name: 'Groceries',
        categoryId: 'groceries',
        amount: Money.parse('500', 'THB'),
        periodStart: DateTime(2026, 5),
        periodEnd: DateTime(2026, 5, 31),
      ),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          budgetRepositoryProvider.overrideWithValue(repository),
          categoryRepositoryProvider.overrideWithValue(
            const _FakeCategoryRepository([
              Category(
                id: 'groceries',
                userId: 'user',
                name: 'Groceries',
                type: CategoryType.expense,
                group: CategoryGroup.needs,
              ),
            ]),
          ),
        ],
        child: MaterialApp(
          theme: AikoTheme.light(),
          home: const BudgetOverviewScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('Groceries').first);
    await tester.pumpAndSettle();

    expect(find.text('Budget details'), findsOneWidget);
    expect(find.text('Period'), findsOneWidget);

    await tester.tap(find.byTooltip('Edit budget'));
    await tester.pumpAndSettle();
    expect(find.text('Edit budget'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Monthly amount'),
      '650',
    );
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(repository._budgets.single.amount.amount.toString(), '650');
    expect(find.textContaining('650.00'), findsOneWidget);

    await tester.tap(find.byTooltip('Delete budget'));
    await tester.pumpAndSettle();
    expect(find.text('Delete budget?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(repository._budgets, isEmpty);
    expect(find.text('No budgets yet'), findsOneWidget);
  });

  testWidgets('daily spending budget edits limit and included categories', (
    tester,
  ) async {
    final repository = _FakeBudgetRepository([
      Budget(
        id: Budget.dailySpendingId,
        userId: 'user',
        name: 'Daily Spending',
        categoryId: 'groceries',
        amount: Money.parse('100', 'THB'),
        periodStart: DateTime(2026, 5, 23),
        periodEnd: DateTime(2026, 5, 23, 23, 59, 59),
        period: BudgetPeriod.daily,
        includedCategoryIds: const ['groceries'],
        isAppDefined: true,
      ),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          budgetRepositoryProvider.overrideWithValue(repository),
          categoryRepositoryProvider.overrideWithValue(
            const _FakeCategoryRepository([
              Category(
                id: 'groceries',
                userId: 'user',
                name: 'Groceries',
                type: CategoryType.expense,
                group: CategoryGroup.needs,
              ),
              Category(
                id: 'dining',
                userId: 'user',
                name: 'Dining',
                type: CategoryType.expense,
                group: CategoryGroup.wants,
              ),
            ]),
          ),
        ],
        child: MaterialApp(
          theme: AikoTheme.light(),
          home: const BudgetOverviewScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Daily Spending'), findsOneWidget);
    expect(find.text('1 category included'), findsOneWidget);

    await tester.tap(find.text('Daily Spending').first);
    await tester.pumpAndSettle();

    expect(find.byTooltip('Delete budget'), findsNothing);
    await tester.tap(find.byTooltip('Edit budget'));
    await tester.pumpAndSettle();

    expect(find.text('Daily Spending'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Daily limit'), findsOneWidget);
    expect(find.text('Included categories'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Daily limit'),
      '250',
    );
    await tester.tap(find.text('Dining'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(repository._budgets.single.amount.amount.toString(), '250');
    expect(repository._budgets.single.includedCategoryIds, [
      'groceries',
      'dining',
    ]);
    expect(repository._budgets.single.isAppDefined, isTrue);
  });
}

class _FakeBudgetRepository extends BudgetRepository {
  _FakeBudgetRepository(this._budgets);

  final List<Budget> _budgets;
  var savedCount = 0;

  @override
  Future<List<Budget>> list() async => List.unmodifiable(_budgets);

  @override
  Future<Budget> save(Budget budget) async {
    savedCount++;
    _budgets.removeWhere((item) => item.id == budget.id);
    _budgets.add(budget);
    return budget;
  }

  @override
  Future<void> delete(String id) async {
    _budgets.removeWhere((item) => item.id == id);
  }
}

class _FakeCategoryRepository extends CategoryRepository {
  const _FakeCategoryRepository(this._categories);

  final List<Category> _categories;

  @override
  Future<List<Category>> list() async => _categories;
}
