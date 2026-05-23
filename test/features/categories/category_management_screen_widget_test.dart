import 'package:aiko/app/providers.dart';
import 'package:aiko/features/categories/domain/category.dart';
import 'package:aiko/features/categories/presentation/category_management_screen.dart';
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
}

class _CategoriesNotifier extends CategoriesNotifier {
  _CategoriesNotifier(this.categories);

  final List<Category> categories;

  @override
  Future<List<Category>> build() async => categories;
}
