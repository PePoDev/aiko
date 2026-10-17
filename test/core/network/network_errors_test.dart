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
    // Callables: Android/iOS report `unavailable`, the web a bare `internal`.
    expect(
      isNetworkError(
        FirebaseFunctionsException(code: 'unavailable', message: 'UNAVAILABLE'),
      ),
      isTrue,
    );
    expect(
      isNetworkError(
        FirebaseFunctionsException(code: 'internal', message: 'internal'),
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
    expect(
      isNetworkError(FirebaseAuthException(code: 'wrong-password')),
      isFalse,
    );
    expect(isNetworkError(StateError('bug')), isFalse);
    expect(isNetworkError(const FormatException('bad json')), isFalse);
  });
}
