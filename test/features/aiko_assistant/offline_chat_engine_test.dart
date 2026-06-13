import 'package:aiko/features/aiko_assistant/application/aiko_assistant_service.dart';
import 'package:aiko/features/aiko_assistant/application/chat_engine.dart';
import 'package:aiko/features/aiko_assistant/domain/aiko_response.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OfflineChatEngine', () {
    test('emits a Delta and Done with the canned service answer', () async {
      const engine = OfflineChatEngine();
      final events = await engine
          .streamReply(
            history: const [ChatMessage(role: 'user', content: 'hello')],
          )
          .toList();

      expect(events.whereType<ChatReplyDelta>(), isNotEmpty);
      expect(
        events.whereType<ChatReplyDelta>().first.delta,
        contains('safe-to-spend'),
      );
      expect(events.whereType<ChatReplyDone>(), hasLength(1));
    });

    test('emits an Error when the service throws', () async {
      final engine = OfflineChatEngine(service: _ThrowingService());
      final events = await engine
          .streamReply(
            history: const [ChatMessage(role: 'user', content: 'x')],
          )
          .toList();

      expect(events.whereType<ChatReplyError>(), hasLength(1));
    });
  });
}

class _ThrowingService extends AikoAssistantService {
  const _ThrowingService();

  @override
  AikoResponse answerQuestion({
    required String question,
    bool aiConsentEnabled = true,
    dynamic safeToSpendAmount,
    dynamic insights = const [],
    dynamic accounts = const [],
    dynamic budgets = const [],
    dynamic goals = const [],
    dynamic transactions = const [],
  }) {
    throw StateError('boom');
  }
}
