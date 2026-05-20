import 'package:aiko/features/budgets/presentation/budget_overview_screen.dart';
import 'package:aiko/theme/aiko_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('budget overview shows recommendation', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
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
