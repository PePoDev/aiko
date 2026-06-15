import '../application/chat_engine.dart';

/// A saved Aiko chat conversation kept on-device.
///
/// The chat screen keeps a small rolling history of past conversations so the
/// user can jump back to an earlier thread. Only a handful of *unpinned*
/// sessions survive the rotation (see [ChatSessionRotation]); a [pinned]
/// session is exempt and stays until the user removes it.
class ChatSession {
  const ChatSession({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.messages,
    this.pinned = false,
  });

  final String id;

  /// Human-readable label, derived from the first user message.
  final String title;

  final DateTime createdAt;
  final DateTime updatedAt;

  /// Pinned sessions are excluded from the rolling-window rotation.
  final bool pinned;

  final List<ChatMessage> messages;

  /// True once the conversation has at least one user turn — only then is it
  /// worth keeping in history (an untouched greeting isn't).
  bool get hasUserTurn => messages.any((m) => m.isUser);

  ChatSession copyWith({
    String? title,
    DateTime? updatedAt,
    bool? pinned,
    List<ChatMessage>? messages,
  }) {
    return ChatSession(
      id: id,
      title: title ?? this.title,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      pinned: pinned ?? this.pinned,
      messages: messages ?? this.messages,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'pinned': pinned,
    'messages': messages.map((m) => m.toJson()).toList(),
  };

  static ChatSession fromJson(Map<String, Object?> json) {
    final rawMessages = json['messages'];
    return ChatSession(
      id: json['id'] as String,
      title: (json['title'] as String?) ?? 'Chat',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
      pinned: json['pinned'] == true,
      messages: rawMessages is List
          ? rawMessages
                .whereType<Map<String, Object?>>()
                .map(ChatMessage.fromJson)
                .toList()
          : const [],
    );
  }

  /// Builds a concise title from the first user message in [messages],
  /// falling back to a generic label.
  static String titleFrom(List<ChatMessage> messages) {
    String? firstUser;
    for (final m in messages) {
      if (m.isUser && m.content.trim().isNotEmpty) {
        firstUser = m.content.trim();
        break;
      }
    }
    if (firstUser == null) return 'New chat';
    final singleLine = firstUser.replaceAll(RegExp(r'\s+'), ' ');
    return singleLine.length <= 40
        ? singleLine
        : '${singleLine.substring(0, 39)}…';
  }
}

/// Keeps the saved-session list within its rolling window.
abstract final class ChatSessionRotation {
  /// How many *unpinned* sessions are retained.
  static const maxUnpinned = 3;

  /// Returns [sessions] trimmed to the rolling window: every pinned session is
  /// kept, every id in [keep] is kept (used to protect the active session),
  /// and the most-recently-updated unpinned sessions fill the rest up to
  /// [maxUnpinned]. Order is preserved as updated-descending.
  static List<ChatSession> prune(
    List<ChatSession> sessions, {
    Set<String> keep = const {},
  }) {
    final ordered = [...sessions]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final result = <ChatSession>[];
    var unpinnedKept = 0;
    for (final session in ordered) {
      if (session.pinned || keep.contains(session.id)) {
        result.add(session);
      } else if (unpinnedKept < maxUnpinned) {
        result.add(session);
        unpinnedKept++;
      }
    }
    return result;
  }
}
