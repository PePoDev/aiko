import 'package:aiko/features/settings/data/line_link_repository.dart';
import 'package:aiko/core/storage/device_values.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  test('maps redeemLinePairing error codes to distinct reasons', () {
    expect(lineLinkErrorForCode('not-found'), LineLinkError.expiredCode);
    expect(lineLinkErrorForCode('invalid-argument'), LineLinkError.invalidCode);
    expect(lineLinkErrorForCode('already-exists'), LineLinkError.alreadyLinked);
    expect(
      lineLinkErrorForCode('resource-exhausted'),
      LineLinkError.tooManyAttempts,
    );
    expect(lineLinkErrorForCode('unauthenticated'), LineLinkError.signedOut);
    expect(lineLinkErrorForCode('internal'), LineLinkError.failed);
    expect(lineLinkErrorForCode('unavailable'), LineLinkError.failed);
  });

  test('code characters match the bot alphabet (no I, L, O, 0 or 1)', () {
    const alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
    for (final char in alphabet.split('')) {
      expect(linePairingCodeCharacter.hasMatch(char), isTrue, reason: char);
    }
    for (final char in ['I', 'L', 'O', '0', '1', 'a', '-', ' ']) {
      expect(linePairingCodeCharacter.hasMatch(char), isFalse, reason: char);
    }
  });

  group('connectWithCode', () {
    const repository = LineLinkRepository();

    Future<LineLinkError> reasonFor(String code) async {
      try {
        await repository.connectWithCode(code);
      } on LineLinkException catch (error) {
        return error.reason;
      }
      fail('expected a LineLinkException');
    }

    test('rejects an empty code', () async {
      expect(await reasonFor('  '), LineLinkError.emptyCode);
    });

    test('rejects malformed codes before calling the server', () async {
      expect(await reasonFor('K7M2Q'), LineLinkError.invalidCode);
      expect(await reasonFor('K7M2QPX'), LineLinkError.invalidCode);
      expect(await reasonFor('K7M2Q0'), LineLinkError.invalidCode);
    });

    test('a well-formed code needs a signed-in user', () async {
      expect(await reasonFor(' k7m2qp '), LineLinkError.signedOut);
    });
  });

  group('offline', () {
    test('a failed pairing call without a connection says offline', () {
      expect(
        lineLinkErrorFor(
          FirebaseFunctionsException(
            code: 'unavailable',
            message: 'UNAVAILABLE',
          ),
        ),
        LineLinkError.offline,
      );
      expect(
        lineLinkErrorFor(http.ClientException('Failed to fetch')),
        LineLinkError.offline,
      );
      expect(
        lineLinkErrorFor(
          FirebaseFunctionsException(
            code: 'not-found',
            message: 'Code is invalid or expired.',
          ),
        ),
        LineLinkError.expiredCode,
      );
      expect(lineLinkErrorFor(StateError('bug')), LineLinkError.failed);
    });

    test('the last known status is used when the read fails', () async {
      final device = MemoryDeviceValues();
      final repository = LineLinkRepository(device: device);

      // Never seen on this device: unknown, never "Connect LINE".
      expect(
        await repository.statusFrom('u1', () async => throw StateError('x')),
        LineLinkStatus.unknown,
      );

      expect(
        await repository.statusFrom('u1', () async => true),
        LineLinkStatus.linked,
      );
      expect(
        await repository.statusFrom(
          'u1',
          () async => throw FirebaseException(
            plugin: 'cloud_firestore',
            code: 'unavailable',
          ),
        ),
        LineLinkStatus.linked,
      );

      // Per user.
      expect(
        await repository.statusFrom('u2', () async => throw StateError('x')),
        LineLinkStatus.unknown,
      );
    });
  });
}
