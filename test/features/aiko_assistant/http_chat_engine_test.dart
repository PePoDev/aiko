import 'dart:async';
import 'dart:convert';

import 'package:aiko/features/aiko_assistant/application/chat_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('HttpChatEngine', () {
    test(
      'parses SSE delta chunks and emits a Done with the full text',
      () async {
        final client = MockClient.streaming((request, stream) async {
          return http.StreamedResponse(
            Stream.fromIterable([
              utf8.encode('data: {"delta":"You "}\n\n'),
              utf8.encode('data: {"delta":"have "}\n\n'),
              utf8.encode('data: {"delta":"\$612"}\n\n'),
              utf8.encode('data: {"done":true}\n\n'),
            ]),
            200,
            headers: {'content-type': 'text/event-stream'},
          );
        });

        final engine = HttpChatEngine(
          functionUrl: 'https://example.test/functions/v1/aiko-chat',
          client: client,
        );

        final events = await engine
            .streamReply(
              history: const [ChatMessage(role: 'user', content: 'safe')],
            )
            .toList();

        final deltas = events.whereType<ChatReplyDelta>().map((e) => e.delta);
        expect(deltas, ['You ', 'have ', '\$612']);
        expect(
          events.whereType<ChatReplyDone>().single.fullText,
          'You have \$612',
        );
      },
    );

    test('surfaces 401 as a non-retryable error', () async {
      final client = MockClient((_) async => http.Response('nope', 401));
      final engine = HttpChatEngine(
        functionUrl: 'https://example.test/functions/v1/aiko-chat',
        client: client,
      );

      final events = await engine
          .streamReply(
            history: const [ChatMessage(role: 'user', content: 'x')],
          )
          .toList();

      final error = events.whereType<ChatReplyError>().single;
      expect(error.retryable, isFalse);
    });

    test('surfaces 403 as a non-retryable error', () async {
      final client = MockClient((_) async => http.Response('off', 403));
      final engine = HttpChatEngine(
        functionUrl: 'https://example.test/functions/v1/aiko-chat',
        client: client,
      );

      final events = await engine
          .streamReply(
            history: const [ChatMessage(role: 'user', content: 'x')],
          )
          .toList();

      final error = events.whereType<ChatReplyError>().single;
      expect(error.retryable, isFalse);
      expect(error.error, ChatFailure.forbidden);
    });

    test('surfaces 429 as a retryable error', () async {
      final client = MockClient((_) async => http.Response('slow', 429));
      final engine = HttpChatEngine(
        functionUrl: 'https://example.test/functions/v1/aiko-chat',
        client: client,
      );

      final events = await engine
          .streamReply(
            history: const [ChatMessage(role: 'user', content: 'x')],
          )
          .toList();

      final error = events.whereType<ChatReplyError>().single;
      expect(error.retryable, isTrue);
    });

    test('surfaces a bad SSE payload as a non-retryable error', () async {
      final client = MockClient.streaming((request, stream) async {
        return http.StreamedResponse(
          Stream.value(utf8.encode('data: not-json\n\n')),
          200,
          headers: {'content-type': 'text/event-stream'},
        );
      });
      final engine = HttpChatEngine(
        functionUrl: 'https://example.test/functions/v1/aiko-chat',
        client: client,
      );

      final events = await engine
          .streamReply(
            history: const [ChatMessage(role: 'user', content: 'x')],
          )
          .toList();

      final error = events.whereType<ChatReplyError>().single;
      expect(error.error, ChatFailure.badResponse);
    });
  });
}
