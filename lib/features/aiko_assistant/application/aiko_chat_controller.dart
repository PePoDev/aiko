import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  });

  final List<ChatMessage> messages;
  final bool isStreaming;
  final ChatError? lastError;

  /// True when Supabase isn't configured, so Aiko answers on-device using the
  /// rule-based engine instead of the cloud function.
  final bool offline;

  bool get isEmpty => messages.length <= 1 && !messages.any((m) => m.isUser);

  bool get showSuggestions => isEmpty;

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isStreaming,
    ChatError? lastError,
    bool clearError = false,
    bool? offline,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isStreaming: isStreaming ?? this.isStreaming,
      lastError: clearError ? null : (lastError ?? this.lastError),
      offline: offline ?? this.offline,
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

final aikoChatControllerProvider =
    NotifierProvider<AikoChatController, ChatState>(AikoChatController.new);

class AikoChatController extends Notifier<ChatState> {
  StreamSubscription<ChatReplyEvent>? _subscription;
  String? _lastUserText;

  @override
  ChatState build() {
    final offline = !ref.watch(supabaseConfigProvider).isConfigured;
    ref.onDispose(() {
      _subscription?.cancel();
    });
    return ChatState(
      offline: offline,
      messages: const [_greeting],
      isStreaming: false,
      lastError: null,
    );
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
        state = state.copyWith(isStreaming: false, clearError: true);
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
