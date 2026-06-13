import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_test_bootstrap.dart';

void main() {
  // Placeholder: the previous "insights tab shows review entry" test was
  // removed when the standalone Aiko Review screen was retired.
  testWidgets('integration bootstrap smoke test', (tester) async {
    await bootstrapIntegrationTest(tester);
    expect(find.byType(MaterialApp), findsOneWidget);
  }, skip: !hasSupabaseIntegrationConfig);
}
