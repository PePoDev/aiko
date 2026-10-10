import '../../../core/firebase/firebase_backend.dart';
import '../../../l10n/l10n.dart';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'chat_engine.dart';
import 'financial_context.dart';

/// Placeholder for the empty state; the screen shows `l10n.chatGreeting` in
/// its place, and it is dropped before the first message is sent.
const _greeting = ChatMessage(role: 'assistant', content: '');

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

  /// True when Firebase isn't configured, so Aiko answers on-device using the
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

final aikoChatEngineProvider = Provider<HttpChatEngine>((ref) {
  return HttpChatEngine(functionUrl: FirebaseBackend.chatUrl);
});

final aikoChatControllerProvider =
    NotifierProvider<AikoChatController, ChatState>(AikoChatController.new);

class AikoChatController extends Notifier<ChatState> {
  StreamSubscription<ChatReplyEvent>? _subscription;
  String? _lastUserText;

  @override
  ChatState build() {
    final offline = !FirebaseBackend.isConfigured;
    ref.onDispose(() {
      _subscription?.cancel();
    });
    return ChatState(offline: offline, messages: const [_greeting]);
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
      // Drop the initial greeting from the transcript the moment the user
      // sends their first message — it belongs to the empty state, not the
      // conversation log, and shouldn't be re-sent to the model.
      if (state.isEmpty) messages.removeAt(0);
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
    if (state.offline) {
      // ponytail: chat needs the cloud engine; on-device answering is gone.
      _handleEvent(const ChatReplyError(ChatFailure.offline, retryable: false));
      return;
    }
    final context = await buildAikoFinancialContext(ref);
    if (!ref.mounted) return;
    _subscription?.cancel();
    _subscription = ref
        .read(aikoChatEngineProvider)
        .streamReply(
          history: history,
          context: context,
          locale: currentL10n().localeName,
        )
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
  }

  String _humanize(Object error) {
    final l10n = currentL10n();
    if (error is ChatReplyError) return _humanize(error.error);
    if (error is ChatFailure) {
      return switch (error) {
        ChatFailure.signInExpired => l10n.chatErrorSignInExpired,
        ChatFailure.forbidden => l10n.chatErrorForbidden,
        ChatFailure.rateLimited => l10n.chatErrorRateLimited,
        ChatFailure.unavailable => l10n.chatErrorUnavailable,
        ChatFailure.badResponse => l10n.chatErrorBadResponse,
        ChatFailure.offline => l10n.chatErrorOffline,
      };
    }
    final text = error.toString();
    if (text.contains('SocketException') || text.contains('Failed host')) {
      return l10n.chatErrorNetwork;
    }
    return l10n.chatErrorGeneric;
  }
}

/// Splits an AI reply's accumulated text into its main answer and a trailing
/// italic disclaimer. The cloud Aiko prompt wraps
/// the disclaimer in `_…_` (or `*…*`) and separates it from the body with a
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
