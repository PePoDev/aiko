import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/money/exchange_rate_repository.dart';
import '../core/money/exchange_rates.dart';
import '../core/storage/device_values.dart';
import 'providers.dart' show exchangeRateServiceProvider;

/// The rates saved on this device; overridden in tests through
/// [deviceValuesProvider].
final exchangeRateCacheProvider = Provider<ExchangeRateCache>(
  (ref) => ExchangeRateCache(ref.watch(deviceValuesProvider)),
);

/// Live rates with the saved copy as fallback, shared by the totals, the
/// transaction form and Travel Mode.
final exchangeRateRepositoryProvider = Provider<ExchangeRateRepository>(
  (ref) => ExchangeRateRepository(
    service: ref.watch(exchangeRateServiceProvider),
    cache: ref.watch(exchangeRateCacheProvider),
  ),
);

/// Exchange rates quoted against a base currency, for totals that hold
/// amounts in other currencies (Overview, Investments, Asset Allocation, the
/// Ask Aiko snapshot).
///
/// The copy saved on the device is returned at once (its
/// [ExchangeRates.savedAsOf] makes screens say "Rates as of …") and refreshed
/// from the network in the background. With nothing saved, the first fetch
/// is awaited; when it fails the result is empty (callers leave unconverted
/// amounts out and say so), and it is fetched again: on the next read
/// ([FxRatesNotifier.retryIfStale]), on pull-to-refresh
/// ([FxRatesNotifier.refresh]) and on a backing-off timer, so a failed fetch
/// never sticks for the session.
final fxRatesProvider = AsyncNotifierProvider.autoDispose
    .family<FxRatesNotifier, ExchangeRates, String>(FxRatesNotifier.new);

class FxRatesNotifier extends AsyncNotifier<ExchangeRates> {
  FxRatesNotifier(String baseCurrency)
    : base = baseCurrency.trim().toUpperCase();

  final String base;

  /// A read retries a failed or saved-copy result at most this often.
  static const retryOnReadAfter = Duration(seconds: 15);

  /// Automatic retries after a failed fetch (about 18 minutes in all); after
  /// that only reads and pull-to-refresh retry.
  static const retryDelays = [
    Duration(seconds: 30),
    Duration(minutes: 1),
    Duration(minutes: 2),
    Duration(minutes: 5),
    Duration(minutes: 5),
    Duration(minutes: 5),
  ];

  Timer? _retryTimer;
  var _retries = 0;
  DateTime? _lastAttempt;
  Future<bool>? _refreshing;

  ExchangeRateRepository get _repository =>
      ref.read(exchangeRateRepositoryProvider);

  @override
  Future<ExchangeRates> build() async {
    // Rates are app-wide; keep them (and the retry timer) for the session.
    ref.keepAlive();
    ref.onDispose(() => _retryTimer?.cancel());

    final session = _repository.sessionRates(base);
    if (session != null) return session;
    final saved = await _repository.saved(base);
    if (saved != null && !saved.isEmpty) {
      // After build has returned, so the live result replaces the saved one.
      Timer.run(() {
        if (ref.mounted) unawaited(refresh());
      });
      return saved;
    }
    _lastAttempt = _repository.now();
    try {
      return await _repository.fetchLive(base);
    } catch (_) {
      _scheduleRetry();
      return ExchangeRates.none(base);
    }
  }

  /// Fetches live rates now (pull-to-refresh, back online). Returns whether
  /// they arrived; on failure the current rates stay.
  Future<bool> refresh() => _refreshing ??= _refresh().whenComplete(() {
    _refreshing = null;
  });

  Future<bool> _refresh() async {
    _lastAttempt = _repository.now();
    final ExchangeRates live;
    try {
      live = await _repository.fetchLive(base);
    } catch (_) {
      if (ref.mounted) _scheduleRetry();
      return false;
    }
    if (!ref.mounted) return true;
    _retryTimer?.cancel();
    _retries = 0;
    state = AsyncData(live);
    return true;
  }

  /// Callers that use the rates call this on every read: a result that is
  /// not live (failed, or the saved copy) is fetched again in the background,
  /// at most every [retryOnReadAfter]. The new rates arrive as a state change.
  void retryIfStale() {
    if (state.isLoading || _refreshing != null) return;
    if (state.value?.isLive ?? false) return;
    final last = _lastAttempt;
    if (last != null && _repository.now().difference(last) < retryOnReadAfter) {
      return;
    }
    unawaited(refresh());
  }

  void _scheduleRetry() {
    if ((_retryTimer?.isActive ?? false) || _retries >= retryDelays.length) {
      return;
    }
    _retryTimer = Timer(retryDelays[_retries++], () {
      if (ref.mounted) unawaited(refresh());
    });
  }
}
