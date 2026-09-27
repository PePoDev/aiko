import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/firebase/firebase_backend.dart';

final lineLinkedProvider = FutureProvider<bool>(
  (ref) => const LineLinkRepository().isLinked(),
);

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
      throw const LineLinkException('Enter the code from the LINE bot.');
    }
    if (FirebaseBackend.userId == null) {
      throw const LineLinkException('Sign in first, then connect LINE.');
    }
    try {
      await FirebaseBackend.functions.httpsCallable('redeemLinePairing').call({
        'code': code,
      });
    } catch (_) {
      throw const LineLinkException(
        'Could not connect LINE. Check the code and connection, then try again.',
      );
    }
  }
}

class LineLinkException implements Exception {
  const LineLinkException(this.message);
  final String message;
  @override
  String toString() => message;
}
