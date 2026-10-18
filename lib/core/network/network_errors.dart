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
/// - Web (Firebase JS SDK 12): no HTTP response at all is status 0, reported
///   as `internal` with the message "internal [0]" ("<description>
///   [<status>]"). A server crash has a status ("INTERNAL [500]").
/// - Android: an IOException becomes `unavailable` / "UNAVAILABLE". A server
///   crash is `internal` / "INTERNAL", so a bare `internal` is not offline.
/// - Every platform: the client's own timeout is `deadline-exceeded` with a
///   bare message ("deadline-exceeded", "DEADLINE_EXCEEDED", "DEADLINE
///   EXCEEDED"). The request may have reached the server.
bool isCallableTransportFailure(FirebaseFunctionsException error) {
  final message = (error.message ?? '').trim();
  if (_noResponseStatus.hasMatch(message)) return true;
  if (error.code != 'unavailable' && error.code != 'deadline-exceeded') {
    return false;
  }
  final bare = message.toLowerCase().replaceAll(RegExp(r'[\s_]+'), '-');
  return bare.isEmpty || bare == error.code;
}

/// The JS SDK's "<description> [0]": the request got no HTTP response.
final _noResponseStatus = RegExp(r'\[0\]$');

/// Whether a feature that runs on Aiko cloud (Ask Aiko, receipt reading,
/// live prices) needs the user to sign in first: a cloud build with nobody
/// signed in (a guest). The functions only answer signed-in users, so
/// nothing is sent then.
bool cloudFeatureNeedsSignIn() =>
    FirebaseBackend.isConfigured && FirebaseBackend.userId == null;
