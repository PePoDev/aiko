import 'dart:async';

import 'package:aiko/features/aiko_assistant/application/aiko_chat_controller.dart';
import 'package:aiko/features/aiko_assistant/application/chat_engine.dart';
import 'package:aiko/features/aiko_assistant/application/financial_context.dart';
import 'package:aiko/features/aiko_assistant/presentation/aiko_assistant_screen.dart';
import 'package:aiko/theme/aiko_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('splitTrailingDisclaimer', () {
    test('lifts a trailing _italic_ block off the main content', () {
      final result = splitTrailingDisclaimer(
        'Here is your answer.\n\n_Estimates, not certified advice._',
      );
      expect(result.content, 'Here is your answer.');
      expect(result.disclaimer, 'Estimates, not certified advice.');
    });

    test('lifts a trailing *italic* block (asterisk marker)', () {
      final result = splitTrailingDisclaimer(
        'Some answer.\n\n*Not financial advice.*',
      );
      expect(result.content, 'Some answer.');
      expect(result.disclaimer, 'Not financial advice.');
    });

    test('returns the original text when there is no trailing italic', () {
      const text = 'Just a plain answer with no disclaimer.';
      final result = splitTrailingDisclaimer(text);
      expect(result.content, text);
      expect(result.disclaimer, isNull);
    });

    test('does not match an italic block that is not at the very end', () {
      const text = 'Answer.\n\n_Not a disclaimer_\n\nMore body.';
      final result = splitTrailingDisclaimer(text);
      expect(result.content, text);
      expect(result.disclaimer, isNull);
    });

    test('ignores an empty italic block', () {
      final result = splitTrailingDisclaimer('Body.\n\n__');
      expect(result.content, 'Body.\n\n__');
      expect(result.disclaimer, isNull);
    });

    test('trims trailing whitespace from the content', () {
      final result = splitTrailingDisclaimer('Body.   \n\n_Disclaimer._   ');
      expect(result.content, 'Body.');
      expect(result.disclaimer, 'Disclaimer.');
    });
  });

  group('Aiko chat disclaimer rendering', () {
    testWidgets(
      'shows divider + compact italic disclaimer when ChatMessage has one',
      (tester) async {
        _useWideSurface(tester);
        final state = ChatState(
          offline: true,
          messages: const [
            ChatMessage(role: 'user', content: 'How is my budget?'),
            ChatMessage(
              role: 'assistant',
              content: 'You spent on Coffee this month.',
              disclaimer: 'Estimates, not certified advice.',
            ),
          ],
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              aikoChatControllerProvider.overrideWith(
                () => _SeededController(state),
              ),
            ],
            child: MaterialApp(
              theme: AikoTheme.light(),
              home: const AikoAssistantScreen(),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Estimates, not certified advice.'), findsOneWidget);
        final disclaimerText = tester.widget<Text>(
          find.text('Estimates, not certified advice.'),
        );
        expect(disclaimerText.style?.fontStyle, FontStyle.italic);
        expect(disclaimerText.style?.fontSize, 12);

        expect(find.byType(Divider), findsOneWidget);
        final divider = tester.widget<Divider>(find.byType(Divider));
        expect(divider.thickness, 1);
      },
    );

    testWidgets('no divider when the assistant message has no disclaimer', (
      tester,
    ) async {
      _useWideSurface(tester);
      const state = ChatState(
        offline: true,
        messages: [
          ChatMessage(role: 'user', content: 'How is my budget?'),
          ChatMessage(
            role: 'assistant',
            content: 'You spent on Coffee this month.',
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            aikoChatControllerProvider.overrideWith(
              () => _SeededController(state),
            ),
          ],
          child: MaterialApp(
            theme: AikoTheme.light(),
            home: const AikoAssistantScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(Divider), findsNothing);
    });

    testWidgets(
      'end-to-end: streaming a reply with a trailing italic splits the '
      'disclaimer into a divider + compact italic line on done',
      (tester) async {
        _useWideSurface(tester);
        final engine = _DisclaimerEngine(
          delta:
              'You spent on Coffee this month.\n\n_Estimates, not certified advice._',
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [aikoChatEngineProvider.overrideWithValue(engine)],
            child: MaterialApp(
              theme: AikoTheme.light(),
              home: const AikoAssistantScreen(),
            ),
          ),
        );
        await tester.pump();

        // The screen's input bar sends on submit; trigger via the field's
        // own TextInputAction so we don't depend on which random suggestion
        // chips render.
        await tester.enterText(find.byType(TextField), 'hello');
        await tester.testTextInput.receiveAction(TextInputAction.send);
        await tester.pumpAndSettle();

        expect(find.text('Estimates, not certified advice.'), findsOneWidget);
        final disclaimerText = tester.widget<Text>(
          find.text('Estimates, not certified advice.'),
        );
        expect(disclaimerText.style?.fontStyle, FontStyle.italic);
        expect(disclaimerText.style?.fontSize, 12);
        expect(find.byType(Divider), findsOneWidget);
      },
    );
  });
}

class _SeededController extends AikoChatController {
  _SeededController(this._seeded);
  final ChatState _seeded;

  @override
  ChatState build() => _seeded;
}

void _useWideSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

class _DisclaimerEngine implements ChatEngine {
  _DisclaimerEngine({required this.delta});
  final String delta;

  @override
  Stream<ChatReplyEvent> streamReply({
    required List<ChatMessage> history,
    AikoFinancialContext? context,
  }) {
    final controller = StreamController<ChatReplyEvent>();
    scheduleMicrotask(() {
      controller.add(ChatReplyDelta(delta));
      controller.add(const ChatReplyDone(''));
      controller.close();
    });
    return controller.stream;
  }
}
