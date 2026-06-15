import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';

void main() {
  testWidgets('router starts on welcome and can show login entry', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    expect(find.text('Aiko'), findsWidgets);
    expect(find.text('Get Started'), findsOneWidget);
  });
}
