import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_test_bootstrap.dart';

void main() {
  testWidgets('insights tab shows review entry', (tester) async {
    await bootstrapIntegrationTest(tester);
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    for (var index = 0; index < 5; index++) {
      await tester.tap(
        find.text(index == 4 ? 'Continue to sign in' : 'Continue'),
      );
      await tester.pumpAndSettle();
    }
    await tester.enterText(find.byType(TextField).at(0), integrationTestEmail);
    await tester.enterText(
      find.byType(TextField).at(1),
      integrationTestPassword,
    );
    await tester.tap(find.text('Continue securely'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Insights'));
    await tester.pumpAndSettle();

    expect(find.text('Aiko Review'), findsOneWidget);
  }, skip: !hasSupabaseIntegrationConfig);
}
