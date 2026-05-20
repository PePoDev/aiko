import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_test_bootstrap.dart';

void main() {
  testWidgets('Aiko tab opens calculator library', (tester) async {
    await bootstrapIntegrationTest(tester);
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    for (var index = 0; index < 5; index++) {
      await tester.tap(find.text(index == 4 ? 'Continue to sign in' : 'Continue'));
      await tester.pumpAndSettle();
    }
    await tester.enterText(find.byType(TextField).at(0), 'test@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'password123');
    await tester.tap(find.text('Continue securely'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Aiko'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open calculators'));
    await tester.pumpAndSettle();

    expect(find.text('Calculators'), findsOneWidget);
    expect(find.text('Compound interest'), findsOneWidget);
  });
}
