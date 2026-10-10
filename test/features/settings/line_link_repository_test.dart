import 'package:aiko/features/settings/data/line_link_repository.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
