import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/firebase/firebase_backend.dart';

/// Whether the signed-in user's LINE chat is linked. Disposed when no screen
/// shows it, and reset on sign-out (`invalidateUserSessionState`), so another
/// user never sees the previous user's status.
final lineLinkedProvider = FutureProvider.autoDispose<bool>(
  (ref) => const LineLinkRepository().isLinked(),
);

/// Pairing codes are 6 characters from the bot's alphabet: A–Z and 2–9
/// without the look-alikes I, L and O (`newPairingCode` in
/// firebase/functions/src/index.ts).
const linePairingCodeLength = 6;
final linePairingCodeCharacter = RegExp('[A-HJKMNP-Z2-9]');
final _linePairingCode = RegExp('^[A-HJKMNP-Z2-9]{$linePairingCodeLength}\$');

/// The reason for a failed `redeemLinePairing` call, by its error code.
LineLinkError lineLinkErrorForCode(String code) {
  return switch (code) {
    'not-found' => LineLinkError.expiredCode,
    'invalid-argument' => LineLinkError.invalidCode,
    'already-exists' => LineLinkError.alreadyLinked,
    'resource-exhausted' => LineLinkError.tooManyAttempts,
    'unauthenticated' => LineLinkError.signedOut,
    _ => LineLinkError.failed,
  };
}

class LineLinkRepository {
  const LineLinkRepository();
  Future<bool> isLinked() async {
    if (FirebaseBackend.userId == null) return false;
    try {
      return (await FirebaseBackend.collection(
        'integrations',
      ).doc('line').get()).exists;
    } catch (_) {
      return false;
    }
  }

  Future<void> connectWithCode(String rawCode) async {
    final code = rawCode.trim().toUpperCase();
    if (code.isEmpty) {
      throw const LineLinkException(LineLinkError.emptyCode);
    }
    if (!_linePairingCode.hasMatch(code)) {
      throw const LineLinkException(LineLinkError.invalidCode);
    }
    if (FirebaseBackend.userId == null) {
      throw const LineLinkException(LineLinkError.signedOut);
    }
    try {
      await FirebaseBackend.functions.httpsCallable('redeemLinePairing').call({
        'code': code,
      });
    } on FirebaseFunctionsException catch (error) {
      throw LineLinkException(lineLinkErrorForCode(error.code));
    } catch (_) {
      throw const LineLinkException(LineLinkError.failed);
    }
  }
}

enum LineLinkError {
  emptyCode,
  invalidCode,
  expiredCode,
  alreadyLinked,
  tooManyAttempts,
  signedOut,
  failed,
}

class LineLinkException implements Exception {
  const LineLinkException(this.reason);
  final LineLinkError reason;
  @override
  String toString() => 'LineLinkException(${reason.name})';
}
