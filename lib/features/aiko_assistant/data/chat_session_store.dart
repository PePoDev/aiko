import 'dart:convert';

import '../../../core/storage/secure_storage_service.dart';
import '../domain/chat_session.dart';

/// On-device persistence for the rolling chat-session history.
///
/// Sessions hold the user's conversation text, so they live in secure storage
/// (encrypted at rest) rather than a plain file — mirroring how
/// [DashboardLayoutRepository] persists local UI state. The rolling window is
/// enforced by [ChatSessionRotation] before every write.
class ChatSessionStore {
  ChatSessionStore({SecureStorageService? storage})
    : _storage = storage ?? FlutterSecureStorageService();

  static const _storageKey = 'aiko_chat_sessions';

  final SecureStorageService _storage;

  Future<List<ChatSession>> load() async {
    try {
      final raw = await _storage.read(_storageKey);
      if (raw == null || raw.isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final sessions = decoded
          .whereType<Map<String, Object?>>()
          .map(ChatSession.fromJson)
          .toList();
      sessions.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return sessions;
    } catch (_) {
      // History is best-effort; a storage hiccup must never break the chat.
      return const [];
    }
  }

  /// Prunes [sessions] to the rolling window (keeping [keep] regardless) and
  /// persists the result, returning the trimmed list. Persistence is
  /// best-effort: if the write fails, the pruned list is still returned so the
  /// in-memory UI stays consistent.
  Future<List<ChatSession>> save(
    List<ChatSession> sessions, {
    Set<String> keep = const {},
  }) async {
    final pruned = ChatSessionRotation.prune(sessions, keep: keep);
    try {
      await _storage.write(
        _storageKey,
        jsonEncode(pruned.map((s) => s.toJson()).toList()),
      );
    } catch (_) {
      // Ignore — keep the trimmed list in memory regardless.
    }
    return pruned;
  }
}
