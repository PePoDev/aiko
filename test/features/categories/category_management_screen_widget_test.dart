import 'package:aiko/app/providers.dart';
import 'package:aiko/features/categories/domain/category.dart';
import 'package:aiko/features/categories/presentation/category_management_screen.dart';
import 'package:aiko/theme/aiko_colors.dart';
import 'package:aiko/theme/aiko_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
    expect(find.text('Budget'), findsOneWidget);
    expect(find.text('Enabled'), findsOneWidget);
    expect(find.text('#8B5CF6'), findsOneWidget);
    expect(find.byIcon(Icons.coffee_outlined), findsWidgets);
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
}

class _CategoriesNotifier extends CategoriesNotifier {
  _CategoriesNotifier(this.categories);

  final List<Category> categories;

  @override
  Future<List<Category>> build() async => categories;
}
