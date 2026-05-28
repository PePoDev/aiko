import 'package:aiko/app/providers.dart';
import 'package:aiko/features/categories/domain/category.dart';
import 'package:aiko/features/categories/presentation/category_management_screen.dart';
import 'package:aiko/theme/aiko_colors.dart';
import 'package:aiko/theme/aiko_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('categories are grouped by transaction type and origin', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          categoriesProvider.overrideWith(
            () => _CategoriesNotifier([
              const Category(
                id: 'default-income-salary',
                userId: 'user',
                name: 'Salary',
                type: CategoryType.income,
                group: CategoryGroup.custom,
                icon: 'salary',
                color: '#22C55E',
                budgetEnabled: false,
              ),
              const Category(
                id: 'default-expense-groceries',
                userId: 'user',
                name: 'Groceries',
                type: CategoryType.expense,
                group: CategoryGroup.needs,
                icon: 'food',
                color: '#F97316',
                budgetEnabled: true,
              ),
              const Category(
                id: 'side-hustle',
                userId: 'user',
                name: 'Side Hustle',
                type: CategoryType.income,
                group: CategoryGroup.business,
                icon: 'salary',
                color: '#14B8A6',
                budgetEnabled: false,
              ),
              const Category(
                id: 'custom-coffee',
                userId: 'user',
                name: 'Coffee',
                type: CategoryType.expense,
                group: CategoryGroup.wants,
                icon: 'coffee',
                color: '#8B5CF6',
                budgetEnabled: true,
              ),
            ]),
          ),
        ],
        child: MaterialApp(
          theme: AikoTheme.light(),
          home: const CategoryManagementScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Income'), findsOneWidget);
    expect(find.text('Expense'), findsOneWidget);
    expect(find.text('Default'), findsNWidgets(2));
    expect(find.text('Custom'), findsNWidgets(3));
    expect(find.text('Salary'), findsOneWidget);
    expect(find.text('Side Hustle'), findsOneWidget);
    expect(find.text('Groceries'), findsOneWidget);
    expect(find.text('Coffee'), findsOneWidget);
  });

  testWidgets('default category details cannot be edited or deleted', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          categoriesProvider.overrideWith(
            () => _CategoriesNotifier([
              const Category(
                id: 'default-income-salary',
                userId: 'user',
                name: 'Salary',
                type: CategoryType.income,
                group: CategoryGroup.custom,
                icon: 'salary',
                color: '#22C55E',
                budgetEnabled: false,
              ),
            ]),
          ),
        ],
        child: MaterialApp(
          theme: AikoTheme.light(),
          home: const CategoryManagementScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('Salary'));
    await tester.pumpAndSettle();

    expect(find.text('Category details'), findsOneWidget);
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
    expect(find.byIcon(Icons.delete_outline), findsNothing);
    expect(find.text('Default category'), findsOneWidget);
  });

  testWidgets('category item opens details screen', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          categoriesProvider.overrideWith(
            () => _CategoriesNotifier([
              const Category(
                id: 'coffee',
                userId: 'user',
                name: 'Coffee',
                type: CategoryType.expense,
                group: CategoryGroup.wants,
                icon: 'coffee',
                color: '#8B5CF6',
                budgetEnabled: true,
              ),
            ]),
          ),
        ],
        child: MaterialApp(
          theme: AikoTheme.light(),
          home: const CategoryManagementScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('Coffee'));
    await tester.pumpAndSettle();

    expect(find.text('Category details'), findsOneWidget);
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    expect(find.text('Coffee'), findsWidgets);
    expect(find.text('Type'), findsOneWidget);
    expect(find.text('Expense'), findsOneWidget);
    expect(find.text('Group'), findsOneWidget);
    expect(find.text('Wants'), findsOneWidget);
    expect(find.text('Budget'), findsNothing);
    expect(find.text('Enabled'), findsNothing);
    expect(find.text('#8B5CF6'), findsOneWidget);
    expect(find.byIcon(Icons.coffee_outlined), findsWidgets);
  });

  testWidgets('category rows use compact list tiles', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          categoriesProvider.overrideWith(
            () => _CategoriesNotifier([
              const Category(
                id: 'coffee',
                userId: 'user',
                name: 'Coffee',
                type: CategoryType.expense,
                group: CategoryGroup.wants,
                icon: 'coffee',
                color: '#8B5CF6',
                budgetEnabled: true,
              ),
            ]),
          ),
        ],
        child: MaterialApp(
          theme: AikoTheme.light(),
          home: const CategoryManagementScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final rowFinder = find.ancestor(
      of: find.text('Coffee'),
      matching: find.byType(ListTile),
    );

    expect(rowFinder, findsOneWidget);

    final row = tester.widget<ListTile>(rowFinder);
    expect(row.dense, isTrue);
    expect(row.visualDensity, VisualDensity.compact);
    expect(find.text('Wants'), findsOneWidget);
    expect(find.text('Wants - Expense'), findsNothing);
  });

  testWidgets('category details color follows category transaction type', (
    tester,
  ) async {
    final cases = [
      (
        type: CategoryType.expense,
        name: 'Coffee',
        iconName: 'coffee',
        icon: Icons.coffee_outlined,
        expected: AikoColors.dangerRed,
      ),
      (
        type: CategoryType.income,
        name: 'Salary',
        iconName: 'salary',
        icon: Icons.attach_money_outlined,
        expected: AikoColors.successGreen,
      ),
      (
        type: CategoryType.transfer,
        name: 'Move Money',
        iconName: 'category',
        icon: Icons.category_outlined,
        expected: AikoColors.primaryBlue,
      ),
    ];

    for (final testCase in cases) {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AikoTheme.light(),
            home: CategoryDetailScreen(
              category: Category(
                id: testCase.name,
                userId: 'user',
                name: testCase.name,
                type: testCase.type,
                group: CategoryGroup.custom,
                icon: testCase.iconName,
                color: '#8B5CF6',
              ),
              categoryIcon: testCase.icon,
              categoryColor: AikoColors.premiumPurple,
              typeLabel: testCase.type.name,
              groupLabel: 'Custom',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final icon = tester.widget<Icon>(find.byIcon(testCase.icon).first);
      expect(icon.color, testCase.expected);
    }
  });

  testWidgets('add category sheet does not expose budget membership toggle', (
    tester,
  ) async {
    final notifier = _SavingCategoriesNotifier([
      const Category(
        id: 'coffee',
        userId: 'user',
        name: 'Coffee',
        type: CategoryType.expense,
        group: CategoryGroup.wants,
        icon: 'coffee',
        color: '#8B5CF6',
        budgetEnabled: true,
      ),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [categoriesProvider.overrideWith(() => notifier)],
        child: MaterialApp(
          theme: AikoTheme.light(),
          home: const CategoryManagementScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FloatingActionButton, 'Add Category'));
    await tester.pumpAndSettle();

    expect(find.text('Include in Budgets'), findsNothing);
    expect(
      find.text('Enables setting up spending budget rules for this category'),
      findsNothing,
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Category Name'),
      'Gym',
    );
    final saveButton = find.widgetWithText(FilledButton, 'Save Category');
    await tester.scrollUntilVisible(
      saveButton,
      180,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(notifier.savedCategory?.name, 'Gym');
    expect(notifier.savedCategory?.budgetEnabled, isTrue);
  });
}

class _CategoriesNotifier extends CategoriesNotifier {
  _CategoriesNotifier(this.categories);

  final List<Category> categories;

  @override
  Future<List<Category>> build() async => categories;
}

class _SavingCategoriesNotifier extends _CategoriesNotifier {
  _SavingCategoriesNotifier(super.categories);

  Category? savedCategory;

  @override
  Future<void> saveCategory(Category category) async {
    savedCategory = category;
    state = AsyncValue.data([...categories, category]);
  }
}
