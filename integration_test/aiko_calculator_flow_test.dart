import 'package:flutter_test/flutter_test.dart';

import 'app_test_bootstrap.dart';

void main() {
  testWidgets('Aiko tab opens calculator library', (tester) async {
    await tester.pumpWidget(buildIntegrationTestApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    for (var index = 0; index < 5; index++) {
      await tester.tap(find.text(index == 4 ? 'Open Aiko' : 'Continue'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Aiko'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open calculators'));
    await tester.pumpAndSettle();

    expect(find.text('Calculators'), findsOneWidget);
    expect(find.text('Compound interest'), findsOneWidget);
  });
}
