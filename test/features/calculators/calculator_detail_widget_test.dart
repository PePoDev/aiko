import 'package:aiko/features/calculators/presentation/calculator_detail_screen.dart';
import 'package:aiko/theme/aiko_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('calculator detail screens expose a calculate action', (
    tester,
  ) async {
    for (final title in [
      'Compound interest',
      'Loan',
      'Credit card payoff',
      'Savings goal',
      'ROI',
      'Currency converter',
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: AikoTheme.light(),
          home: CalculatorDetailScreen(title: title),
        ),
      );

      expect(find.text('Calculate'), findsOneWidget);
    }
  });

  testWidgets('loan calculator calculates a monthly payment', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AikoTheme.light(),
        home: const CalculatorDetailScreen(title: 'Loan'),
      ),
    );

    await tester.enterText(find.byType(TextField).at(0), '1200');
    await tester.enterText(find.byType(TextField).at(1), '12');
    await tester.enterText(find.byType(TextField).at(2), '12');
    await tester.tap(find.text('Calculate'));
    await tester.pump();

    expect(find.text('Monthly payment'), findsOneWidget);
    expect(find.textContaining('Estimated total paid'), findsOneWidget);
  });
}
