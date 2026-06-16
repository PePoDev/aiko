import 'package:flutter_test/flutter_test.dart';

import 'package:aiko/core/storage/secure_storage_service.dart';
import 'package:aiko/features/aiko_assistant/application/chat_engine.dart';
import 'package:aiko/features/aiko_assistant/data/chat_store.dart';

void main() {
  group('ChatStore', () {
    test('round-trips the single conversation through storage', () async {
      final store = ChatStore(storage: MemorySecureStorageService());

      expect(await store.load(), isEmpty);

      await store.save(const [
        ChatMessage(role: 'user', content: 'hi'),
        ChatMessage(role: 'assistant', content: 'hello'),
      ]);

      final loaded = await store.load();
      expect(loaded, hasLength(2));
      expect(loaded.first.content, 'hi');
      expect(loaded.last.content, 'hello');
    });

    test('clear deletes the saved conversation', () async {
      final store = ChatStore(storage: MemorySecureStorageService());
      await store.save(const [ChatMessage(role: 'user', content: 'hi')]);

      await store.clear();

      expect(await store.load(), isEmpty);
    });
  });
}
