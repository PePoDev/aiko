import 'package:aiko/features/budgets/presentation/budget_overview_screen.dart';
import 'package:aiko/theme/aiko_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('budget overview shows recommendation', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: AikoTheme.light(), home: const BudgetOverviewScreen()),
    );

    expect(find.text('Aiko recommendation'), findsOneWidget);
  });
}
