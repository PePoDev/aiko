import 'package:aiko/app/providers.dart';
import 'package:aiko/features/aiko_assistant/presentation/aiko_assistant_screen.dart';
import 'package:aiko/features/aiko_character/presentation/aiko_character.dart';
import 'package:aiko/features/settings/domain/profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('empty assistant stage wires the thinking Aiko character', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profileProvider.overrideWith(
              (ref) async => const Profile(
                id: 'profile-id',
                displayName: 'Aiko user',
                email: 'user@example.com',
                baseCurrency: 'USD',
                country: 'US',
                securityStatus: SecurityStatus.notConfigured,
              ),
            ),
          ],
          child: const MaterialApp(home: AikoAssistantScreen()),
        ),
      );
      await tester.pump();

      final stageCharacter = find.byWidgetPredicate(
        (widget) =>
            widget is AikoCharacter &&
            widget.key == const ValueKey('aiko-stage-character'),
      );
      expect(stageCharacter, findsOneWidget);

      final character = tester.widget<AikoCharacter>(stageCharacter);
      expect(character.mood, AikoMood.thinking);
      expect(character.semanticLabel, 'Aiko is thinking');
      expect(character.size, 220);
      expect(tester.getSize(stageCharacter), const Size.square(220));
      expect(find.bySemanticsLabel('Aiko is thinking'), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });
}
