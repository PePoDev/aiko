import 'package:aiko/features/calculators/presentation/calculator_detail_screen.dart';
import 'package:aiko/features/calculators/presentation/calculator_library_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildScreen() {
    return const MaterialApp(home: CalculatorLibraryScreen());
  }

  testWidgets('calculator cards open without repeated open buttons', (
    tester,
  ) async {
    await tester.pumpWidget(buildScreen());

    expect(find.text('Open'), findsNothing);
    expect(find.byType(GridView), findsOneWidget);

    await tester.tap(find.text('Loan'));
    await tester.pumpAndSettle();

    expect(find.byType(CalculatorDetailScreen), findsOneWidget);
    expect(find.text('Loan payment'), findsOneWidget);
  });

  testWidgets('search filters calculator cards', (tester) async {
    await tester.pumpWidget(buildScreen());

    await tester.enterText(find.byType(TextField), 'mortgage');
    await tester.pump();

    expect(find.text('Bi-weekly mortgage payment'), findsOneWidget);
    expect(find.text('Compound interest'), findsNothing);
  });
}
