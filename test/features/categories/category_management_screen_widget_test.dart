import 'package:aiko/app/providers.dart';
import 'package:aiko/core/money/money.dart';
import 'package:aiko/features/categories/domain/category.dart';
import 'package:aiko/features/categories/domain/category_defaults.dart';
import 'package:aiko/features/categories/presentation/category_management_screen.dart';
import 'package:aiko/theme/aiko_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  _defaultsInvariantsTests();
  _budgetPillTests();

  testWidgets('shows Income and Expense sections together with Expense first', (
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
          categoryGroupsProvider.overrideWith(() => _GroupsNotifier(const [])),
        ],
        child: MaterialApp(
          theme: AikoTheme.light(),
          home: const CategoryManagementScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // No more tabs; both section headers are visible.
    expect(find.byType(TabBar), findsNothing);
    expect(find.byType(TabBarView), findsNothing);

    // Expense appears before Income on the same scroll.
    final incomeHeader = find.descendant(
      of: find.byKey(const ValueKey('section-income')),
      matching: find.text('Income'),
    );
    final expenseHeader = find.descendant(
      of: find.byKey(const ValueKey('section-expense')),
      matching: find.text('Expense'),
    );
    expect(incomeHeader, findsOneWidget);
    expect(expenseHeader, findsOneWidget);
    expect(
      tester.getTopLeft(expenseHeader).dy,
      lessThan(tester.getTopLeft(incomeHeader).dy),
    );

    // Groups are collapsed by default; expand both "Other" groups (expense
    // first in the list, then income) to reveal the seeded categories.
    await tester.tap(find.text('Other').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Other').last);
    await tester.pumpAndSettle();

    // All seeded categories are visible (no tab isolation).
    expect(find.text('Salary'), findsOneWidget);
    expect(find.text('Side Hustle'), findsOneWidget);
    expect(find.text('Groceries'), findsOneWidget);
    expect(find.text('Coffee'), findsOneWidget);

    expect(find.byTooltip('Add'), findsOneWidget);
    expect(find.byTooltip('About categories'), findsNothing);
    expect(find.byIcon(Icons.info_outline), findsNothing);
  });

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

    // Headers render collapsed: Expense section first (Household, Other), then
    // the Income section (Side Income). Expense sits above Income.
    expect(find.text('Side Income'), findsOneWidget);
    expect(find.text('Household'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Household')).dy,
      lessThan(tester.getTopLeft(find.text('Side Income')).dy),
    );

    // Expand each group to reveal its categories.
    await tester.tap(find.text('Side Income'));
    await tester.pumpAndSettle();
    expect(find.text('Freelance'), findsOneWidget);

    await tester.tap(find.text('Household'));
    await tester.pumpAndSettle();
    expect(find.text('Rent'), findsOneWidget);
    expect(find.text('Utilities'), findsOneWidget);

    // The 13 default groups are appended after the user's; "Other" holds the
    // unfiled custom (Pet Care). Scroll it into view, then expand.
    await tester.scrollUntilVisible(find.text('Other'), 180);
    await tester.tap(find.text('Other'));
    await tester.pumpAndSettle();
    expect(find.text('Pet Care'), findsOneWidget);
  });

  testWidgets('groups are collapsed by default and toggle on header tap', (
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

    // Collapsed by default: the category row is hidden on load.
    expect(find.text('Rent'), findsNothing);

    // Tapping the group header expands it, revealing the category rows.
    await tester.tap(find.text('Household'));
    await tester.pumpAndSettle();
    expect(find.text('Rent'), findsOneWidget);

    // Tapping again collapses it.
    await tester.tap(find.text('Household'));
    await tester.pumpAndSettle();
    expect(find.text('Rent'), findsNothing);

    // Editing the group happens via the tune action, not the header tap.
    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();
    expect(find.text('Edit Group'), findsOneWidget);
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
    // Expand the (unfiled) "Other" group, then tap the default category.
    await tester.tap(find.text('Other'));
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
    await tester.tap(find.text('Other'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Coffee'));
    await tester.pumpAndSettle();

    expect(find.text('Category details'), findsNothing);
    expect(find.text('Edit Category'), findsOneWidget);
    expect(find.text('Coffee'), findsWidgets);
    expect(find.text('Expense'), findsWidgets);
    expect(find.text('Wants'), findsNothing);
    expect(find.text('Category Group (50/30/20 Rule)'), findsNothing);
    // The category form owns the optional budget fields (CLAUDE.md).
    expect(find.text('Budget'), findsWidgets);
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
    await tester.tap(find.text('Other'));
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
    await tester.tap(find.text('Other'));
    await tester.pumpAndSettle();

    final itemFinder = find.byKey(const ValueKey('category-row-coffee'));

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
    // Both income cards live in the unfiled "Other" group; expand it.
    await tester.tap(find.text('Other'));
    await tester.pumpAndSettle();

    final defaultRowFinder = find.byKey(
      ValueKey('category-row-${CategoryDefaults.salaryId}'),
    );
    final customRowFinder = find.byKey(
      const ValueKey('category-row-side-hustle'),
    );

    expect(find.text('Other'), findsOneWidget);
    expect(
      find.descendant(
        of: defaultRowFinder,
        matching: find.byIcon(Icons.lock_outline),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: customRowFinder,
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
    await tester.tap(find.byTooltip('Add'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New category'));
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
    await tester.tap(find.byTooltip('Add'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New category'));
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

  testWidgets('app-bar Add category defaults the new category to expense', (
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
    // The app-bar "+" opens a menu with "New category" and "New group".
    // Picking "New category" defaults the sheet to expense.
    await tester.tap(find.byTooltip('Add'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New category'));
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

    expect(notifier.savedCategory?.type, CategoryType.expense);
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
    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();

    expect(find.text('Edit Group'), findsOneWidget);
    expect(find.text('Household'), findsWidgets);
  });

  testWidgets(
    'Other group renders built-ins and unfiled customs, locked and expanded',
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
                  groupId: CategoryGroupDefaults.unfiledGroupId,
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

      // The unfiled "Other" group holds both the built-in and the unfiled
      // custom. The group is locked (no tune affordance for system groups).
      expect(find.text('Other'), findsOneWidget);
      expect(find.byIcon(Icons.tune), findsNothing);

      // Expand it to reveal both rows.
      await tester.tap(find.text('Other'));
      await tester.pumpAndSettle();
      expect(find.text('Groceries'), findsOneWidget);
      expect(find.text('Pet Care'), findsOneWidget);

      // The built-in keeps its lock; the unfiled custom does not.
      expect(
        find.descendant(
          of: find.byKey(
            ValueKey('category-row-${CategoryDefaults.groceriesId}'),
          ),
          matching: find.byIcon(Icons.lock_outline),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('category-row-custom-pet')),
          matching: find.byIcon(Icons.lock_outline),
        ),
        findsNothing,
      );
    },
  );

  testWidgets('category editor group picker offers user and default groups', (
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
    // The only category is filed under Household, so no Other section renders.
    // The 'Other' match below would have to come from the picker.
    expect(find.text('Other'), findsNothing);

    // Expand the group to reach the category, then open its editor.
    await tester.tap(find.text('Household'));
    await tester.pumpAndSettle();
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

    // Both the user group AND the default groups are offerable as targets
    // (Decision D4). skipOffstage: false so the assertion holds even when
    // the long dropdown list scrolls items off the test viewport.
    expect(find.text('Household'), findsWidgets);
    expect(find.text('Other', skipOffstage: false), findsWidgets);
  });
}

void _budgetPillTests() {
  testWidgets('row shows spent/limit when budgeted, + Budget chip when not', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          categoriesProvider.overrideWith(
            () => _CategoriesNotifier([
              Category(
                id: 'cat-budgeted',
                userId: 'user',
                name: 'Dining',
                type: CategoryType.expense,
                group: CategoryBudgetGroup.wants,
                icon: 'food',
                color: '#F97316',
                budgetEnabled: true,
                monthlyLimit: Money.parse('1000', 'USD'),
              ),
              const Category(
                id: 'cat-nobudget',
                userId: 'user',
                name: 'Misc',
                type: CategoryType.expense,
                group: CategoryBudgetGroup.wants,
                icon: 'category',
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

    // Both categories are unfiled, so they land in the "Other" group. Expand it.
    await tester.tap(find.text('Other'));
    await tester.pumpAndSettle();

    // Budgeted row: trailing total carries a slash (spent/limit), no add chip.
    final budgeted = tester.widget<Text>(
      find.byKey(const ValueKey('category-cat-budgeted-total')),
    );
    expect(budgeted.data, contains('/'));
    expect(
      find.byKey(const ValueKey('category-cat-budgeted-add-budget')),
      findsNothing,
    );

    // No-budget row exposes the + Budget affordance.
    expect(
      find.byKey(const ValueKey('category-cat-nobudget-add-budget')),
      findsOneWidget,
    );
  });

  testWidgets(
    'group header shows + Budget chip without a limit and a progress bar with one',
    (tester) async {
      // A custom expense group with a group-level limit, plus the unfiled
      // built-in "Other" group which has none.
      final groups = [
        CategoryGroup(
          id: 'group-food',
          userId: 'user',
          name: 'Food',
          icon: 'food',
          color: '#F97316',
          budgetLimit: Money.parse('600', 'USD'),
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            categoriesProvider.overrideWith(
              () => _CategoriesNotifier([
                const Category(
                  id: 'cat-groceries',
                  userId: 'user',
                  name: 'Groceries',
                  type: CategoryType.expense,
                  group: CategoryBudgetGroup.needs,
                  groupId: 'group-food',
                  icon: 'food',
                  color: '#F97316',
                  budgetEnabled: true,
                ),
                const Category(
                  id: 'cat-loose',
                  userId: 'user',
                  name: 'Misc',
                  type: CategoryType.expense,
                  group: CategoryBudgetGroup.custom,
                  icon: 'category',
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

      // The budgeted group renders an animated progress bar, no + Budget chip.
      expect(
        find.byKey(const ValueKey('group-budget-progress')),
        findsOneWidget,
      );
      // The unfiled "Other" group has no group limit: it offers + Budget.
      expect(find.byKey(const ValueKey('group-add-budget')), findsOneWidget);
    },
  );

  testWidgets(
    'default group shows its saved budget overlay (regression for "+ Budget" '
    'not reflecting after save)',
    (tester) async {
      // The provider's merged output for a default group carrying a per-user
      // budget overlay — exactly what CategoryGroupsNotifier._merge produces
      // after saveGroup() on a default group. The screen must use this list
      // directly instead of re-appending raw CategoryGroupDefaults.all, which
      // would discard the overlay.
      final mergedGroups = CategoryGroupDefaults.all
          .map(
            (group) => group.id == CategoryGroupDefaults.foodAndDrinkId
                ? group.copyWith(budgetLimit: Money.parse('500', 'USD'))
                : group,
          )
          .toList(growable: false);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            categoriesProvider.overrideWith(
              () => _CategoriesNotifier([
                const Category(
                  id: 'cat-groceries',
                  userId: 'user',
                  name: 'Groceries',
                  type: CategoryType.expense,
                  group: CategoryBudgetGroup.needs,
                  groupId: CategoryGroupDefaults.foodAndDrinkId,
                  icon: 'food',
                  color: '#F97316',
                  budgetEnabled: true,
                ),
              ]),
            ),
            categoryGroupsProvider.overrideWith(
              () => _RawGroupsNotifier(mergedGroups),
            ),
          ],
          child: MaterialApp(
            theme: AikoTheme.light(),
            home: const CategoryManagementScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The Food & Drink default group carries a budget overlay: it must
      // render the spent/limit text and the animated progress bar, and must
      // NOT render the "+ Budget" add chip.
      expect(find.text('Food & Drink'), findsOneWidget);
      expect(find.byKey(const ValueKey('group-total-amount')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('group-budget-progress')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('group-add-budget')), findsNothing);
    },
  );
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

  // Mirror production: the 13 default groups are always injected after the
  // user's own groups, in their declared display order.
  @override
  Future<List<CategoryGroup>> build() async => [
    ...groups,
    ...CategoryGroupDefaults.all,
  ];
}

/// Returns its list verbatim — simulates the production notifier's *merged*
/// output (user groups + default groups with per-user budget overlays folded
/// in). Used by regression tests that need a default group to carry a budget.
class _RawGroupsNotifier extends CategoryGroupsNotifier {
  _RawGroupsNotifier(this.groups);

  final List<CategoryGroup> groups;

  @override
  Future<List<CategoryGroup>> build() async => groups;
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

void _defaultsInvariantsTests() {
  test('every default category points at a known default group', () {
    for (final category in CategoryDefaults.all) {
      expect(
        CategoryGroupDefaults.systemIds,
        contains(category.groupId),
        reason:
            'Category ${category.id} (${category.name}) has groupId '
            '${category.groupId} which is not in CategoryGroupDefaults.systemIds',
      );
    }
  });

  test('CategoryGroupDefaults.all covers every default group exactly once', () {
    expect(
      CategoryGroupDefaults.all.map((g) => g.id).toSet(),
      CategoryGroupDefaults.systemIds,
    );
  });

  test('unfiledGroupId is the renamed "Other" group', () {
    final unfiled = CategoryGroupDefaults.all.firstWhere(
      (g) => g.id == CategoryGroupDefaults.unfiledGroupId,
    );
    expect(unfiled.name, 'Other');
  });

  test('systemIds is exactly 13', () {
    expect(CategoryGroupDefaults.systemIds.length, 13);
  });

  test('CategoryDefaults.allIds has the expected count', () {
    // 11 income + 70 expense = 81.
    expect(CategoryDefaults.allIds.length, 81);
  });
}
