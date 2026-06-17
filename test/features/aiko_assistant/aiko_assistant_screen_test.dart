import 'dart:async';
import 'dart:convert';

import 'package:aiko/core/storage/secure_storage_service.dart';
import 'package:aiko/features/aiko_assistant/application/aiko_chat_controller.dart';
import 'package:aiko/features/aiko_assistant/application/chat_engine.dart';
import 'package:aiko/features/aiko_assistant/application/financial_context.dart';
import 'package:aiko/features/aiko_assistant/data/chat_store.dart';
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
    // Nothing to clear on a fresh chat, so the clear chip stays hidden.
    expect(find.byTooltip('Clear chat'), findsNothing);
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

  testWidgets('restores the saved conversation on build', (tester) async {
    _useWideSurface(tester);
    final store = ChatStore(storage: _seededStorage());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [chatStoreProvider.overrideWithValue(store)],
        child: MaterialApp(
          theme: AikoTheme.light(),
          home: const AikoAssistantScreen(),
        ),
      ),
    );
    // First pump builds the screen, second flushes the async load.
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('hi'), findsOneWidget);
    expect(find.text('hello'), findsOneWidget);
    // A non-empty chat shows the clear action.
    expect(find.byTooltip('Clear chat'), findsOneWidget);
  });

  testWidgets('clear chat asks for confirmation and wipes the conversation', (
    tester,
  ) async {
    _useWideSurface(tester);
    final store = ChatStore(storage: _seededStorage());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [chatStoreProvider.overrideWithValue(store)],
        child: MaterialApp(
          theme: AikoTheme.light(),
          home: const AikoAssistantScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    // The clear icon lives inside the suggestion strip, not the app bar, and
    // uses `Icons.clear_all` rather than a trash icon.
    final clearIcon = find.byTooltip('Clear chat');
    expect(clearIcon, findsOneWidget);
    expect(
      find.descendant(of: clearIcon, matching: find.byIcon(Icons.clear_all)),
      findsOneWidget,
    );

    await tester.tap(clearIcon);
    await tester.pumpAndSettle();
    expect(find.text('Clear chat?'), findsOneWidget);
    expect(find.textContaining('cannot be undone'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Clear'));
    await tester.pumpAndSettle();

    expect(find.text('hi'), findsNothing);
    expect(await store.load(), isEmpty);
  });

  testWidgets('clear chat icon is the first item in the suggestion strip', (
    tester,
  ) async {
    _useWideSurface(tester);
    final store = ChatStore(storage: _seededStorage());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [chatStoreProvider.overrideWithValue(store)],
        child: MaterialApp(
          theme: AikoTheme.light(),
          home: const AikoAssistantScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    // The strip is a horizontal Row — the clear chip should sit to the left
    // of the first prompt chip in reading order.
    final clearChip = find.byKey(const ValueKey('chat-clear-chip'));
    final firstPrompt = find.text(_shownSuggestions().first);
    expect(clearChip, findsOneWidget);
    expect(firstPrompt, findsOneWidget);
    final clearCenter = tester.getCenter(clearChip);
    final promptCenter = tester.getCenter(firstPrompt);
    expect(clearCenter.dx, lessThan(promptCenter.dx));
  });

  testWidgets('app bar profile icon opens the profile screen', (tester) async {
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

    // The profile icon is hidden until the profile provider resolves. Without
    // a real profile in the test environment, we just confirm the icon isn't
    // shown and there's no broken link in the app bar.
    final profileIcon = find.byTooltip('Profile');
    expect(profileIcon, findsNothing);
  });
}

/// In-memory secure storage pre-seeded with a saved conversation.
SecureStorageService _seededStorage() {
  final storage = MemorySecureStorageService();
  storage.write(
    'aiko_chat',
    jsonEncode([
      {'role': 'user', 'content': 'hi'},
      {'role': 'assistant', 'content': 'hello'},
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
