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

    test('never moves a guest, who uses the app signed out', () {
      expect(
        signedOutRedirect('/home', hasKnownAccount: true, isGuest: true),
        isNull,
      );
      expect(
        signedOutRedirect(
          '/transactions',
          hasKnownAccount: false,
          isGuest: true,
        ),
        isNull,
      );
    });
  });

  group('initialAppLocation', () {
    test('cloud builds open on Welcome', () {
      expect(initialAppLocation(cloud: true, isGuest: false), '/');
    });

    test('guests and local-only builds open on Home', () {
      expect(initialAppLocation(cloud: true, isGuest: true), '/home');
      expect(initialAppLocation(cloud: false, isGuest: false), '/home');
    });
  });

  group('returningUserRedirect', () {
    String? redirect(
      String location, {
      bool signedIn = false,
      bool isGuest = false,
      bool hasKnownAccount = false,
    }) => returningUserRedirect(
      location,
      signedIn: signedIn,
      isGuest: isGuest,
      hasKnownAccount: hasKnownAccount,
    );

    test('a signed-in user goes Home from Welcome or the login screen', () {
      expect(redirect('/', signedIn: true), '/home');
      expect(redirect('/auth', signedIn: true), '/home');
    });

    test('a known account goes from Welcome to the login screen', () {
      expect(redirect('/', hasKnownAccount: true), '/auth');
      expect(redirect('/'), isNull);
    });

    test('a guest is never sent to the login screen', () {
      expect(redirect('/', isGuest: true, hasKnownAccount: true), '/home');
      // A guest on the login screen came there to sign in.
      expect(redirect('/auth', isGuest: true, hasKnownAccount: true), isNull);
    });

    test('screens inside the app are left alone', () {
      expect(redirect('/home', hasKnownAccount: true), isNull);
      expect(redirect('/profile', isGuest: true), isNull);
      expect(redirect('/settings', signedIn: true), isNull);
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
