import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;

/// Whether [error] means a request never got an answer from the server: no
/// connection, a timeout, or the SDK's own transport failure. Screens use it
/// to say "you're offline" instead of a generic failure, and the price
/// refresh to stop early without using up its rate budget.
///
/// - `http` wraps every transport failure (SocketException on Android/iOS,
///   "Failed to fetch" on the web) in a [http.ClientException].
/// - Firebase callables report a connection failure as `unavailable` on
///   Android and iOS, and as `internal` with the bare message "internal" on
///   the web (where a server crash looks the same, so the wording of offline
///   messages also suits a server that can't be reached).
/// - Firebase Auth reports `network-request-failed`; Firestore `unavailable`.
bool isNetworkError(Object error) {
  if (error is TimeoutException || error is http.ClientException) return true;
  if (error is FirebaseException) {
    switch (error.code) {
      case 'unavailable' || 'deadline-exceeded' || 'network-request-failed':
        return true;
      case 'internal':
        final message = (error.message ?? '').trim().toLowerCase();
        return message.isEmpty || message == 'internal';
    }
    return false;
  }
  final text = error.toString();
  return text.contains('SocketException') ||
      text.contains('Failed host lookup') ||
      text.contains('Network is unreachable') ||
      text.contains('Connection refused') ||
      text.contains('Connection reset');
}
