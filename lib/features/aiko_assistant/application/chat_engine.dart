import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../core/firebase/firebase_backend.dart';
import 'financial_context.dart';

class ChatMessage {
  const ChatMessage({
    required this.role,
    required this.content,
    this.disclaimer,
  });

  final String role;
  final String content;

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
  offline,
}

class ChatReplyError extends ChatReplyEvent {
  const ChatReplyError(this.error, {this.retryable = true});

  /// A [ChatFailure], or the underlying exception for anything else.
  final Object error;
  final bool retryable;
}

class HttpChatEngine {
  const HttpChatEngine({required this.functionUrl, http.Client? client})
    : _client = client;

  final String functionUrl;
  final http.Client? _client;

  /// [locale] (for example `th`) tells Aiko which language to answer in.
  Stream<ChatReplyEvent> streamReply({
    required List<ChatMessage> history,
    AikoFinancialContext? context,
    String? locale,
  }) {
    final controller = StreamController<ChatReplyEvent>();
    final client = _client ?? http.Client();
    final messages = history
        .map((m) => {'role': m.role, 'content': m.content})
        .toList(growable: false);

    unawaited(() async {
      try {
        final request = http.Request('POST', Uri.parse(functionUrl))
          ..headers['Content-Type'] = 'application/json'
          ..headers['Accept'] = 'text/event-stream';

        final token = await FirebaseBackend.auth?.currentUser?.getIdToken();
        if (token != null) {
          request.headers['Authorization'] = 'Bearer $token';
        }

        request.body = jsonEncode({
          'messages': messages,
          if (locale != null) 'systemContext': {'locale': locale},
          if (context != null) 'financialContext': context.toJson(),
        });

        final response = await client.send(request);
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

        final buffer = StringBuffer();
        final lines = response.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter());

        await for (final line in lines) {
          if (line.isEmpty) continue;
          if (!line.startsWith('data:')) continue;
          final payload = line.substring(5).trim();
          if (payload.isEmpty) continue;
          if (payload == '[DONE]') {
            controller.add(ChatReplyDone(buffer.toString()));
            break;
          }
          try {
            final json = jsonDecode(payload);
            if (json is Map<String, dynamic>) {
              if (json['error'] is String) {
                debugPrint('[aiko-chat] ${json['error']}');
                controller.add(const ChatReplyError(ChatFailure.unavailable));
                break;
              }
              final delta = json['delta'];
              if (delta is String && delta.isNotEmpty) {
                buffer.write(delta);
                controller.add(ChatReplyDelta(delta));
              } else if (json['done'] == true) {
                controller.add(ChatReplyDone(buffer.toString()));
                break;
              }
            }
          } on FormatException {
            controller.add(const ChatReplyError(ChatFailure.badResponse));
            break;
          }
        }
        await controller.close();
      } catch (e) {
        controller.add(ChatReplyError(e));
        await controller.close();
      } finally {
        if (_client == null) client.close();
      }
    }());

    return controller.stream;
  }
}
