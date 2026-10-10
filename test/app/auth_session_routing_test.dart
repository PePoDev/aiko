import 'package:aiko/app/aiko_app.dart';
import 'package:aiko/app/firebase_sync.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('signedOutRedirect', () {
    test('leaves signed-in screens for login when the account is known', () {
      expect(signedOutRedirect('/home', hasKnownAccount: true), '/auth');
      expect(signedOutRedirect('/profile', hasKnownAccount: true), '/auth');
    });

    test('leaves signed-in screens for Welcome otherwise', () {
      expect(signedOutRedirect('/transactions', hasKnownAccount: false), '/');
    });

    test('stays on Welcome and the login screen', () {
      expect(signedOutRedirect('/', hasKnownAccount: true), isNull);
      expect(signedOutRedirect('/auth', hasKnownAccount: false), isNull);
    });
  });

  group('authEventChangesUser', () {
    test('the first event repeating the startup user changes nothing', () {
      expect(
        authEventChangesUser(
          isFirstEvent: true,
          startupUid: 'a',
          eventUid: 'a',
        ),
        isFalse,
      );
      expect(
        authEventChangesUser(
          isFirstEvent: true,
          startupUid: null,
          eventUid: null,
        ),
        isFalse,
      );
    });

    test('a first event with another user is a change', () {
      expect(
        authEventChangesUser(
          isFirstEvent: true,
          startupUid: 'a',
          eventUid: null,
        ),
        isTrue,
      );
      expect(
        authEventChangesUser(
          isFirstEvent: true,
          startupUid: null,
          eventUid: 'b',
        ),
        isTrue,
      );
    });

    test('later events are sign-ins and sign-outs', () {
      expect(
        authEventChangesUser(
          isFirstEvent: false,
          startupUid: 'a',
          eventUid: 'a',
        ),
        isTrue,
      );
    });
  });

  group('FirebaseSyncPause', () {
    test('pauses refreshes only while the action runs', () async {
      expect(FirebaseSyncPause.isPaused, isFalse);
      final result = await FirebaseSyncPause.during(() async {
        expect(FirebaseSyncPause.isPaused, isTrue);
        return 42;
      });
      expect(result, 42);
      expect(FirebaseSyncPause.isPaused, isFalse);
    });

    test('resumes after the action fails', () async {
      await expectLater(
        FirebaseSyncPause.during<void>(() async => throw StateError('boom')),
        throwsStateError,
      );
      expect(FirebaseSyncPause.isPaused, isFalse);
    });
  });
}
