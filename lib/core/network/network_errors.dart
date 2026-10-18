import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;

import '../firebase/firebase_backend.dart';

/// Whether [error] means a request never got an answer from the server: no
/// connection, a timeout, or the SDK's own transport failure. Screens use it
/// to say "you're offline" instead of a generic failure, and the price
/// refresh to stop early.
///
/// - `http` wraps every transport failure (SocketException on Android/iOS,
///   "Failed to fetch" on the web) in a [http.ClientException].
/// - Firebase callables: see [isCallableTransportFailure]. An error the
///   function raised itself (even `unavailable`) is an answer, not offline.
/// - Firebase Auth reports `network-request-failed`; Firestore `unavailable`.
bool isNetworkError(Object error) {
  if (error is TimeoutException || error is http.ClientException) return true;
  if (error is FirebaseFunctionsException) {
    return isCallableTransportFailure(error);
  }
  if (error is FirebaseException) {
    return switch (error.code) {
      'unavailable' || 'deadline-exceeded' || 'network-request-failed' => true,
      _ => false,
    };
  }
  final text = error.toString();
  return text.contains('SocketException') ||
      text.contains('Failed host lookup') ||
      text.contains('Network is unreachable') ||
      text.contains('Connection refused') ||
      text.contains('Connection reset');
}

/// Whether a callable failed in the SDK, before the function answered. An
/// error the function raises carries its own message ("Provider request
/// failed."); the SDK's own failures carry none, or just the code:
///
/// - Web (Firebase JS SDK 12): the message is `<code> [<status>]`, and no
///   HTTP response at all is status 0 (`internal` / "internal [0]"). A
///   server crash has a status ("internal [500]").
/// - Android: an IOException becomes `unavailable` / "UNAVAILABLE". A server
///   crash is `internal` / "INTERNAL", so a bare `internal` is not offline.
/// - iOS: a URL loading failure (no connection, host not found, connection
///   lost) is not a Functions error, so FlutterFire reports `unknown` with
///   the system's description. The functions never raise `unknown`; the
///   other SDKs use it for an HTTP status they don't know ("UNKNOWN",
///   "unknown [502]"), which is an answer.
/// - Every platform: the client's own timeout is `deadline-exceeded` with a
///   bare message ("deadline-exceeded", "DEADLINE_EXCEEDED", "DEADLINE
///   EXCEEDED"). The request may have reached the server.
bool isCallableTransportFailure(FirebaseFunctionsException error) {
  final message = (error.message ?? '').trim();
  final status = _httpStatus.firstMatch(message)?.group(1);
  if (status != null) return status == '0';
  final bare = message.toLowerCase().replaceAll(RegExp(r'[\s_]+'), '-');
  return switch (error.code) {
    'unavailable' || 'deadline-exceeded' => bare.isEmpty || bare == error.code,
    'unknown' => bare.isNotEmpty && bare != error.code,
    _ => false,
  };
}

/// The JS SDK's `<description> [<status>]`; status 0 is no HTTP response.
final _httpStatus = RegExp(r'\[(\d{1,3})\]$');

/// Whether a feature that runs on Aiko cloud (Ask Aiko, receipt reading,
/// live prices) needs the user to sign in first: a cloud build with nobody
/// signed in (a guest). The functions only answer signed-in users, so
/// nothing is sent then.
bool cloudFeatureNeedsSignIn() =>
    FirebaseBackend.isConfigured && FirebaseBackend.userId == null;
