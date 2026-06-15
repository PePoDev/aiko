import 'package:flutter_test/flutter_test.dart';

import 'package:aiko/core/storage/secure_storage_service.dart';
import 'package:aiko/features/aiko_assistant/application/chat_engine.dart';
import 'package:aiko/features/aiko_assistant/data/chat_session_store.dart';
import 'package:aiko/features/aiko_assistant/domain/chat_session.dart';

ChatSession _session(
  String id, {
  bool pinned = false,
  int updatedMinutesAgo = 0,
  List<ChatMessage>? messages,
}) {
  final now = DateTime(2026, 6, 15, 12);
  return ChatSession(
    id: id,
    title: id,
    createdAt: now,
    updatedAt: now.subtract(Duration(minutes: updatedMinutesAgo)),
    pinned: pinned,
    messages:
        messages ??
        const [
          ChatMessage(role: 'user', content: 'hi'),
          ChatMessage(role: 'assistant', content: 'hello'),
        ],
  );
}

void main() {
  group('ChatSession.titleFrom', () {
    test('uses the first user message, truncated', () {
      final title = ChatSession.titleFrom(const [
        ChatMessage(role: 'assistant', content: 'greeting'),
        ChatMessage(role: 'user', content: '  How much   can I spend?  '),
      ]);
      expect(title, 'How much can I spend?');
    });

    test('falls back when there is no user turn', () {
      expect(
        ChatSession.titleFrom(const [
          ChatMessage(role: 'assistant', content: 'greeting'),
        ]),
        'New chat',
      );
    });

    test('truncates long messages with an ellipsis', () {
      final long = 'a' * 80;
      final title = ChatSession.titleFrom([
        ChatMessage(role: 'user', content: long),
      ]);
      expect(title.length, 40);
      expect(title.endsWith('…'), isTrue);
    });
  });

  group('ChatSessionRotation.prune', () {
    test('keeps at most 3 unpinned, most-recent first', () {
      final pruned = ChatSessionRotation.prune([
        _session('a', updatedMinutesAgo: 40),
        _session('b', updatedMinutesAgo: 10),
        _session('c', updatedMinutesAgo: 30),
        _session('d', updatedMinutesAgo: 20),
      ]);
      expect(pruned.map((s) => s.id), ['b', 'd', 'c']);
    });

    test('pinned sessions are exempt from the window', () {
      final pruned = ChatSessionRotation.prune([
        _session('pin', pinned: true, updatedMinutesAgo: 100),
        _session('a', updatedMinutesAgo: 40),
        _session('b', updatedMinutesAgo: 30),
        _session('c', updatedMinutesAgo: 20),
        _session('d', updatedMinutesAgo: 10),
      ]);
      expect(pruned.map((s) => s.id), containsAll(['pin', 'b', 'c', 'd']));
      expect(pruned.map((s) => s.id), isNot(contains('a')));
      expect(pruned, hasLength(4));
    });

    test('keep ids survive even when unpinned and old', () {
      final pruned = ChatSessionRotation.prune([
        _session('active', updatedMinutesAgo: 100),
        _session('a', updatedMinutesAgo: 40),
        _session('b', updatedMinutesAgo: 30),
        _session('c', updatedMinutesAgo: 20),
      ], keep: {'active'});
      expect(pruned.map((s) => s.id), contains('active'));
      expect(pruned, hasLength(4));
    });
  });

  group('ChatSessionStore', () {
    test('round-trips sessions through storage and prunes on save', () async {
      final storage = MemorySecureStorageService();
      final store = ChatSessionStore(storage: storage);

      expect(await store.load(), isEmpty);

      final saved = await store.save([
        _session('a', updatedMinutesAgo: 40),
        _session('b', updatedMinutesAgo: 30),
        _session('c', updatedMinutesAgo: 20),
        _session('d', updatedMinutesAgo: 10),
      ]);
      expect(saved, hasLength(3));

      final loaded = await store.load();
      expect(loaded.map((s) => s.id), ['d', 'c', 'b']);
      expect(loaded.first.messages, hasLength(2));
      expect(loaded.first.messages.first.content, 'hi');
    });
  });
}
