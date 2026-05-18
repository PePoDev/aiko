import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';

void main() {
  testWidgets('router starts on splash and can show onboarding entry', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    expect(find.text('Aiko'), findsWidgets);
    expect(find.text('Get started'), findsOneWidget);
  });
}
