import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../core/firebase/firebase_backend.dart';
import '../../../core/network/network_errors.dart';
import 'chat_http_client.dart';
import 'financial_context.dart';

class ChatMessage {
  const ChatMessage({
    required this.role,
    required this.content,
    this.disclaimer,
    this.incomplete = false,
  });

  final String role;
  final String content;

  /// The answer stopped before it finished (cut off); the chat says so
  /// instead of showing it as a complete answer.
  final bool incomplete;

  /// Optional AI disclaimer (estimates, not financial advice, etc.). When
  /// set, the chat UI renders it as compact italic text below a horizontal
  /// divider so it visually separates from the main answer.
  final String? disclaimer;

  bool get isUser => role == 'user';

  Map<String, Object?> toJson() => {
    'role': role,
    'content': content,
    if (disclaimer != null) 'disclaimer': disclaimer,
  };

  static ChatMessage fromJson(Map<String, Object?> json) => ChatMessage(
    role: (json['role'] as String?) ?? 'assistant',
    content: (json['content'] as String?) ?? '',
    disclaimer: json['disclaimer'] as String?,
  );
}

sealed class ChatReplyEvent {
  const ChatReplyEvent();
}

class ChatReplyDelta extends ChatReplyEvent {
  const ChatReplyDelta(this.delta);
  final String delta;
}

class ChatReplyDone extends ChatReplyEvent {
  const ChatReplyDone(this.fullText);
  final String fullText;
}

/// Known chat failures; the controller shows them in the user's language.
enum ChatFailure {
  signInExpired,
  forbidden,
  rateLimited,
  unavailable,
  badResponse,

  /// Local-only build: chat needs Aiko cloud.
  offline,

  /// Nobody is signed in (a guest on a cloud build): Aiko cloud only answers
  /// signed-in users, so nothing was sent.
  signInRequired,

  /// No connection (the request never reached Aiko).
  network,

  /// No answer within the response or idle time limit.
  timedOut,

  /// The answer stopped before it finished: the stream ended (or broke)
  /// without its done marker.
  cutOff,
}

extension ChatFailureRetry on ChatFailure {
  /// Whether sending the same message again can help. Sign-in, access and
  /// local-only mode need the user to act elsewhere first.
  bool get isRetryable => switch (this) {
    ChatFailure.signInExpired ||
    ChatFailure.signInRequired ||
    ChatFailure.forbidden ||
    ChatFailure.offline => false,
    ChatFailure.rateLimited ||
    ChatFailure.unavailable ||
    ChatFailure.badResponse ||
    ChatFailure.network ||
    ChatFailure.timedOut ||
    ChatFailure.cutOff => true,
  };
}

class ChatReplyError extends ChatReplyEvent {
  const ChatReplyError(this.error, {this.retryable = true});

  /// A [ChatFailure], or the underlying exception for anything else.
  final Object error;
  final bool retryable;
}

class HttpChatEngine {
  const HttpChatEngine({
    required this.functionUrl,
    http.Client? client,
    this.connectTimeout = const Duration(seconds: 15),
    this.responseTimeout = const Duration(seconds: 60),
    this.idleTimeout = const Duration(seconds: 45),
  }) : _client = client;

  final String functionUrl;
  final http.Client? _client;

  /// Opening the connection (Android and iOS; the browser has its own).
  final Duration connectTimeout;

  /// Until the response starts. Aiko cloud sends its headers as soon as it
  /// has checked the sign-in and starts on the answer, so this only measures
  /// whether it can be reached.
  final Duration responseTimeout;

  /// The longest gap between two parts of an answer. While Aiko looks data
  /// up before the first words, the server sends a keep-alive comment every
  /// 15 s.
  final Duration idleTimeout;

  /// [locale] (for example `th`) tells Aiko which language to answer in.
  Stream<ChatReplyEvent> streamReply({
    required List<ChatMessage> history,
    AikoFinancialContext? context,
    String? locale,
  }) {
    final controller = StreamController<ChatReplyEvent>();
    final client = _client ?? createChatHttpClient(connectTimeout);
    final messages = history
        .map((m) => {'role': m.role, 'content': m.content})
        .toList(growable: false);

    unawaited(() async {
      final buffer = StringBuffer();
      if (cloudFeatureNeedsSignIn()) {
        // Nothing is sent for a guest: the server would refuse it anyway.
        controller.add(
          const ChatReplyError(ChatFailure.signInRequired, retryable: false),
        );
        await controller.close();
        if (_client == null) client.close();
        return;
      }
      try {
        final request = http.Request('POST', Uri.parse(functionUrl))
          ..headers['Content-Type'] = 'application/json'
          ..headers['Accept'] = 'text/event-stream';

        // Refreshing an expired sign-in token needs the network too.
        final token = await FirebaseBackend.auth?.currentUser
            ?.getIdToken()
            .timeout(responseTimeout);
        if (token != null) {
          request.headers['Authorization'] = 'Bearer $token';
        }

        request.body = jsonEncode({
          'messages': messages,
          if (locale != null) 'systemContext': {'locale': locale},
          if (context != null) 'financialContext': context.toJson(),
        });

        final response = await client.send(request).timeout(responseTimeout);
        if (response.statusCode == 401) {
          controller.add(
            const ChatReplyError(ChatFailure.signInExpired, retryable: false),
          );
          await controller.close();
          return;
        }
        if (response.statusCode == 403) {
          controller.add(
            const ChatReplyError(ChatFailure.forbidden, retryable: false),
          );
          await controller.close();
          return;
        }
        if (response.statusCode == 429) {
          controller.add(
            const ChatReplyError(ChatFailure.rateLimited, retryable: true),
          );
          await controller.close();
          return;
        }
        if (response.statusCode >= 400) {
          debugPrint('[aiko-chat] HTTP ${response.statusCode}');
          controller.add(const ChatReplyError(ChatFailure.unavailable));
          await controller.close();
          return;
        }

        final lines = response.stream
            .timeout(idleTimeout)
            .transform(utf8.decoder)
            .transform(const LineSplitter());

        var ended = false;
        await for (final line in lines) {
          if (line.isEmpty) continue;
          if (!line.startsWith('data:')) continue;
          final payload = line.substring(5).trim();
          if (payload.isEmpty) continue;
          if (payload == '[DONE]') {
            controller.add(ChatReplyDone(buffer.toString()));
            ended = true;
            break;
          }
          try {
            final json = jsonDecode(payload);
            if (json is Map<String, dynamic>) {
              if (json['error'] is String) {
                debugPrint('[aiko-chat] ${json['error']}');
                controller.add(const ChatReplyError(ChatFailure.unavailable));
                ended = true;
                break;
              }
              final delta = json['delta'];
              if (delta is String && delta.isNotEmpty) {
                buffer.write(delta);
                controller.add(ChatReplyDelta(delta));
              } else if (json['done'] == true) {
                controller.add(ChatReplyDone(buffer.toString()));
                ended = true;
                break;
              }
            }
          } on FormatException {
            controller.add(const ChatReplyError(ChatFailure.badResponse));
            ended = true;
            break;
          }
        }
        if (!ended) {
          // The connection closed without the done marker: whatever arrived
          // is not the whole answer.
          controller.add(
            ChatReplyError(
              buffer.isEmpty ? ChatFailure.unavailable : ChatFailure.cutOff,
            ),
          );
        }
        await controller.close();
      } catch (e) {
        controller.add(ChatReplyError(chatFailureFor(e, partial: buffer)));
        await controller.close();
      } finally {
        if (_client == null) client.close();
      }
    }());

    return controller.stream;
  }
}

/// The [ChatFailure] for an exception while asking Aiko, or [error] itself
/// when it is none of them. Once part of an answer has arrived ([partial]),
/// any break leaves it cut off.
@visibleForTesting
Object chatFailureFor(Object error, {StringBuffer? partial}) {
  if (partial != null && partial.isNotEmpty) return ChatFailure.cutOff;
  if (error is TimeoutException) return ChatFailure.timedOut;
  if (isNetworkError(error)) return ChatFailure.network;
  return error;
}
