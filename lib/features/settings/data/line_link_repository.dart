import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/connectivity/network_status.dart';
import '../../../core/firebase/firebase_backend.dart';
import '../../../core/network/network_errors.dart';
import '../../../core/storage/device_values.dart';

/// Whether the signed-in user's LINE chat is linked. Disposed when no screen
/// shows it, and reset on sign-out (`invalidateUserSessionState`), so another
/// user never sees the previous user's status. Checked again when the device
/// comes back online (offline it is the last status seen, or unknown).
final lineLinkedProvider = FutureProvider.autoDispose<LineLinkStatus>((ref) {
  refreshWhenBackOnline(ref);
  return LineLinkRepository(device: ref.watch(deviceValuesProvider)).status();
});

/// What the Profile screen can say about LINE.
enum LineLinkStatus {
  linked,
  notLinked,

  /// Offline, and this device has never learned the status.
  unknown,
}

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
  const LineLinkRepository({DeviceValueStore? device}) : _device = device;

  final DeviceValueStore? _device;

  DeviceValueStore get _values => _device ?? const LocalDeviceValues();

  /// A status read or a pairing call that takes longer counts as offline.
  static const timeout = Duration(seconds: 15);

  static String _statusKey(String userId) => 'line_linked:$userId';

  /// Reads `integrations/line` (the server, or Firestore's cache offline).
  /// When neither has it, the status this device saw last is used, so an
  /// offline device never offers "Connect LINE" for a linked account; with
  /// no status at all it is [LineLinkStatus.unknown].
  Future<LineLinkStatus> status() async {
    final userId = FirebaseBackend.userId;
    if (userId == null) return LineLinkStatus.notLinked;
    return statusFrom(
      userId,
      () async => (await FirebaseBackend.collection(
        'integrations',
      ).doc('line').get()).exists,
    );
  }

  /// [status] with the read injected (tests).
  Future<LineLinkStatus> statusFrom(
    String userId,
    Future<bool> Function() readLinked,
  ) async {
    try {
      final linked = await readLinked().timeout(timeout);
      await _values.write(_statusKey(userId), '$linked');
      return linked ? LineLinkStatus.linked : LineLinkStatus.notLinked;
    } catch (_) {
      return switch (await _values.read(_statusKey(userId))) {
        'true' => LineLinkStatus.linked,
        'false' => LineLinkStatus.notLinked,
        _ => LineLinkStatus.unknown,
      };
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
      await FirebaseBackend.functions
          .httpsCallable(
            'redeemLinePairing',
            options: HttpsCallableOptions(timeout: timeout),
          )
          .call({'code': code})
          .timeout(timeout + const Duration(seconds: 5));
    } catch (error) {
      throw LineLinkException(lineLinkErrorFor(error));
    }
    await _values.write(_statusKey(FirebaseBackend.userId!), 'true');
  }
}

/// The reason for a failed `redeemLinePairing` call: no connection, or the
/// server's answer by its error code.
LineLinkError lineLinkErrorFor(Object error) {
  if (isNetworkError(error)) return LineLinkError.offline;
  if (error is FirebaseException) return lineLinkErrorForCode(error.code);
  return LineLinkError.failed;
}

enum LineLinkError {
  emptyCode,
  invalidCode,
  expiredCode,
  alreadyLinked,
  tooManyAttempts,
  signedOut,

  /// No connection, or no answer in time.
  offline,
  failed,
}

class LineLinkException implements Exception {
  const LineLinkException(this.reason);
  final LineLinkError reason;
  @override
  String toString() => 'LineLinkException(${reason.name})';
}
