import 'dart:async';

import 'package:aiko/core/network/network_errors.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  test('transport failures on every platform are network errors', () {
    // Web ("Failed to fetch") and Android/iOS (wrapped SocketException).
    expect(isNetworkError(http.ClientException('Failed to fetch')), isTrue);
    expect(isNetworkError(TimeoutException('slow')), isTrue);
    expect(
      isNetworkError(Exception('SocketException: Failed host lookup')),
      isTrue,
    );
    // Callables: Android reports `unavailable` with a bare message, the web
    // (JS SDK 12) `internal` with "internal [0]" (no HTTP response).
    expect(
      isNetworkError(
        FirebaseFunctionsException(code: 'unavailable', message: 'UNAVAILABLE'),
      ),
      isTrue,
    );
    expect(
      isNetworkError(
        FirebaseFunctionsException(code: 'internal', message: 'internal [0]'),
      ),
      isTrue,
    );
    expect(
      isNetworkError(
        FirebaseFunctionsException(
          code: 'deadline-exceeded',
          message: 'DEADLINE_EXCEEDED',
        ),
      ),
      isTrue,
    );
    expect(
      isNetworkError(FirebaseAuthException(code: 'network-request-failed')),
      isTrue,
    );
    expect(
      isNetworkError(
        FirebaseException(plugin: 'firestore', code: 'unavailable'),
      ),
      isTrue,
    );
    expect(
      isNetworkError(
        FirebaseException(
          plugin: 'cloud_firestore',
          code: 'unavailable',
          message: 'Failed to get document because the client is offline.',
        ),
      ),
      isTrue,
    );
  });

  test('a callable timeout is a transport failure on every platform', () {
    for (final message in [
      'deadline-exceeded',
      'DEADLINE_EXCEEDED',
      'DEADLINE EXCEEDED',
    ]) {
      expect(
        isCallableTransportFailure(
          FirebaseFunctionsException(
            code: 'deadline-exceeded',
            message: message,
          ),
        ),
        isTrue,
        reason: message,
      );
    }
  });

  test('answers from the server are not network errors', () {
    expect(
      isNetworkError(
        FirebaseFunctionsException(
          code: 'not-found',
          message: 'Code is invalid or expired.',
        ),
      ),
      isFalse,
    );
    expect(
      isNetworkError(
        FirebaseFunctionsException(
          code: 'internal',
          message: 'Receipt image too large.',
        ),
      ),
      isFalse,
    );
    // The function's own errors carry its message, even `unavailable`.
    expect(
      isNetworkError(
        FirebaseFunctionsException(
          code: 'unavailable',
          message: 'Provider request failed.',
        ),
      ),
      isFalse,
    );
    expect(
      isNetworkError(
        FirebaseFunctionsException(
          code: 'unavailable',
          message: 'Provider request failed. [503]',
        ),
      ),
      isFalse,
    );
    // A server crash: "INTERNAL" on Android/iOS, "INTERNAL [500]" on the web.
    expect(
      isNetworkError(
        FirebaseFunctionsException(code: 'internal', message: 'INTERNAL'),
      ),
      isFalse,
    );
    expect(
      isNetworkError(
        FirebaseFunctionsException(code: 'internal', message: 'INTERNAL [500]'),
      ),
      isFalse,
    );
    expect(
      isNetworkError(FirebaseAuthException(code: 'wrong-password')),
      isFalse,
    );
    expect(isNetworkError(StateError('bug')), isFalse);
    expect(isNetworkError(const FormatException('bad json')), isFalse);
  });
}
