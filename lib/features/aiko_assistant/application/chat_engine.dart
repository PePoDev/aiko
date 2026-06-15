import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/supabase/supabase_client_provider.dart';
import '../domain/aiko_response.dart';
import 'aiko_assistant_service.dart';
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

class ChatReplyError extends ChatReplyEvent {
  const ChatReplyError(this.error, {this.retryable = true});
  final Object error;
  final bool retryable;
}

abstract class ChatEngine {
  Stream<ChatReplyEvent> streamReply({
    required List<ChatMessage> history,
    AikoFinancialContext? context,
  });
}

class OfflineChatEngine implements ChatEngine {
  const OfflineChatEngine({this.service = const AikoAssistantService()});

  final AikoAssistantService service;

  @override
  Stream<ChatReplyEvent> streamReply({
    required List<ChatMessage> history,
    AikoFinancialContext? context,
  }) {
    // The on-device engine answers from its own rule-based service; the
    // snapshot is only used by the cloud engine.
    final controller = StreamController<ChatReplyEvent>();
    scheduleMicrotask(() {
      final lastUser = history.lastWhere(
        (m) => m.isUser,
        orElse: () => const ChatMessage(role: 'user', content: ''),
      );
      AikoResponse response;
      try {
        response = service.answerQuestion(question: lastUser.content);
      } catch (e) {
        controller.add(ChatReplyError(e));
        controller.close();
        return;
      }
      final text = response.answer.trim();
      if (response.disclaimer != null && response.disclaimer!.isNotEmpty) {
        controller.add(ChatReplyDelta('$text\n\n_${response.disclaimer}_'));
      } else {
        controller.add(ChatReplyDelta(text));
      }
      controller.add(ChatReplyDone(text));
      controller.close();
    });
    return controller.stream;
  }
}

class HttpChatEngine implements ChatEngine {
  const HttpChatEngine({required this.functionUrl, http.Client? client})
    : _client = client;

  final String functionUrl;
  final http.Client? _client;

  @override
  Stream<ChatReplyEvent> streamReply({
    required List<ChatMessage> history,
    AikoFinancialContext? context,
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

        final session = AikoSupabase.tryClient();
        final token = session?.auth.currentSession?.accessToken;
        if (token != null) {
          request.headers['Authorization'] = 'Bearer $token';
        }

        request.body = jsonEncode({
          'messages': messages,
          if (context != null) 'financialContext': context.toJson(),
        });

        final response = await client.send(request);
        if (response.statusCode == 401) {
          controller.add(
            const ChatReplyError('Sign-in expired.', retryable: false),
          );
          await controller.close();
          return;
        }
        if (response.statusCode == 403) {
          controller.add(
            const ChatReplyError(
              "Aiko can't access this right now.",
              retryable: false,
            ),
          );
          await controller.close();
          return;
        }
        if (response.statusCode == 429) {
          controller.add(
            const ChatReplyError(
              'Slow down a bit — too many messages in a row.',
              retryable: true,
            ),
          );
          await controller.close();
          return;
        }
        if (response.statusCode >= 400) {
          controller.add(
            ChatReplyError(
              'Aiko service is unavailable (HTTP ${response.statusCode}).',
            ),
          );
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
                controller.add(ChatReplyError(json['error'] as String));
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
            controller.add(const ChatReplyError('Bad response from Aiko.'));
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
