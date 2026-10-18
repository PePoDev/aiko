import '../../../core/firebase/firebase_backend.dart';
import '../../../core/network/network_errors.dart';
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
    this.needsSignIn = false,
  });

  final List<ChatMessage> messages;
  final bool isStreaming;
  final ChatError? lastError;

  /// True when Firebase isn't configured, so Aiko answers on-device using the
  /// rule-based engine instead of the cloud function.
  final bool offline;

  /// True for a guest (a cloud build with nobody signed in): chat needs an
  /// account, and nothing is sent until they sign in.
  final bool needsSignIn;

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
      needsSignIn: needsSignIn,
    );
  }
}

final aikoChatEngineProvider = Provider<HttpChatEngine>((ref) {
  return HttpChatEngine(functionUrl: FirebaseBackend.chatUrl);
});

/// True when Firebase isn't configured (local-only mode), so chat can't run.
final aikoChatOfflineProvider = Provider<bool>(
  (ref) => !FirebaseBackend.isConfigured,
);

/// True for a guest (a cloud build with nobody signed in): Aiko cloud only
/// answers signed-in users, so the chat asks them to sign in instead of
/// sending their question and financial snapshot. Follows sign-in and
/// sign-out.
final aikoChatNeedsSignInProvider = Provider<bool>((ref) {
  final auth = FirebaseBackend.auth;
  if (auth == null) return false;
  final needsSignIn = cloudFeatureNeedsSignIn();
  final subscription = auth.authStateChanges().listen((user) {
    if ((user == null) != needsSignIn) ref.invalidateSelf();
  });
  ref.onDispose(subscription.cancel);
  return needsSignIn;
});

final aikoChatControllerProvider =
    NotifierProvider<AikoChatController, ChatState>(AikoChatController.new);

class AikoChatController extends Notifier<ChatState> {
  StreamSubscription<ChatReplyEvent>? _subscription;
  String? _lastUserText;

  @override
  ChatState build() {
    final offline = ref.watch(aikoChatOfflineProvider);
    final needsSignIn = !offline && ref.watch(aikoChatNeedsSignInProvider);
    ref.onDispose(() {
      _subscription?.cancel();
    });
    return ChatState(
      offline: offline,
      needsSignIn: needsSignIn,
      messages: const [_greeting],
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
      // Drop the initial greeting from the transcript the moment the user
      // sends their first message — it belongs to the empty state, not the
      // conversation log, and shouldn't be re-sent to the model.
      if (state.isEmpty) messages.removeAt(0);
      // A failed reply leaves an empty assistant bubble; drop it so the new
      // question doesn't sit under a blank answer.
      while (messages.isNotEmpty &&
          !messages.last.isUser &&
          messages.last.content.isEmpty) {
        messages.removeLast();
      }
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
    if (state.needsSignIn) {
      // Nothing about the guest's money leaves the device.
      _handleEvent(
        const ChatReplyError(ChatFailure.signInRequired, retryable: false),
      );
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
          onDone: _handleStreamClosed,
        );
  }

  /// The stream ended without a done or error event (a dropped connection):
  /// whatever arrived stays, marked as cut off (not a complete answer), with
  /// a retry; with nothing at all, a retryable failure. Typing stops.
  void _handleStreamClosed() {
    if (!ref.mounted || !state.isStreaming) return;
    final last = state.messages.isEmpty ? null : state.messages.last;
    if (last != null && !last.isUser && last.content.isNotEmpty) {
      _handleEvent(const ChatReplyError(ChatFailure.cutOff));
    } else {
      _handleEvent(const ChatReplyError(ChatFailure.unavailable));
    }
  }

  void _handleEvent(ChatReplyEvent event) {
    switch (event) {
      case ChatReplyDelta(delta: final delta):
        _appendToLast(delta);
      case ChatReplyDone(fullText: _):
        _finalizeLastMessage();
      case ChatReplyError(error: final e, retryable: final retryable):
        final failure = _failureOf(e);
        state = state.copyWith(
          // Part of an answer that broke off stays, marked incomplete.
          messages: _markLastIncomplete(state.messages),
          isStreaming: false,
          lastError: ChatError(
            _humanize(e),
            retryable: failure?.isRetryable ?? retryable,
          ),
        );
    }
  }

  static List<ChatMessage> _markLastIncomplete(List<ChatMessage> messages) {
    if (messages.isEmpty) return messages;
    final last = messages.last;
    if (last.isUser || last.content.isEmpty || last.incomplete) {
      return messages;
    }
    return [
      ...messages.sublist(0, messages.length - 1),
      ChatMessage(role: last.role, content: last.content, incomplete: true),
    ];
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

  ChatFailure? _failureOf(Object error) => switch (error) {
    ChatFailure() => error,
    ChatReplyError(error: final inner) => _failureOf(inner),
    _ => null,
  };

  String _humanize(Object error) {
    final l10n = currentL10n();
    if (error is ChatReplyError) return _humanize(error.error);
    if (error is ChatFailure) {
      return switch (error) {
        ChatFailure.signInExpired => l10n.chatErrorSignInExpired,
        ChatFailure.signInRequired => l10n.netChatNeedsSignIn,
        ChatFailure.forbidden => l10n.chatErrorForbidden,
        ChatFailure.rateLimited => l10n.chatErrorRateLimited,
        ChatFailure.unavailable => l10n.chatErrorUnavailable,
        ChatFailure.badResponse => l10n.chatErrorBadResponse,
        ChatFailure.offline => l10n.chatErrorOffline,
        ChatFailure.network => l10n.chatErrorNetwork,
        ChatFailure.timedOut => l10n.netChatTimedOut,
        ChatFailure.cutOff => l10n.netChatCutOff,
      };
    }
    if (isNetworkError(error)) return l10n.chatErrorNetwork;
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
