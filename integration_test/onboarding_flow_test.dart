import 'package:flutter_test/flutter_test.dart';

import 'app_test_bootstrap.dart';

void main() {
  testWidgets('first launch can reach onboarding', (tester) async {
    await bootstrapIntegrationTest(tester);
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome to Aiko'), findsOneWidget);
  });
}
