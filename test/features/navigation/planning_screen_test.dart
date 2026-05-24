import 'package:aiko/features/navigation/presentation/planning_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('planning screen groups planning and finance workspaces', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: PlanningScreen()));

    await tester.pumpAndSettle();

    expect(find.text('Planning'), findsWidgets);
    expect(find.text('Budget'), findsOneWidget);
    expect(find.text('Goals'), findsOneWidget);
    expect(find.text('Recurring Transactions'), findsOneWidget);
    expect(find.text('Debt and Loans'), findsOneWidget);
    expect(find.text('Credit Cards'), findsOneWidget);
    expect(find.text('Accounts'), findsOneWidget);
    expect(find.text('Categories'), findsOneWidget);
    expect(find.text('Assets'), findsOneWidget);
    expect(find.text('Tax Center'), findsOneWidget);
    expect(find.text('Accounting'), findsOneWidget);
    expect(find.text('Portfolio'), findsOneWidget);
  });
}
