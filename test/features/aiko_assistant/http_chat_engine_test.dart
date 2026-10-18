import 'dart:async';
import 'dart:convert';

import 'package:aiko/features/aiko_assistant/application/chat_engine.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

    test('skips the keep-alive comments sent before the first words', () async {
      final client = MockClient.streaming((request, stream) async {
        return http.StreamedResponse(
          Stream.fromIterable([
            utf8.encode(': ok\n\n'),
            utf8.encode(': ping\n\n'),
            utf8.encode('data: {"delta":"Hi"}\n\n'),
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
            history: const [ChatMessage(role: 'user', content: 'x')],
          )
          .toList();

      expect(events.whereType<ChatReplyError>(), isEmpty);
      expect(events.whereType<ChatReplyDone>().single.fullText, 'Hi');
    });

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

  group('HttpChatEngine offline and cut-off handling', () {
    const url = 'https://example.test/functions/v1/aiko-chat';
    const history = [ChatMessage(role: 'user', content: 'x')];

    Future<List<ChatReplyEvent>> eventsFrom(
      http.Client client, {
      Duration responseTimeout = const Duration(seconds: 60),
      Duration idleTimeout = const Duration(seconds: 45),
    }) => HttpChatEngine(
      functionUrl: url,
      client: client,
      responseTimeout: responseTimeout,
      idleTimeout: idleTimeout,
    ).streamReply(history: history).toList();

    http.StreamedResponse sse(Stream<String> lines) => http.StreamedResponse(
      lines.map(utf8.encode),
      200,
      headers: {'content-type': 'text/event-stream'},
    );

    test('a stream that ends without its done marker is cut off', () async {
      final events = await eventsFrom(
        MockClient.streaming(
          (request, body) async =>
              sse(Stream.fromIterable(['data: {"delta":"Half an "}\n\n'])),
        ),
      );
      expect(events.whereType<ChatReplyDone>(), isEmpty);
      expect(events.whereType<ChatReplyDelta>().single.delta, 'Half an ');
      expect(events.last, isA<ChatReplyError>());
      expect((events.last as ChatReplyError).error, ChatFailure.cutOff);
    });

    test('an empty answer is unavailable, not cut off', () async {
      final events = await eventsFrom(
        MockClient.streaming(
          (request, body) async => sse(const Stream.empty()),
        ),
      );
      expect(
        events.whereType<ChatReplyError>().single.error,
        ChatFailure.unavailable,
      );
    });

    test('no connection is a retryable network failure', () async {
      final events = await eventsFrom(
        MockClient((_) async => throw http.ClientException('Failed to fetch')),
      );
      final error = events.whereType<ChatReplyError>().single;
      expect(error.error, ChatFailure.network);
      expect(ChatFailure.network.isRetryable, isTrue);
    });

    test('no answer in time ends the request', () async {
      final never = Completer<http.StreamedResponse>();
      final events = await eventsFrom(
        MockClient.streaming((request, body) => never.future),
        responseTimeout: const Duration(milliseconds: 20),
      );
      expect(
        events.whereType<ChatReplyError>().single.error,
        ChatFailure.timedOut,
      );
    });

    test('a stall mid-answer marks the answer cut off', () async {
      final lines = StreamController<String>();
      lines.add('data: {"delta":"Partial"}\n\n');
      addTearDown(lines.close);
      final events = await eventsFrom(
        MockClient.streaming((request, body) async => sse(lines.stream)),
        idleTimeout: const Duration(milliseconds: 20),
      );
      expect(events.whereType<ChatReplyDelta>().single.delta, 'Partial');
      expect(
        events.whereType<ChatReplyError>().single.error,
        ChatFailure.cutOff,
      );
    });
  });

  group('chatFailureFor', () {
    test('classifies offline errors from every platform', () {
      expect(
        chatFailureFor(http.ClientException('SocketException: Failed host')),
        ChatFailure.network,
      );
      expect(
        chatFailureFor(FirebaseAuthException(code: 'network-request-failed')),
        ChatFailure.network,
      );
      expect(chatFailureFor(TimeoutException('slow')), ChatFailure.timedOut);
    });

    test('anything after part of an answer is a cut-off', () {
      expect(
        chatFailureFor(
          http.ClientException('Connection reset'),
          partial: StringBuffer('Half'),
        ),
        ChatFailure.cutOff,
      );
    });

    test('other errors pass through', () {
      final error = StateError('bug');
      expect(chatFailureFor(error), same(error));
    });
  });
}
