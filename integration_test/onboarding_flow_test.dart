import 'package:flutter_test/flutter_test.dart';

import 'app_test_bootstrap.dart';

void main() {
  testWidgets('first launch shows the welcome screen', (tester) async {
    await bootstrapIntegrationTest(tester);

    expect(find.textContaining("Hi, I'm Aiko!"), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
  });
}
