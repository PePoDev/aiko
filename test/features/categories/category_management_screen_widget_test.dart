import 'package:aiko/app/providers.dart';
import 'package:aiko/features/categories/domain/category.dart';
import 'package:aiko/features/categories/domain/category_defaults.dart';
import 'package:aiko/features/categories/presentation/category_management_screen.dart';
import 'package:aiko/theme/aiko_colors.dart';
import 'package:aiko/theme/aiko_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'expense tab shows the system group by default and switches to income',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            categoriesProvider.overrideWith(
              () => _CategoriesNotifier([
                Category(
                  id: CategoryDefaults.salaryId,
                  userId: 'user',
                  name: 'Salary',
                  type: CategoryType.income,
                  group: CategoryBudgetGroup.custom,
                  icon: 'salary',
                  color: '#22C55E',
                  budgetEnabled: false,
                ),
                Category(
                  id: CategoryDefaults.groceriesId,
                  userId: 'user',
                  name: 'Groceries',
                  type: CategoryType.expense,
                  group: CategoryBudgetGroup.needs,
                  icon: 'food',
                  color: '#F97316',
                  budgetEnabled: true,
                ),
                const Category(
                  id: 'side-hustle',
                  userId: 'user',
                  name: 'Side Hustle',
                  type: CategoryType.income,
                  group: CategoryBudgetGroup.business,
                  icon: 'salary',
                  color: '#14B8A6',
                  budgetEnabled: false,
                ),
                const Category(
                  id: 'custom-coffee',
                  userId: 'user',
                  name: 'Coffee',
                  type: CategoryType.expense,
                  group: CategoryBudgetGroup.wants,
                  icon: 'coffee',
                  color: '#8B5CF6',
                  budgetEnabled: true,
                ),
              ]),
            ),
            categoryGroupsProvider.overrideWith(
              () => _GroupsNotifier(const []),
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
      expect(find.text('System'), findsOneWidget);
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
    },
  );

  testWidgets('user-defined groups section categories by group on the screen', (
    tester,
  ) async {
    final groups = [
      const CategoryGroup(
        id: 'group-household',
        userId: 'user',
        name: 'Household',
        icon: 'home',
        color: '#0EA5E9',
        sortOrder: 0,
      ),
      const CategoryGroup(
        id: 'group-side',
        userId: 'user',
        name: 'Side Income',
        icon: 'work',
        color: '#7C3AED',
        sortOrder: 1,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          categoriesProvider.overrideWith(
            () => _CategoriesNotifier([
              const Category(
                id: 'cat-rent',
                userId: 'user',
                name: 'Rent',
                type: CategoryType.expense,
                group: CategoryBudgetGroup.needs,
                groupId: 'group-household',
                icon: 'home',
                color: '#0EA5E9',
                budgetEnabled: true,
              ),
              const Category(
                id: 'cat-utilities',
                userId: 'user',
                name: 'Utilities',
                type: CategoryType.expense,
                group: CategoryBudgetGroup.needs,
                groupId: 'group-household',
                icon: 'utilities',
                color: '#0284C7',
                budgetEnabled: true,
              ),
              const Category(
                id: 'cat-freelance',
                userId: 'user',
                name: 'Freelance',
                type: CategoryType.income,
                group: CategoryBudgetGroup.business,
                groupId: 'group-side',
                icon: 'work',
                color: '#7C3AED',
                budgetEnabled: false,
              ),
              const Category(
                id: 'cat-loose',
                userId: 'user',
                name: 'Pet Care',
                type: CategoryType.expense,
                group: CategoryBudgetGroup.custom,
                icon: 'category',
                color: '#22C55E',
                budgetEnabled: true,
              ),
            ]),
          ),
          categoryGroupsProvider.overrideWith(() => _GroupsNotifier(groups)),
        ],
        child: MaterialApp(
          theme: AikoTheme.light(),
          home: const CategoryManagementScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Expense tab: Household (rent + utilities) and System (pet care, an
    // unfiled custom category that the System group absorbs).
    expect(find.text('Household'), findsOneWidget);
    expect(find.text('Side Income'), findsNothing);
    expect(find.text('System'), findsOneWidget);
    expect(find.text('Rent'), findsOneWidget);
    expect(find.text('Utilities'), findsOneWidget);
    expect(find.text('Pet Care'), findsOneWidget);
    expect(find.text('Freelance'), findsNothing);

    // The Household group should be the first expense group, and the System
    // group follows it.
    final householdFinder = find.text('Household');
    final systemFinder = find.text('System');
    expect(
      tester.getTopLeft(householdFinder).dy,
      lessThan(tester.getTopLeft(systemFinder).dy),
    );

    // Switch to Income tab: Side Income (freelance); the System group is empty
    // here because the income default/unfiled categories aren't seeded.
    await tester.drag(find.byType(TabBarView), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(find.text('Side Income'), findsOneWidget);
    expect(find.text('Freelance'), findsOneWidget);
    expect(find.text('Household'), findsNothing);
  });

  testWidgets('group section header can be collapsed and expanded', (
    tester,
  ) async {
    final groups = [
      const CategoryGroup(
        id: 'group-household',
        userId: 'user',
        name: 'Household',
        icon: 'home',
        color: '#0EA5E9',
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          categoriesProvider.overrideWith(
            () => _CategoriesNotifier([
              const Category(
                id: 'cat-rent',
                userId: 'user',
                name: 'Rent',
                type: CategoryType.expense,
                group: CategoryBudgetGroup.needs,
                groupId: 'group-household',
                icon: 'home',
                color: '#0EA5E9',
                budgetEnabled: true,
              ),
            ]),
          ),
          categoryGroupsProvider.overrideWith(() => _GroupsNotifier(groups)),
        ],
        child: MaterialApp(
          theme: AikoTheme.light(),
          home: const CategoryManagementScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Rent'), findsOneWidget);

    await tester.tap(find.text('Household'));
    await tester.pumpAndSettle();
    expect(find.text('Rent'), findsNothing);

    await tester.tap(find.text('Household'));
    await tester.pumpAndSettle();
    expect(find.text('Rent'), findsOneWidget);
  });

  testWidgets('default category tap does not open a popup or route', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          categoriesProvider.overrideWith(
            () => _CategoriesNotifier([
              Category(
                id: CategoryDefaults.salaryId,
                userId: 'user',
                name: 'Salary',
                type: CategoryType.income,
                group: CategoryBudgetGroup.custom,
                icon: 'salary',
                color: '#22C55E',
                budgetEnabled: false,
              ),
            ]),
          ),
          categoryGroupsProvider.overrideWith(() => _GroupsNotifier(const [])),
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
                group: CategoryBudgetGroup.wants,
                icon: 'coffee',
                color: '#8B5CF6',
                budgetEnabled: true,
              ),
            ]),
          ),
          categoryGroupsProvider.overrideWith(() => _GroupsNotifier(const [])),
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
    expect(find.byKey(const Key('category-group-picker')), findsOneWidget);
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
        group: CategoryBudgetGroup.wants,
        icon: 'coffee',
        color: '#8B5CF6',
        budgetEnabled: true,
      ),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          categoriesProvider.overrideWith(() => notifier),
          categoryGroupsProvider.overrideWith(() => _GroupsNotifier(const [])),
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
                group: CategoryBudgetGroup.wants,
                icon: 'coffee',
                color: '#8B5CF6',
                budgetEnabled: true,
              ),
            ]),
          ),
          categoryGroupsProvider.overrideWith(() => _GroupsNotifier(const [])),
        ],
        child: MaterialApp(
          theme: AikoTheme.light(),
          home: const CategoryManagementScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final itemFinder = find.byKey(const ValueKey('category-card-coffee'));

    expect(itemFinder, findsOneWidget);
    expect(
      find.descendant(of: itemFinder, matching: find.text('Coffee')),
      findsOneWidget,
    );

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
              Category(
                id: CategoryDefaults.salaryId,
                userId: 'user',
                name: 'Salary',
                type: CategoryType.income,
                group: CategoryBudgetGroup.custom,
                icon: 'salary',
                color: '#22C55E',
              ),
              const Category(
                id: 'side-hustle',
                userId: 'user',
                name: 'Side Hustle',
                type: CategoryType.income,
                group: CategoryBudgetGroup.business,
                icon: 'salary',
                color: '#14B8A6',
              ),
            ]),
          ),
          categoryGroupsProvider.overrideWith(() => _GroupsNotifier(const [])),
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

    final defaultCardFinder = find.byKey(
      ValueKey('category-card-${CategoryDefaults.salaryId}'),
    );
    final customCardFinder = find.byKey(
      const ValueKey('category-card-side-hustle'),
    );
    final defaultCard = tester.widget<Card>(defaultCardFinder);
    final customCard = tester.widget<Card>(customCardFinder);

    expect(find.text('System'), findsOneWidget);
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
        group: CategoryBudgetGroup.wants,
        icon: 'coffee',
        color: '#8B5CF6',
        budgetEnabled: true,
      ),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          categoriesProvider.overrideWith(() => notifier),
          categoryGroupsProvider.overrideWith(() => _GroupsNotifier(const [])),
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
    expect(notifier.savedCategory?.group, CategoryBudgetGroup.custom);
  });

  testWidgets('add category sheet limits type selector to income and expense', (
    tester,
  ) async {
    final notifier = _SavingCategoriesNotifier(const []);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          categoriesProvider.overrideWith(() => notifier),
          categoryGroupsProvider.overrideWith(() => _GroupsNotifier(const [])),
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
        group: CategoryBudgetGroup.custom,
      ),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          categoriesProvider.overrideWith(() => notifier),
          categoryGroupsProvider.overrideWith(() => _GroupsNotifier(const [])),
        ],
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

  testWidgets('group edit button opens the group editor sheet for that group', (
    tester,
  ) async {
    final groups = [
      const CategoryGroup(
        id: 'group-household',
        userId: 'user',
        name: 'Household',
        icon: 'home',
        color: '#0EA5E9',
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          categoriesProvider.overrideWith(
            () => _CategoriesNotifier([
              const Category(
                id: 'cat-rent',
                userId: 'user',
                name: 'Rent',
                type: CategoryType.expense,
                group: CategoryBudgetGroup.needs,
                groupId: 'group-household',
                icon: 'home',
                color: '#0EA5E9',
                budgetEnabled: true,
              ),
            ]),
          ),
          categoryGroupsProvider.overrideWith(() => _GroupsNotifier(groups)),
        ],
        child: MaterialApp(
          theme: AikoTheme.light(),
          home: const CategoryManagementScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Edit group'));
    await tester.pumpAndSettle();

    expect(find.text('Edit Group'), findsOneWidget);
    expect(find.text('Household'), findsWidgets);
  });

  testWidgets(
    'system group renders built-ins and unfiled customs, locked and expanded',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            categoriesProvider.overrideWith(
              () => _CategoriesNotifier([
                Category(
                  id: CategoryDefaults.groceriesId,
                  userId: 'user',
                  name: 'Groceries',
                  type: CategoryType.expense,
                  group: CategoryBudgetGroup.needs,
                  groupId: CategoryGroupDefaults.systemId,
                  icon: 'groceries',
                  color: '#F97316',
                ),
                const Category(
                  id: 'custom-pet',
                  userId: 'user',
                  name: 'Pet Care',
                  type: CategoryType.expense,
                  group: CategoryBudgetGroup.custom,
                  icon: 'category',
                  color: '#22C55E',
                ),
              ]),
            ),
            categoryGroupsProvider.overrideWith(
              () => _GroupsNotifier(const []),
            ),
          ],
          child: MaterialApp(
            theme: AikoTheme.light(),
            home: const CategoryManagementScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Expanded by default: both the built-in and the unfiled custom show.
      expect(find.text('System'), findsOneWidget);
      expect(find.byKey(const Key('system-group-section')), findsOneWidget);
      expect(find.text('Groceries'), findsOneWidget);
      expect(find.text('Pet Care'), findsOneWidget);

      // Locked: no edit (tune) button and no in-group add action.
      expect(find.byTooltip('Edit group'), findsNothing);
      expect(
        find.byKey(
          Key('add-category-in-group-${CategoryGroupDefaults.systemId}'),
        ),
        findsNothing,
      );

      // The built-in keeps its lock; the unfiled custom does not.
      expect(
        find.descendant(
          of: find.byKey(
            ValueKey('category-card-${CategoryDefaults.groceriesId}'),
          ),
          matching: find.byIcon(Icons.lock_outline),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('category-card-custom-pet')),
          matching: find.byIcon(Icons.lock_outline),
        ),
        findsNothing,
      );
    },
  );

  testWidgets('category editor group picker excludes the System group', (
    tester,
  ) async {
    final groups = [
      const CategoryGroup(
        id: 'group-household',
        userId: 'user',
        name: 'Household',
        icon: 'home',
        color: '#0EA5E9',
      ),
    ];

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
                group: CategoryBudgetGroup.wants,
                groupId: 'group-household',
                icon: 'coffee',
                color: '#8B5CF6',
                budgetEnabled: true,
              ),
            ]),
          ),
          categoryGroupsProvider.overrideWith(() => _GroupsNotifier(groups)),
        ],
        child: MaterialApp(
          theme: AikoTheme.light(),
          home: const CategoryManagementScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    // No System section on screen (the only category is filed under Household),
    // so any 'System' match below would have to come from the picker.
    expect(find.text('System'), findsNothing);

    await tester.tap(find.text('Coffee'));
    await tester.pumpAndSettle();

    // Open the group dropdown inside the editor sheet.
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('category-group-picker')),
        matching: find.byType(DropdownButtonFormField<String?>),
      ),
    );
    await tester.pumpAndSettle();

    // The user group is offered; the read-only System group is not.
    expect(find.text('Household'), findsWidgets);
    expect(find.text('System'), findsNothing);
  });
}

class _CategoriesNotifier extends CategoriesNotifier {
  _CategoriesNotifier(this.categories);

  final List<Category> categories;

  @override
  Future<List<Category>> build() async => categories;
}

class _GroupsNotifier extends CategoryGroupsNotifier {
  _GroupsNotifier(this.groups);

  final List<CategoryGroup> groups;

  // Mirror production: the global System group is always injected last.
  @override
  Future<List<CategoryGroup>> build() async => [
    ...groups,
    CategoryGroupDefaults.system,
  ];
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
