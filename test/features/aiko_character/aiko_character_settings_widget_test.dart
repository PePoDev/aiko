import 'package:aiko/features/aiko_character/presentation/aiko_character_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows hide and reduce character controls', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: AikoCharacterSettingsScreen()),
    );

    expect(find.text('Full'), findsOneWidget);
    expect(find.text('Reduced'), findsOneWidget);
    expect(find.text('Hidden'), findsOneWidget);
    expect(find.text('Reduce animation'), findsOneWidget);
    expect(find.text('Serious warnings stay professional'), findsOneWidget);
  });
}
