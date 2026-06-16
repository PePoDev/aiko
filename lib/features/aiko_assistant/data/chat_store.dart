import 'dart:convert';

import '../../../core/storage/secure_storage_service.dart';
import '../application/chat_engine.dart';

/// On-device persistence for the single Aiko conversation.
///
/// Only one chat is kept on the device. It holds the user's conversation text,
/// so it lives in secure storage (encrypted at rest) rather than a plain file.
/// Clearing is irreversible — the stored messages are deleted outright.
class ChatStore {
  ChatStore({SecureStorageService? storage})
    : _storage = storage ?? FlutterSecureStorageService();

  static const _storageKey = 'aiko_chat';

  final SecureStorageService _storage;

  Future<List<ChatMessage>> load() async {
    try {
      final raw = await _storage.read(_storageKey);
      if (raw == null || raw.isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map<String, Object?>>()
          .map(ChatMessage.fromJson)
          .toList();
    } catch (_) {
      // History is best-effort; a storage hiccup must never break the chat.
      return const [];
    }
  }

  /// Persists [messages] as the single saved conversation. Best-effort.
  Future<void> save(List<ChatMessage> messages) async {
    try {
      await _storage.write(
        _storageKey,
        jsonEncode(messages.map((m) => m.toJson()).toList()),
      );
    } catch (_) {
      // Ignore — persistence is best-effort.
    }
  }

  Future<void> clear() async {
    try {
      await _storage.delete(_storageKey);
    } catch (_) {
      // Ignore.
    }
  }
}
