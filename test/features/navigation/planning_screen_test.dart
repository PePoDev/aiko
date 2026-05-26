import 'package:aiko/features/navigation/presentation/planning_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('planning screen groups planning and finance workspaces', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 1400);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: PlanningScreen()));

    await tester.pumpAndSettle();

    expect(find.text('Planning'), findsOneWidget);
    expect(
      find.text(
        'Keep budgets, goals, accounts, debt, assets, taxes, and investments in one place.',
      ),
      findsNothing,
    );
    for (final label in [
      'Budget',
      'Goals',
      'Recurring Transactions',
      'Debt and Loans',
      'Credit Cards',
      'Accounts',
      'Categories',
      'Assets',
      'Tax Center',
      'Accounting',
      'Portfolio',
      'Travel Mode',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
  });
}
