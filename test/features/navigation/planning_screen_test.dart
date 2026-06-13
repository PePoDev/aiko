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
    for (final label in ['Budget', 'Goals', 'Investments', 'Travel Mode']) {
      expect(find.text(label), findsOneWidget);
    }

    // Refactored-away entries should no longer be present.
    expect(find.text('Recurring Transactions'), findsNothing);
    expect(find.text('Credit Cards'), findsNothing);
    expect(find.text('Debt and Loans'), findsNothing);
  });
}
