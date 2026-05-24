import 'package:aiko/features/navigation/presentation/planning_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'planning screen groups budget goals and recurring transactions',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: PlanningScreen()));

      await tester.pumpAndSettle();

      expect(find.text('Planning'), findsWidgets);
      expect(find.text('Budget'), findsOneWidget);
      expect(find.text('Goals'), findsOneWidget);
      expect(find.text('Recurring Transactions'), findsOneWidget);
    },
  );
}
