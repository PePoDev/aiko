import 'package:aiko/features/debt_loans/presentation/debt_payoff_plan_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('debt screen shows payoff strategy areas', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: DebtPayoffPlanScreen())),
    );
    expect(find.text('Payoff strategies'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(find.text('Interest savings'), findsOneWidget);
  });
}
