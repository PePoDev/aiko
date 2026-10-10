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
      throw const LineLinkException(LineLinkError.emptyCode);
    }
    if (FirebaseBackend.userId == null) {
      throw const LineLinkException(LineLinkError.signedOut);
    }
    try {
      await FirebaseBackend.functions.httpsCallable('redeemLinePairing').call({
        'code': code,
      });
    } catch (_) {
      throw const LineLinkException(LineLinkError.failed);
    }
  }
}

enum LineLinkError { emptyCode, signedOut, failed }

class LineLinkException implements Exception {
  const LineLinkException(this.reason);
  final LineLinkError reason;
  @override
  String toString() => 'LineLinkException(${reason.name})';
}
