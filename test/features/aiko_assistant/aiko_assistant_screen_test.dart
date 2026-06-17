import 'dart:async';

import 'package:aiko/features/aiko_assistant/application/aiko_chat_controller.dart';
import 'package:aiko/features/aiko_assistant/application/chat_engine.dart';
import 'package:aiko/features/aiko_assistant/application/financial_context.dart';
import 'package:aiko/features/aiko_assistant/domain/aiko_prompt_suggestions.dart';
import 'package:aiko/features/aiko_assistant/presentation/aiko_assistant_screen.dart';
import 'package:aiko/theme/aiko_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows greeting bubble, suggestion chips, and input on build', (
    tester,
  ) async {
    _useWideSurface(tester);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AikoTheme.light(),
          home: const AikoAssistantScreen(),
        ),
      ),
    );
    await tester.pump();

    // The empty state shows the greeting as a thinking bubble above the
    // large Aiko character.
    expect(find.textContaining("I'm Aiko"), findsOneWidget);
    expect(find.byKey(const ValueKey('aiko-stage-character')), findsOneWidget);
    // The empty state shows a random subset of the prompt pool, so assert the
    // count and pool membership rather than specific prompts.
    final shown = _shownSuggestions();
    expect(shown, hasLength(AikoPromptSuggestions.count));
    expect(shown.every(AikoPromptSuggestions.all.contains), isTrue);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Ask about your money...'), findsOneWidget);
  });

  testWidgets(
    'without Supabase configured, shows on-device mode and keeps input usable',
    (tester) async {
      _useWideSurface(tester);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AikoTheme.light(),
            home: const AikoAssistantScreen(),
          ),
        ),
      );
      await tester.pump();

      // SUPABASE_URL is unset in tests, so the screen is in on-device mode.
      expect(find.textContaining('On-device mode'), findsWidgets);
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.enabled, isTrue);
    },
  );

  testWidgets('tapping a suggestion sends it and shows it in the list', (
    tester,
  ) async {
    _useWideSurface(tester);
    final fakeEngine = _RecordingEngine();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [aikoChatEngineProvider.overrideWithValue(fakeEngine)],
        child: MaterialApp(
          theme: AikoTheme.light(),
          home: const AikoAssistantScreen(),
        ),
      ),
    );
    await tester.pump();

    final prompt = _shownSuggestions().first;
    // Chips sit in a horizontal scroll view, so the pick may be off-screen.
    // The stage character floats continuously, so pumpAndSettle would hang;
    // a single pump is enough to lay the chips out before tapping.
    await tester.ensureVisible(find.text(prompt));
    await tester.pump();
    await tester.tap(find.text(prompt));
    await tester.pump();

    expect(fakeEngine.calls, hasLength(1));
    expect(fakeEngine.calls.single.last.content, prompt);
    expect(find.text(prompt), findsWidgets);
  });

  testWidgets('hides the Aiko character once a message is sent', (
    tester,
  ) async {
    _useWideSurface(tester);
    final fakeEngine = _RecordingEngine();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [aikoChatEngineProvider.overrideWithValue(fakeEngine)],
        child: MaterialApp(
          theme: AikoTheme.light(),
          home: const AikoAssistantScreen(),
        ),
      ),
    );
    await tester.pump();

    // The stage character is visible before any user turn.
    expect(find.byKey(const ValueKey('aiko-stage-character')), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'How much can I spend?');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump();

    // After sending, the stage is replaced by the chat transcript.
    expect(find.byKey(const ValueKey('aiko-stage-character')), findsNothing);
    expect(find.text('How much can I spend?'), findsOneWidget);
  });

  testWidgets('drops the empty-state greeting from the transcript on first send', (
    tester,
  ) async {
    _useWideSurface(tester);
    final fakeEngine = _RecordingEngine();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [aikoChatEngineProvider.overrideWithValue(fakeEngine)],
        child: MaterialApp(
          theme: AikoTheme.light(),
          home: const AikoAssistantScreen(),
        ),
      ),
    );
    await tester.pump();

    // Greeting is rendered as the empty-state thinking bubble.
    expect(find.textContaining("I'm Aiko"), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'How am I doing?');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump();

    // The greeting belonged to the stage, not the transcript; once a real
    // message is sent it should not reappear as a chat bubble.
    expect(find.textContaining("I'm Aiko"), findsNothing);
    expect(find.text('How am I doing?'), findsOneWidget);
  });

  testWidgets('app bar exposes profile title and settings action', (
    tester,
  ) async {
    _useWideSurface(tester);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AikoTheme.light(),
          home: const AikoAssistantScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byTooltip('Profile'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('chat-notifications-icon')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('chat-settings-icon')), findsOneWidget);
    // The clear action is gone — chat sessions are no longer saved.
    expect(find.byTooltip('Clear chat'), findsNothing);
  });
}

/// The prompt pool members currently rendered as suggestion chips.
List<String> _shownSuggestions() => AikoPromptSuggestions.all
    .where((p) => find.text(p).evaluate().isNotEmpty)
    .toList();

void _useWideSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

class _RecordingEngine implements ChatEngine {
  final List<List<ChatMessage>> calls = [];

  @override
  Stream<ChatReplyEvent> streamReply({
    required List<ChatMessage> history,
    AikoFinancialContext? context,
  }) {
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
