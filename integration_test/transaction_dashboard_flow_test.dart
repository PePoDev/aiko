import 'package:flutter_test/flutter_test.dart';

import 'app_test_bootstrap.dart';

void main() {
  testWidgets('home quick add opens transactions', (tester) async {
    await tester.pumpWidget(buildIntegrationTestApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    for (var index = 0; index < 5; index++) {
      await tester.tap(find.text(index == 4 ? 'Open Aiko' : 'Continue'));
      await tester.pumpAndSettle();
    }

    expect(find.text('Home'), findsOneWidget);
    await tester.tap(find.text('Quick add'));
    await tester.pumpAndSettle();
    expect(find.text('Transactions'), findsOneWidget);
  });
}
