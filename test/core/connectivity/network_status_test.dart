import 'dart:async';

import 'package:aiko/core/connectivity/network_status.dart';
import 'package:aiko/features/settings/data/line_link_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeMonitor implements NetworkMonitor {
  _FakeMonitor(this.online);

  final bool online;
  final _changes = StreamController<bool>.broadcast();

  void set(bool value) => _changes.add(value);

  Future<void> close() => _changes.close();

  @override
  Future<bool> isOnline() async => online;

  @override
  Stream<bool> get onlineChanges => _changes.stream;
}

void main() {
  group('refreshWhenBackOnline', () {
    late _FakeMonitor monitor;
    late ProviderContainer container;
    late int builds;
    late Provider<int> probe;

    void start({required bool online}) {
      monitor = _FakeMonitor(online);
      container = ProviderContainer(
        overrides: [networkMonitorProvider.overrideWithValue(monitor)],
      );
      builds = 0;
      probe = Provider<int>((ref) {
        refreshWhenBackOnline(ref);
        return ++builds;
      });
      container.listen(probe, (_, _) {});
    }

    tearDown(() async {
      container.dispose();
      await monitor.close();
    });

    test('builds again when the device comes back online', () async {
      start(online: false);
      await pumpEventQueue();
      expect(builds, 1);

      monitor.set(true);
      await pumpEventQueue();
      expect(container.read(probe), 2);
    });

    test('not when the status is first known, nor when going offline or '
        'staying online', () async {
      start(online: true);
      await pumpEventQueue();
      monitor.set(true);
      await pumpEventQueue();
      monitor.set(false);
      await pumpEventQueue();

      expect(container.read(probe), 1);
    });
  });

  test('the LINE status is checked again when the device is back online '
      '(it may be unknown offline)', () async {
    final monitor = _FakeMonitor(false);
    final container = ProviderContainer(
      overrides: [networkMonitorProvider.overrideWithValue(monitor)],
    );
    addTearDown(() async {
      container.dispose();
      await monitor.close();
    });
    final states = <AsyncValue<LineLinkStatus>>[];
    container.listen(
      lineLinkedProvider,
      (_, next) => states.add(next),
      fireImmediately: true,
    );
    await pumpEventQueue();
    // Signed out in tests: "not linked" without asking anyone.
    expect(states.last.value, LineLinkStatus.notLinked);
    final checks = states.where((state) => state.isLoading).length;

    monitor.set(true);
    await pumpEventQueue();
    container.read(lineLinkedProvider);
    await pumpEventQueue();

    expect(states.where((state) => state.isLoading).length, checks + 1);
    expect(states.last.value, LineLinkStatus.notLinked);
  });
}
