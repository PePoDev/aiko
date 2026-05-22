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
    expect(find.text(r'$500.00'), findsOneWidget);
  });
}

class _FakeBudgetRepository extends BudgetRepository {
  _FakeBudgetRepository(this._budgets);

  final List<Budget> _budgets;

  @override
  Future<List<Budget>> list() async => List.unmodifiable(_budgets);

  @override
  Future<Budget> save(Budget budget) async {
    _budgets.removeWhere((item) => item.id == budget.id);
    _budgets.add(budget);
    return budget;
  }
}

class _FakeCategoryRepository extends CategoryRepository {
  const _FakeCategoryRepository(this._categories);

  final List<Category> _categories;

  @override
  Future<List<Category>> list() async => _categories;
}
