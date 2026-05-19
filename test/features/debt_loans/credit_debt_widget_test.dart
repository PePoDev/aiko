import 'package:aiko/features/credit_cards/presentation/credit_card_overview_screen.dart';
import 'package:aiko/features/debt_loans/presentation/debt_payoff_plan_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('credit card overview shows metrics areas', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: CreditCardOverviewScreen()),
    );
    expect(find.text('Utilization'), findsOneWidget);
    expect(find.text('Payment planning'), findsOneWidget);
  });

  testWidgets('debt screen shows payoff strategy areas', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: DebtPayoffPlanScreen()));
    expect(find.text('Payoff strategies'), findsOneWidget);
    expect(find.text('Interest savings'), findsOneWidget);
  });
}
