import 'package:aiko/features/insights/presentation/insights_screen.dart';
import 'package:aiko/theme/aiko_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('insights screen shows Aiko insight and review entry', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: AikoTheme.light(), home: const InsightsScreen()),
    );

    expect(find.text('Food spending increased'), findsOneWidget);
    expect(find.text('Aiko Review'), findsOneWidget);
  });
}
