import 'package:aiko/features/monetization/presentation/plan_matrix_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('plan matrix shows free premium and pro', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PlanMatrixScreen()));
    expect(find.text('Free'), findsOneWidget);
    expect(find.text('Premium'), findsOneWidget);
    expect(find.text('Pro'), findsOneWidget);
  });
}
