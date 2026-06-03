import 'package:aiko/app/providers.dart';
import 'package:aiko/features/categories/domain/category.dart';
import 'package:aiko/features/categories/presentation/category_management_screen.dart';
import 'package:aiko/theme/aiko_colors.dart';
import 'package:aiko/theme/aiko_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('categories show expense first and switch to income by swipe', (
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
    expect(find.byType(TabBar), findsOneWidget);
    expect(find.byType(TabBarView), findsOneWidget);
    expect(
      tester.widget<TabBar>(find.byType(TabBar)).labelColor,
      AikoColors.dangerRed,
    );
    expect(find.text('Default'), findsNothing);
    expect(find.text('Custom'), findsNothing);
    expect(find.text('Salary'), findsNothing);
    expect(find.text('Side Hustle'), findsNothing);
    expect(find.text('Groceries'), findsOneWidget);
    expect(find.text('Coffee'), findsOneWidget);

    await tester.drag(find.byType(TabBarView), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(find.text('Salary'), findsOneWidget);
    expect(find.text('Side Hustle'), findsOneWidget);
    expect(find.text('Groceries'), findsNothing);
    expect(find.text('Coffee'), findsNothing);
    expect(
      tester.widget<TabBar>(find.byType(TabBar)).labelColor,
      AikoColors.successGreen,
    );
    expect(find.byTooltip('Add category'), findsOneWidget);
    expect(find.byTooltip('About categories'), findsNothing);
    expect(find.byIcon(Icons.info_outline), findsNothing);
  });

  testWidgets('default category tap does not open a popup or route', (
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
    await tester.tap(find.text('Income'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salary'));
    await tester.pumpAndSettle();

    expect(find.text('Edit Category'), findsNothing);
    expect(find.text('Category details'), findsNothing);
    expect(find.text('Salary'), findsOneWidget);
  });

  testWidgets('custom category item opens edit category popup', (tester) async {
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

    expect(find.text('Category details'), findsNothing);
    expect(find.text('Edit Category'), findsOneWidget);
    expect(find.text('Coffee'), findsWidgets);
    expect(find.text('Expense'), findsWidgets);
    expect(find.text('Wants'), findsNothing);
    expect(find.text('Category Group (50/30/20 Rule)'), findsNothing);
    expect(find.text('Budget'), findsNothing);
    expect(find.text('Enabled'), findsNothing);
    expect(find.byIcon(Icons.coffee_outlined), findsWidgets);
  });

  testWidgets('edit category sheet can delete a custom category', (
    tester,
  ) async {
    final notifier = _DeletingCategoriesNotifier([
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
    await tester.tap(find.text('Coffee'));
    await tester.pumpAndSettle();

    expect(
      find.widgetWithText(OutlinedButton, 'Delete Category'),
      findsNothing,
    );

    final deleteButton = find.byTooltip('Delete category');
    expect(deleteButton, findsOneWidget);

    await tester.tap(deleteButton);
    await tester.pumpAndSettle();

    expect(find.text('Delete "Coffee"?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(notifier.deletedId, 'coffee');
    expect(find.text('Edit Category'), findsNothing);
    expect(find.text('Coffee'), findsNothing);
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
    expect(find.byIcon(Icons.chevron_right), findsNothing);
    expect(find.text('Wants'), findsNothing);
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
    await tester.tap(find.text('Income'));
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
    expect(find.text('Category Group (50/30/20 Rule)'), findsNothing);

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
    expect(notifier.savedCategory?.group, CategoryGroup.custom);
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
    expect(
      tester.getTopLeft(find.byKey(const Key('category-type-selector'))).dy,
      lessThan(
        tester
            .getTopLeft(find.widgetWithText(TextFormField, 'Category Name'))
            .dy,
      ),
    );

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

  testWidgets('add category sheet defaults type from selected category tab', (
    tester,
  ) async {
    final notifier = _SavingCategoriesNotifier([
      const Category(
        id: 'coffee',
        userId: 'user',
        name: 'Coffee',
        type: CategoryType.expense,
        group: CategoryGroup.custom,
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
    await tester.tap(
      find.descendant(of: find.byType(TabBar), matching: find.text('Income')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Add category'));
    await tester.pumpAndSettle();

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

  testWidgets('add category sheet centers icons in a balanced grid', (
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
      find.descendant(of: gridFinder, matching: find.byType(GridView)),
      findsOneWidget,
    );
    final gridView = tester.widget<GridView>(
      find.descendant(of: gridFinder, matching: find.byType(GridView)),
    );
    final delegate =
        gridView.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.crossAxisCount, greaterThanOrEqualTo(5));
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

class _DeletingCategoriesNotifier extends _CategoriesNotifier {
  _DeletingCategoriesNotifier(super.categories);

  String? deletedId;

  @override
  Future<void> deleteCategory(String id) async {
    deletedId = id;
    state = AsyncValue.data(
      categories.where((category) => category.id != id).toList(growable: false),
    );
  }
}
