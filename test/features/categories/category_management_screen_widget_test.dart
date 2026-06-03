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
    expect(find.text('Default'), findsNothing);
    expect(find.text('Custom'), findsOneWidget);
    expect(find.text('Salary'), findsOneWidget);
    expect(find.text('Side Hustle'), findsOneWidget);
    expect(find.text('Groceries'), findsOneWidget);
    expect(find.text('Coffee'), findsOneWidget);
    expect(find.byTooltip('Add category'), findsOneWidget);
    expect(find.byTooltip('About categories'), findsNothing);
    expect(find.byIcon(Icons.info_outline), findsNothing);
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

  testWidgets('category items use compact box cards', (tester) async {
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

    final itemFinder = find.ancestor(
      of: find.text('Coffee'),
      matching: find.byType(Card),
    );

    expect(itemFinder, findsOneWidget);

    expect(find.byType(ListTile), findsNothing);
    expect(find.text('Wants'), findsOneWidget);
    expect(find.text('Wants - Expense'), findsNothing);
  });

  testWidgets('default category items show a lock without dimming the card', (
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
              ),
              const Category(
                id: 'side-hustle',
                userId: 'user',
                name: 'Side Hustle',
                type: CategoryType.income,
                group: CategoryGroup.business,
                icon: 'salary',
                color: '#14B8A6',
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

    final defaultCardFinder = find.ancestor(
      of: find.text('Salary'),
      matching: find.byType(Card),
    );
    final customCardFinder = find.ancestor(
      of: find.text('Side Hustle'),
      matching: find.byType(Card),
    );
    final defaultCard = tester.widget<Card>(defaultCardFinder);
    final customCard = tester.widget<Card>(customCardFinder);

    expect(find.text('Default'), findsNothing);
    expect(defaultCard.color, customCard.color);
    expect(
      find.descendant(
        of: defaultCardFinder,
        matching: find.byIcon(Icons.lock_outline),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: customCardFinder,
        matching: find.byIcon(Icons.lock_outline),
      ),
      findsNothing,
    );
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
    await tester.tap(find.byTooltip('Add category'));
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

  testWidgets('add category sheet limits type selector to income and expense', (
    tester,
  ) async {
    final notifier = _SavingCategoriesNotifier(const []);

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
    await tester.tap(find.byTooltip('Add category'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('category-type-selector')), findsOneWidget);
    expect(
      find.widgetWithText(
        DropdownButtonFormField<CategoryType>,
        'Category Type',
      ),
      findsNothing,
    );
    expect(find.text('Expense'), findsOneWidget);
    expect(find.text('Income'), findsOneWidget);
    expect(find.textContaining('Transfer'), findsNothing);

    await tester.tap(find.text('Income'));
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Category Name'),
      'Bonus',
    );
    final saveButton = find.widgetWithText(FilledButton, 'Save Category');
    await tester.scrollUntilVisible(
      saveButton,
      180,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(notifier.savedCategory?.type, CategoryType.income);
  });

  testWidgets('add category sheet shows icons in a vertical multi-line grid', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          categoriesProvider.overrideWith(
            () => _SavingCategoriesNotifier(const []),
          ),
        ],
        child: MaterialApp(
          theme: AikoTheme.light(),
          home: const CategoryManagementScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Add category'));
    await tester.pumpAndSettle();

    final gridFinder = find.byKey(const Key('category-icon-grid'));
    expect(gridFinder, findsOneWidget);
    expect(
      find.descendant(of: gridFinder, matching: find.byType(Wrap)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: gridFinder, matching: find.byType(ListView)),
      findsNothing,
    );
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
