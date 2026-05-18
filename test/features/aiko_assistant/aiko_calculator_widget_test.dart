import 'package:aiko/features/aiko_assistant/presentation/aiko_assistant_screen.dart';
import 'package:aiko/theme/aiko_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Aiko assistant shows prompt and calculator entry', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: AikoTheme.light(), home: const AikoAssistantScreen()),
    );

    expect(find.text('Ask Aiko'), findsOneWidget);
    expect(find.text('Open calculators'), findsOneWidget);
  });
}
