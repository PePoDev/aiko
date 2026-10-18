import 'dart:async';

import 'package:aiko/app/startup_guard.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const timeout = Duration(milliseconds: 20);

  test('completes when startup completes', () async {
    var calls = 0;
    final guard = StartupGuard(() async => calls++, timeout: timeout);
    await guard.run();
    expect(calls, 1);
    expect(guard.running, isNull);
  });

  test('times out, then joins the running attempt instead of starting '
      'another', () async {
    var calls = 0;
    final startup = Completer<void>();
    final guard = StartupGuard(() {
      calls++;
      return startup.future;
    }, timeout: timeout);

    await expectLater(guard.run(), throwsA(isA<TimeoutException>()));
    expect(guard.running, isNotNull);
    await expectLater(guard.run(), throwsA(isA<TimeoutException>()));
    expect(calls, 1);

    startup.complete();
    await guard.running;
    expect(guard.running, isNull);
    await guard.run();
    expect(calls, 1);
  });

  test('starts over after a failed attempt', () async {
    var calls = 0;
    final guard = StartupGuard(() async {
      if (++calls == 1) throw StateError('database locked');
    }, timeout: timeout);

    await expectLater(guard.run(), throwsStateError);
    expect(guard.running, isNull);
    await guard.run();
    expect(calls, 2);
  });

  test('starts over after an attempt that failed late', () async {
    var calls = 0;
    final first = Completer<void>();
    final guard = StartupGuard(() {
      return ++calls == 1 ? first.future : Future<void>.value();
    }, timeout: timeout);

    await expectLater(guard.run(), throwsA(isA<TimeoutException>()));
    first.completeError(StateError('download failed'));
    await pumpEventQueue();
    expect(guard.running, isNull);
    await guard.run();
    expect(calls, 2);
  });

  test('treats a synchronous throw as a failed attempt', () async {
    var calls = 0;
    final guard = StartupGuard(() {
      if (++calls == 1) throw StateError('no config');
      return Future<void>.value();
    }, timeout: timeout);

    await expectLater(guard.run(), throwsStateError);
    await guard.run();
    expect(calls, 2);
  });

  test(
    'reports an error that comes after the timeout, and only that one',
    () async {
      final errors = <Object>[];
      final first = Completer<void>();
      var calls = 0;
      final guard = StartupGuard(
        () {
          calls++;
          if (calls == 1) return first.future;
          throw StateError('fails right away');
        },
        timeout: timeout,
        onLateError: (error, _) => errors.add(error),
      );

      await expectLater(guard.run(), throwsA(isA<TimeoutException>()));
      first.completeError(StateError('disk full'));
      await pumpEventQueue();
      expect(errors, [
        isA<StateError>().having((e) => e.message, 'message', 'disk full'),
      ]);

      // Thrown to the caller instead.
      await expectLater(guard.run(), throwsStateError);
      expect(errors, hasLength(1));
    },
  );

  group('waitUnlessStuck', () {
    const stuckAfter = Duration(milliseconds: 150);

    test('returns right away when nothing is running', () async {
      final guard = StartupGuard(() async {}, timeout: timeout);
      await guard.waitUnlessStuck();
      expect(guard.done, isFalse);
      await guard.run();
      await guard.waitUnlessStuck();
      expect(guard.done, isTrue);
    });

    test('waits for a slow attempt that finishes', () async {
      final startup = Completer<void>();
      final guard = StartupGuard(
        () => startup.future,
        timeout: timeout,
        stuckAfter: stuckAfter,
      );
      await expectLater(guard.run(), throwsA(isA<TimeoutException>()));

      final waiting = guard.waitUnlessStuck();
      startup.complete();
      await waiting;
      expect(guard.done, isTrue);
      expect(guard.running, isNull);
      await guard.run();
    });

    test('waits for a slow attempt that fails, which a run restarts', () async {
      var calls = 0;
      final first = Completer<void>();
      final guard = StartupGuard(
        () => ++calls == 1 ? first.future : Future<void>.value(),
        timeout: timeout,
        stuckAfter: stuckAfter,
        onLateError: (_, _) {},
      );
      await expectLater(guard.run(), throwsA(isA<TimeoutException>()));

      final waiting = guard.waitUnlessStuck();
      first.completeError(StateError('download failed'));
      await waiting;
      expect(guard.done, isFalse);
      expect(guard.running, isNull);
      await guard.run();
      expect(calls, 2);
      expect(guard.done, isTrue);
    });

    test('gives up once the attempt has run for stuckAfter in all', () async {
      final guard = StartupGuard(
        () => Completer<void>().future,
        timeout: timeout,
        stuckAfter: stuckAfter,
      );
      final started = Stopwatch()..start();
      await expectLater(guard.run(), throwsA(isA<TimeoutException>()));

      await guard.waitUnlessStuck();
      // Measured from the start of the attempt, not from the call.
      expect(started.elapsed, greaterThanOrEqualTo(stuckAfter));
      expect(started.elapsed, lessThan(stuckAfter * 3));
      expect(guard.done, isFalse);
      expect(guard.running, isNotNull);
      final again = Stopwatch()..start();
      await guard.waitUnlessStuck();
      expect(again.elapsed, lessThan(stuckAfter));
    });
  });
}
