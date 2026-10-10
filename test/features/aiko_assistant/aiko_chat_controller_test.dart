import 'dart:async';

import 'package:aiko/app/providers.dart';
import 'package:aiko/features/aiko_assistant/application/aiko_chat_controller.dart';
import 'package:aiko/features/aiko_assistant/application/chat_engine.dart';
import 'package:aiko/features/aiko_assistant/application/financial_context.dart';
import 'package:aiko/features/settings/data/profile_repository.dart';
import 'package:aiko/features/settings/domain/profile.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Replies with the next scripted stream for each request.
class _ScriptedEngine extends HttpChatEngine {
  _ScriptedEngine(this.replies) : super(functionUrl: 'https://example.test');

  final List<Stream<ChatReplyEvent> Function()> replies;
  final requests = <List<ChatMessage>>[];

  @override
  Stream<ChatReplyEvent> streamReply({
    required List<ChatMessage> history,
    AikoFinancialContext? context,
    String? locale,
  }) {
    requests.add(history);
    return replies.removeAt(0)();
  }
}

/// No snapshot: the chat proceeds without pre-loaded context.
class _NoProfileRepository extends ProfileRepository {
  const _NoProfileRepository();

  @override
  Future<Profile> load() async => throw StateError('no profile in tests');
}

ProviderContainer _container(_ScriptedEngine engine) {
  final container = ProviderContainer(
    overrides: [
      aikoChatOfflineProvider.overrideWithValue(false),
      aikoChatEngineProvider.overrideWithValue(engine),
      profileRepositoryProvider.overrideWithValue(const _NoProfileRepository()),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 10));

void main() {
  // currentL10n() reads the platform locale.
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a new question after a failed reply leaves no empty bubble', () async {
    final engine = _ScriptedEngine([
      () => Stream.value(const ChatReplyError(ChatFailure.unavailable)),
      () => Stream.fromIterable(const [
        ChatReplyDelta('Hello'),
        ChatReplyDone('Hello'),
      ]),
    ]);
    final container = _container(engine);
    final chat = container.read(aikoChatControllerProvider.notifier);

    chat.send('First');
    await _settle();
    expect(container.read(aikoChatControllerProvider).lastError, isNotNull);

    chat.send('Second');
    await _settle();
    final messages = container.read(aikoChatControllerProvider).messages;
    expect(messages.map((m) => '${m.role}:${m.content}'), [
      'user:First',
      'user:Second',
      'assistant:Hello',
    ]);
    expect(engine.requests.last.map((m) => m.content), ['First', 'Second']);
  });

  test('a stream that closes early stops typing and keeps the text', () async {
    final engine = _ScriptedEngine([
      () => Stream.value(const ChatReplyDelta('Partial answer')),
    ]);
    final container = _container(engine);

    container.read(aikoChatControllerProvider.notifier).send('Hi');
    await _settle();
    final state = container.read(aikoChatControllerProvider);
    expect(state.isStreaming, isFalse);
    expect(state.lastError, isNull);
    expect(state.messages.last.content, 'Partial answer');
  });

  test('a stream that closes with nothing reports a retryable error', () async {
    final engine = _ScriptedEngine([() => const Stream.empty()]);
    final container = _container(engine);

    container.read(aikoChatControllerProvider.notifier).send('Hi');
    await _settle();
    final state = container.read(aikoChatControllerProvider);
    expect(state.isStreaming, isFalse);
    expect(state.lastError?.retryable, isTrue);
  });

  test('sign-in and access errors are not retryable', () async {
    for (final failure in [ChatFailure.signInExpired, ChatFailure.forbidden]) {
      final engine = _ScriptedEngine([
        // Even if the engine says otherwise, the failure decides.
        () => Stream.value(ChatReplyError(failure)),
      ]);
      final container = _container(engine);
      container.read(aikoChatControllerProvider.notifier).send('Hi');
      await _settle();
      expect(
        container.read(aikoChatControllerProvider).lastError?.retryable,
        isFalse,
        reason: '$failure',
      );
    }
  });

  test('retryable failures follow the ChatFailure kind', () {
    expect(ChatFailure.rateLimited.isRetryable, isTrue);
    expect(ChatFailure.unavailable.isRetryable, isTrue);
    expect(ChatFailure.badResponse.isRetryable, isTrue);
    expect(ChatFailure.offline.isRetryable, isFalse);
    expect(ChatFailure.signInExpired.isRetryable, isFalse);
    expect(ChatFailure.forbidden.isRetryable, isFalse);
  });

  test('local-only mode fails without a retry', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(aikoChatControllerProvider.notifier).send('Hi');
    await _settle();
    final state = container.read(aikoChatControllerProvider);
    expect(state.offline, isTrue);
    expect(state.lastError?.retryable, isFalse);
  });
}
