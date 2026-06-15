import 'dart:async';
import 'dart:convert';

import 'package:aiko/core/storage/secure_storage_service.dart';
import 'package:aiko/features/aiko_assistant/application/aiko_chat_controller.dart';
import 'package:aiko/features/aiko_assistant/application/chat_engine.dart';
import 'package:aiko/features/aiko_assistant/application/financial_context.dart';
import 'package:aiko/features/aiko_assistant/data/chat_session_store.dart';
import 'package:aiko/features/aiko_assistant/domain/aiko_prompt_suggestions.dart';
import 'package:aiko/features/aiko_assistant/presentation/aiko_assistant_screen.dart';
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
        child: MaterialApp(
          theme: AikoTheme.light(),
          home: const AikoAssistantScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Aiko'), findsOneWidget);
    expect(find.textContaining("I'm Aiko"), findsOneWidget);
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
    await tester.ensureVisible(find.text(prompt));
    await tester.pumpAndSettle();
    await tester.tap(find.text(prompt));
    await tester.pump();

    expect(fakeEngine.calls, hasLength(1));
    expect(fakeEngine.calls.single.last.content, prompt);
    expect(find.text(prompt), findsWidgets);
  });

  testWidgets(
    'renders saved chat history under the greeting on the empty state',
    (tester) async {
      // Regression: when the empty state had saved history, the list builder
      // hardcoded the history row at index 1 but offset the message index by
      // -1, indexing `state.messages[-1]` on the greeting row and crashing
      // with `RangeError (length): Invalid value: Only valid value is 0: -1`.
      _useWideSurface(tester);
      final store = ChatSessionStore(storage: _seededStorage());
      await tester.pumpWidget(
        ProviderScope(
          overrides: [chatSessionStoreProvider.overrideWithValue(store)],
          child: MaterialApp(
            theme: AikoTheme.light(),
            home: const AikoAssistantScreen(),
          ),
        ),
      );
      // First pump builds the screen, second flushes the async session load.
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.textContaining("I'm Aiko"), findsOneWidget);
      expect(find.text('Recent chats'), findsOneWidget);
      expect(find.text('Past chat'), findsOneWidget);
    },
  );
}

/// In-memory secure storage pre-seeded with a single saved chat session so the
/// session store reports a non-empty history.
SecureStorageService _seededStorage() {
  final storage = MemorySecureStorageService();
  storage.write(
    'aiko_chat_sessions',
    jsonEncode([
      {
        'id': 'past-1',
        'title': 'Past chat',
        'createdAt': '2026-01-01T00:00:00.000Z',
        'updatedAt': '2026-01-02T00:00:00.000Z',
        'pinned': false,
        'messages': [
          {'role': 'user', 'content': 'hi'},
          {'role': 'assistant', 'content': 'hello'},
        ],
      },
    ]),
  );
  return storage;
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
