import 'dart:async';

import 'package:aiko/app/providers.dart';
import 'package:aiko/features/aiko_assistant/application/aiko_chat_controller.dart';
import 'package:aiko/features/aiko_assistant/application/chat_engine.dart';
import 'package:aiko/features/aiko_assistant/presentation/aiko_assistant_screen.dart';
import 'package:aiko/features/settings/domain/profile.dart';
import 'package:aiko/theme/aiko_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows greeting, suggestion chips, and input on first build', (
    tester,
  ) async {
    _useWideSurface(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileProvider.overrideWith(_profileWith(aiConsent: true)),
        ],
        child: MaterialApp(
          theme: AikoTheme.light(),
          home: const AikoAssistantScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Aiko'), findsOneWidget);
    expect(find.textContaining("I'm Aiko"), findsOneWidget);
    expect(find.text('How much can I safely spend?'), findsOneWidget);
    expect(find.text('Am I on track for my goals?'), findsOneWidget);
    expect(find.text('Where can I cut back?'), findsOneWidget);
    expect(find.text('Give me a quick money check-up.'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Ask about your money...'), findsOneWidget);
  });

  testWidgets(
    'hides suggestion chips and shows consent notice when AI is off',
    (tester) async {
      _useWideSurface(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profileProvider.overrideWith(_profileWith(aiConsent: false)),
          ],
          child: MaterialApp(
            theme: AikoTheme.light(),
            home: const AikoAssistantScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Offline mode'), findsOneWidget);
      expect(find.text('How much can I safely spend?'), findsNothing);
      expect(find.textContaining('AI features are off'), findsOneWidget);
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.enabled, isFalse);
    },
  );

  testWidgets('tapping a suggestion sends it and shows it in the list', (
    tester,
  ) async {
    _useWideSurface(tester);
    final fakeEngine = _RecordingEngine();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileProvider.overrideWith(_profileWith(aiConsent: true)),
          aikoChatEngineProvider.overrideWithValue(fakeEngine),
        ],
        child: MaterialApp(
          theme: AikoTheme.light(),
          home: const AikoAssistantScreen(),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Where can I cut back?'));
    await tester.pump();

    expect(fakeEngine.calls, hasLength(1));
    expect(fakeEngine.calls.single.last.content, 'Where can I cut back?');
    expect(find.text('Where can I cut back?'), findsWidgets);
  });
}

void _useWideSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<Profile> Function(Ref) _profileWith({required bool aiConsent}) {
  return (ref) async => Profile(
    id: 'test-user',
    displayName: 'Tester',
    email: 'tester@example.com',
    baseCurrency: 'USD',
    country: 'US',
    aiConsentEnabled: aiConsent,
    onboardingStatus: OnboardingStatus.completed,
    securityStatus: SecurityStatus.notConfigured,
  );
}

class _RecordingEngine implements ChatEngine {
  final List<List<ChatMessage>> calls = [];

  @override
  Stream<ChatReplyEvent> streamReply({required List<ChatMessage> history}) {
    calls.add(history);
    final controller = StreamController<ChatReplyEvent>();
    scheduleMicrotask(() {
      controller.add(const ChatReplyDelta('Aiko here.'));
      controller.add(const ChatReplyDone('Aiko here.'));
      controller.close();
    });
    return controller.stream;
  }
}
