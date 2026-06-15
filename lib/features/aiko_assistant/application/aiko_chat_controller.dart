import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../data/chat_session_store.dart';
import '../domain/chat_session.dart';
import 'chat_engine.dart';
import 'financial_context.dart';

const _greeting = ChatMessage(
  role: 'assistant',
  content:
      "Hi! I'm Aiko. Ask me anything about your money, budgets, goals, or spending.",
);

class ChatError {
  const ChatError(this.message, {required this.retryable});
  final String message;
  final bool retryable;
}

class ChatState {
  const ChatState({
    this.messages = const [_greeting],
    this.isStreaming = false,
    this.lastError,
    this.offline = false,
    this.sessions = const [],
    this.activeSessionId = '',
  });

  final List<ChatMessage> messages;
  final bool isStreaming;
  final ChatError? lastError;

  /// True when Supabase isn't configured, so Aiko answers on-device using the
  /// rule-based engine instead of the cloud function.
  final bool offline;

  /// Saved past conversations kept on-device. Includes the active session once
  /// it has been persisted; the UI filters [activeSessionId] out of the
  /// history list shown above the greeting.
  final List<ChatSession> sessions;

  /// Id of the conversation currently on screen.
  final String activeSessionId;

  bool get isEmpty => messages.length <= 1 && !messages.any((m) => m.isUser);

  bool get showSuggestions => isEmpty;

  /// Sessions to surface in the history list — everything except the live one.
  List<ChatSession> get history =>
      sessions.where((s) => s.id != activeSessionId).toList();

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isStreaming,
    ChatError? lastError,
    bool clearError = false,
    bool? offline,
    List<ChatSession>? sessions,
    String? activeSessionId,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isStreaming: isStreaming ?? this.isStreaming,
      lastError: clearError ? null : (lastError ?? this.lastError),
      offline: offline ?? this.offline,
      sessions: sessions ?? this.sessions,
      activeSessionId: activeSessionId ?? this.activeSessionId,
    );
  }
}

final aikoChatEngineProvider = Provider<ChatEngine>((ref) {
  final config = ref.watch(supabaseConfigProvider);
  if (!config.isConfigured) {
    return const OfflineChatEngine();
  }
  return HttpChatEngine(functionUrl: '${config.url}/functions/v1/aiko-chat');
});

final chatSessionStoreProvider = Provider<ChatSessionStore>(
  (ref) => ChatSessionStore(),
);

final aikoChatControllerProvider =
    NotifierProvider<AikoChatController, ChatState>(AikoChatController.new);

class AikoChatController extends Notifier<ChatState> {
  StreamSubscription<ChatReplyEvent>? _subscription;
  String? _lastUserText;
  static const _uuid = Uuid();

  ChatSessionStore get _store => ref.read(chatSessionStoreProvider);

  @override
  ChatState build() {
    final offline = !ref.watch(supabaseConfigProvider).isConfigured;
    ref.onDispose(() {
      _subscription?.cancel();
    });
    unawaited(_loadSessions());
    return ChatState(
      offline: offline,
      messages: const [_greeting],
      isStreaming: false,
      lastError: null,
      activeSessionId: _uuid.v4(),
    );
  }

  Future<void> _loadSessions() async {
    final sessions = await _store.load();
    if (!ref.mounted) return;
    state = state.copyWith(sessions: sessions);
  }

  /// Upserts the current conversation into the saved-session list and persists
  /// it (applying the rolling-window rotation). No-op until the conversation
  /// has a user turn worth keeping.
  Future<void> _persistActive() async {
    if (!state.messages.any((m) => m.isUser)) return;
    final now = DateTime.now();
    final existing = _find(state.activeSessionId);
    final title = (existing != null && existing.pinned)
        ? existing
              .title // keep a user-pinned thread's established title
        : ChatSession.titleFrom(state.messages);
    final session =
        existing?.copyWith(
          title: title,
          messages: state.messages,
          updatedAt: now,
        ) ??
        ChatSession(
          id: state.activeSessionId,
          title: title,
          createdAt: now,
          updatedAt: now,
          messages: state.messages,
        );
    final merged = [
      session,
      for (final s in state.sessions)
        if (s.id != session.id) s,
    ];
    final pruned = await _store.save(merged, keep: {state.activeSessionId});
    if (!ref.mounted) return;
    state = state.copyWith(sessions: pruned);
  }

  /// Saves the current conversation and starts a fresh one.
  Future<void> newChat() async {
    await _persistActive();
    _subscription?.cancel();
    _lastUserText = null;
    if (!ref.mounted) return;
    state = state.copyWith(
      messages: const [_greeting],
      isStreaming: false,
      clearError: true,
      activeSessionId: _uuid.v4(),
    );
  }

  /// Saves the current conversation, then loads [id] from history.
  Future<void> loadSession(String id) async {
    if (id == state.activeSessionId) return;
    await _persistActive();
    final target = _find(id);
    if (target == null || !ref.mounted) return;
    _subscription?.cancel();
    _lastUserText = target.messages
        .lastWhere(
          (m) => m.isUser,
          orElse: () => const ChatMessage(role: 'user', content: ''),
        )
        .content;
    state = state.copyWith(
      messages: target.messages,
      activeSessionId: id,
      isStreaming: false,
      clearError: true,
    );
  }

  Future<void> togglePin(String id) async {
    final updated = [
      for (final s in state.sessions)
        if (s.id == id) s.copyWith(pinned: !s.pinned) else s,
    ];
    final pruned = await _store.save(updated, keep: {state.activeSessionId});
    if (!ref.mounted) return;
    state = state.copyWith(sessions: pruned);
  }

  Future<void> deleteSession(String id) async {
    final remaining = [
      for (final s in state.sessions)
        if (s.id != id) s,
    ];
    final pruned = await _store.save(remaining, keep: {state.activeSessionId});
    if (!ref.mounted) return;
    var next = state.copyWith(sessions: pruned);
    // Deleting the live thread drops you into a fresh chat.
    if (id == state.activeSessionId) {
      _subscription?.cancel();
      _lastUserText = null;
      next = next.copyWith(
        messages: const [_greeting],
        activeSessionId: _uuid.v4(),
        isStreaming: false,
        clearError: true,
      );
    }
    state = next;
  }

  ChatSession? _find(String id) {
    for (final s in state.sessions) {
      if (s.id == id) return s;
    }
    return null;
  }

  void send(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.isStreaming) return;
    _lastUserText = trimmed;
    _streamReply(trimmed, addUserMessage: true);
  }

  void retry() {
    final lastUser = _lastUserText;
    if (lastUser == null || state.isStreaming) return;
    _streamReply(lastUser, addUserMessage: false);
  }

  void _streamReply(String text, {required bool addUserMessage}) {
    final messages = [...state.messages];
    if (addUserMessage) {
      messages.add(ChatMessage(role: 'user', content: text));
    }
    while (messages.isNotEmpty && !messages.last.isUser) {
      messages.removeLast();
    }
    messages.add(const ChatMessage(role: 'assistant', content: ''));
    state = state.copyWith(
      messages: messages,
      isStreaming: true,
      clearError: true,
    );

    final history = messages
        .where((m) => m.content.isNotEmpty || m.isUser)
        .toList(growable: false);
    unawaited(_dispatch(history));
  }

  /// Builds the on-device financial snapshot (Layer 1), then opens the stream.
  /// The optimistic UI update already happened in [_streamReply], so the brief
  /// snapshot build doesn't block the typing indicator.
  Future<void> _dispatch(List<ChatMessage> history) async {
    final context = state.offline ? null : await buildAikoFinancialContext(ref);
    if (!ref.mounted) return;
    _subscription?.cancel();
    _subscription = ref
        .read(aikoChatEngineProvider)
        .streamReply(history: history, context: context)
        .listen(
          _handleEvent,
          onError: (Object e) => _handleEvent(ChatReplyError(e)),
        );
  }

  void _handleEvent(ChatReplyEvent event) {
    switch (event) {
      case ChatReplyDelta(delta: final delta):
        _appendToLast(delta);
      case ChatReplyDone(fullText: _):
        _finalizeLastMessage();
      case ChatReplyError(error: final e, retryable: final retryable):
        state = state.copyWith(
          isStreaming: false,
          lastError: ChatError(_humanize(e), retryable: retryable),
        );
    }
  }

  void _appendToLast(String delta) {
    if (state.messages.isEmpty) return;
    final messages = [...state.messages];
    final last = messages.removeLast();
    messages.add(ChatMessage(role: last.role, content: last.content + delta));
    state = state.copyWith(messages: messages);
  }

  void _finalizeLastMessage() {
    if (state.messages.isEmpty) return;
    final messages = [...state.messages];
    final last = messages.removeLast();
    final split = splitTrailingDisclaimer(last.content);
    messages.add(
      ChatMessage(
        role: last.role,
        content: split.content,
        disclaimer: split.disclaimer,
      ),
    );
    state = state.copyWith(
      messages: messages,
      isStreaming: false,
      clearError: true,
    );
    unawaited(_persistActive());
  }

  String _humanize(Object error) {
    if (error is ChatReplyError) return error.error.toString();
    final text = error.toString();
    if (text.contains('SocketException') || text.contains('Failed host')) {
      return "I couldn't reach Aiko just now. Check your connection and try again.";
    }
    return 'Something went wrong. Tap retry to try again.';
  }
}

class _SupabaseConfig {
  const _SupabaseConfig({required this.url, required this.isConfigured});
  final String url;
  final bool isConfigured;
}

final supabaseConfigProvider = Provider<_SupabaseConfig>((ref) {
  final url = const String.fromEnvironment('SUPABASE_URL');
  return _SupabaseConfig(url: url, isConfigured: url.isNotEmpty);
});

/// Splits an AI reply's accumulated text into its main answer and a trailing
/// italic disclaimer. Both the offline engine and the cloud Aiko prompt wrap
/// the disclaimer in `_…_` (or `*…*`) and separate it from the body with a
/// blank line — we lift that block out so the chat can render it compact and
/// below a divider instead of as inline body text.
@visibleForTesting
({String content, String? disclaimer}) splitTrailingDisclaimer(String text) {
  final match = _trailingDisclaimerPattern.firstMatch(text);
  if (match == null) return (content: text, disclaimer: null);
  final disclaimer = match.group(2)!.trim();
  if (disclaimer.isEmpty) return (content: text, disclaimer: null);
  final content = text.substring(0, match.start).trimRight();
  return (content: content, disclaimer: disclaimer);
}

final RegExp _trailingDisclaimerPattern = RegExp(r'\n\n([_*])([^*_]+?)\1\s*$');
