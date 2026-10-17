import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the device has a network connection, as the platform reports it
/// (connectivity_plus: the active interfaces on Android and iOS,
/// `navigator.onLine` on the web). A connection doesn't promise the internet
/// is reachable, but no connection means it isn't.
abstract interface class NetworkMonitor {
  /// Whether the device has a connection now.
  Future<bool> isOnline();

  /// Every change of [isOnline].
  Stream<bool> get onlineChanges;
}

/// [NetworkMonitor] over connectivity_plus. When the platform can't say
/// (plugin missing, error), the device counts as online, so nothing is
/// skipped for a status that isn't known.
class PlatformNetworkMonitor implements NetworkMonitor {
  const PlatformNetworkMonitor();

  @override
  Future<bool> isOnline() async {
    try {
      return hasConnection(await Connectivity().checkConnectivity());
    } catch (_) {
      return true;
    }
  }

  @override
  Stream<bool> get onlineChanges {
    try {
      return Connectivity().onConnectivityChanged
          .map(hasConnection)
          .handleError((Object _) {});
    } catch (_) {
      return const Stream.empty();
    }
  }
}

/// Whether [results] include any connection; connectivity_plus reports
/// [ConnectivityResult.none] alone when there is none.
bool hasConnection(List<ConnectivityResult> results) =>
    results.any((result) => result != ConnectivityResult.none);

/// The device's [NetworkMonitor]; overridden in tests.
final networkMonitorProvider = Provider<NetworkMonitor>(
  (ref) => const PlatformNetworkMonitor(),
);

/// Whether the device has a network connection; updates as it changes.
final deviceOnlineProvider = StreamProvider<bool>((ref) async* {
  final monitor = ref.watch(networkMonitorProvider);
  final changes = monitor.onlineChanges;
  yield await monitor.isOnline();
  yield* changes;
}, retry: (_, _) => null);
