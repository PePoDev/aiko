import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// An account operation that needs the server was tried without a working
/// connection.
class NeedsConnectionException implements Exception {
  const NeedsConnectionException();

  @override
  String toString() => 'NeedsConnectionException';
}

/// Whether [error] means the server couldn't be reached (offline, or no
/// usable connection), as opposed to the server refusing the request.
bool isNetworkError(Object error) {
  if (error is NeedsConnectionException || error is TimeoutException) {
    return true;
  }
  // Auth, Firestore and Functions errors all extend FirebaseException.
  if (error is FirebaseException) {
    return error.code == 'network-request-failed' ||
        error.code == 'unavailable';
  }
  if (error is PlatformException) {
    return error.code == 'network_error' || _mentionsNetwork(error.message);
  }
  // The Google account picker reports platform errors as text only.
  if (error is GoogleSignInException) {
    return _mentionsNetwork(error.description);
  }
  return false;
}

final _networkWords = RegExp(
  r'network|offline|internet|unreachable|host lookup|timed out',
  caseSensitive: false,
);

bool _mentionsNetwork(String? text) =>
    text != null && _networkWords.hasMatch(text);

/// Whether writes made on this device are still waiting to reach the server
/// after giving [waitForPendingWrites] (`FirebaseFirestore.
/// waitForPendingWrites`) [timeout] to upload them. Offline they stay
/// queued, so this is true; a failed wait counts as pending too, so the
/// caller warns rather than risks losing them.
Future<bool> pendingWritesRemain(
  Future<void> Function() waitForPendingWrites, {
  required Duration timeout,
}) async {
  try {
    await waitForPendingWrites().timeout(timeout);
    return false;
  } catch (_) {
    return true;
  }
}
