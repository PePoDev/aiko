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
}
