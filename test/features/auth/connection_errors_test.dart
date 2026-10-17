import 'dart:async';

import 'package:aiko/features/auth/data/connection_errors.dart';
import 'package:aiko/features/auth/presentation/auth_error_message.dart';
import 'package:aiko/l10n/app_localizations.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';

void main() {
  group('pendingWritesRemain', () {
    const timeout = Duration(milliseconds: 20);

    test('nothing pending when the writes upload in time', () async {
      expect(await pendingWritesRemain(() async {}, timeout: timeout), isFalse);
    });

    test('pending when they are still queued (offline)', () async {
      final never = Completer<void>();
      expect(
        await pendingWritesRemain(() => never.future, timeout: timeout),
        isTrue,
      );
    });

    test('a failed wait counts as pending, so the user is warned', () async {
      expect(
        await pendingWritesRemain(
          () async => throw StateError('closed'),
          timeout: timeout,
        ),
        isTrue,
      );
    });
  });

  group('isNetworkError', () {
    test('recognises a missing connection', () {
      for (final error in <Object>[
        FirebaseAuthException(code: 'network-request-failed'),
        FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
        FirebaseFunctionsException(message: 'offline', code: 'unavailable'),
        const GoogleSignInException(
          code: GoogleSignInExceptionCode.unknownError,
          description: 'A network error occurred.',
        ),
        PlatformException(code: 'network_error'),
        TimeoutException('slow'),
        const NeedsConnectionException(),
      ]) {
        expect(isNetworkError(error), isTrue, reason: '$error');
      }
    });

    test('leaves other failures alone', () {
      for (final error in <Object>[
        FirebaseAuthException(code: 'wrong-password'),
        FirebaseFunctionsException(message: 'no', code: 'failed-precondition'),
        FirebaseFunctionsException(message: 'slow', code: 'deadline-exceeded'),
        const GoogleSignInException(
          code: GoogleSignInExceptionCode.clientConfigurationError,
          description: 'Missing server client id.',
        ),
        StateError('Sign in first.'),
      ]) {
        expect(isNetworkError(error), isFalse, reason: '$error');
      }
    });
  });

  group('authErrorMessage', () {
    final l10n = lookupAppLocalizations(const Locale('en'));

    test('offline, says what needs the connection', () {
      final error = FirebaseAuthException(code: 'network-request-failed');

      expect(
        authErrorMessage(
          error,
          l10n,
          fallback: l10n.authSignInFailed,
          offline: l10n.guestSignInNeedsConnection,
        ),
        l10n.guestSignInNeedsConnection,
      );
      expect(
        authErrorMessage(error, l10n, fallback: l10n.authSignInFailed),
        l10n.authErrorNetwork,
      );
    });

    test('a Google picker without a connection is offline too', () {
      expect(
        authErrorMessage(
          const GoogleSignInException(
            code: GoogleSignInExceptionCode.unknownError,
            description: 'The Internet connection appears to be offline.',
          ),
          l10n,
          fallback: l10n.authGoogleFailed,
          offline: l10n.guestSignInNeedsConnection,
        ),
        l10n.guestSignInNeedsConnection,
      );
    });

    test('other errors keep their own message', () {
      expect(
        authErrorMessage(
          FirebaseAuthException(code: 'wrong-password'),
          l10n,
          fallback: l10n.authSignInFailed,
          offline: l10n.guestSignInNeedsConnection,
        ),
        l10n.authErrorWrongCredentials,
      );
      expect(
        authErrorMessage(
          StateError('boom'),
          l10n,
          fallback: l10n.authResetFailed,
          offline: l10n.guestResetNeedsConnection,
        ),
        l10n.authResetFailed,
      );
    });
  });
}
