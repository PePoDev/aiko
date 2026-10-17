import 'dart:async';
import 'dart:convert';
import '../../../core/storage/secure_storage_service.dart';
import '../../../core/storage/synced_preferences.dart';
import '../../../core/offline/offline_store.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/trip.dart';
import '../../../app/providers.dart';

class TravelState {
  const TravelState({
    this.activeTrip,
    this.exchangeRate =
        1.0, // Mock exchange rate, e.g. 1 HomeCurrency = exchangeRate LocalCurrency
  });

  final Trip? activeTrip;
  final double exchangeRate;

  TravelState copyWith({
    Trip? activeTrip,
    double? exchangeRate,
    bool clearTrip = false,
  }) {
    return TravelState(
      activeTrip: clearTrip ? null : (activeTrip ?? this.activeTrip),
      exchangeRate: exchangeRate ?? this.exchangeRate,
    );
  }
}

final travelStorageProvider = Provider<SecureStorageService>(
  (ref) => SyncedPreferences(),
);
final storedTravelProvider = FutureProvider<TravelState>((ref) async {
  final raw = await ref.watch(travelStorageProvider).read('travel_mode_v1');
  if (raw == null) return const TravelState();
  final data = jsonDecode(raw) as Map<String, dynamic>;
  return TravelState(
    activeTrip: data['trip'] == null
        ? null
        : Trip.fromJson(Map<String, dynamic>.from(data['trip'] as Map)),
    exchangeRate: (data['rate'] as num).toDouble(),
  );
});

/// Where a new trip's starting rate came from.
enum TripRateSource {
  /// A live quote.
  live,

  /// The exchange rates saved on this device (offline).
  saved,

  /// The app's built-in reference table (offline, nothing saved).
  reference,

  /// Typed by the user.
  manual,
}

/// What [TravelModeNotifier.createTrip] did.
class TripStart {
  const TripStart(TripRateSource this.source, {this.savedAt});

  /// No rate is known for the pair: nothing was saved; ask the user for one.
  const TripStart.needsRate() : source = null, savedAt = null;

  final TripRateSource? source;

  /// For [TripRateSource.saved], when those rates were fetched.
  final DateTime? savedAt;

  bool get started => source != null;
}

class TravelModeNotifier extends Notifier<TravelState> {
  @override
  TravelState build() {
    ref.listen(storedTravelProvider, (previous, next) {
      if (next.hasValue) state = next.requireValue;
    });
    return ref.read(storedTravelProvider).asData?.value ?? const TravelState();
  }

  /// Starts and saves a trip. Its rate is [rate] when the user typed one;
  /// otherwise a live quote, else the rates saved on this device, else the
  /// built-in reference table. With none of those for the pair, nothing is
  /// saved and the result asks for a rate ([TripStart.needsRate]); the app
  /// never assumes 1. The trip counts as started only once it is saved: a
  /// failed save restores the previous state and throws. The home and local
  /// currencies must differ.
  Future<TripStart> createTrip(Trip trip, {double? rate}) async {
    if (trip.homeCurrency == trip.localCurrency) {
      throw ArgumentError.value(
        trip.localCurrency,
        'localCurrency',
        'Must differ from the home currency',
      );
    }
    if (rate != null && !(rate > 0 && rate.isFinite)) {
      throw ArgumentError.value(rate, 'rate', 'Must be a positive number');
    }
    // Let the stored trip load first, so it can't arrive late and replace
    // the new one. Offline it may not load at all; the new trip replaces it
    // anyway, so don't wait long.
    try {
      await ref
          .read(storedTravelProvider.future)
          .timeout(const Duration(seconds: 3));
    } catch (_) {}

    final double startRate;
    final TripStart start;
    if (rate != null) {
      startRate = rate;
      start = const TripStart(TripRateSource.manual);
    } else {
      final found = await _startingRate(trip.homeCurrency, trip.localCurrency);
      if (found == null) return const TripStart.needsRate();
      startRate = found.rate;
      start = found.start;
    }

    final previous = state;
    state = TravelState(activeTrip: trip, exchangeRate: startRate);
    try {
      await _write();
    } catch (_) {
      state = previous;
      rethrow;
    }
    return start;
  }

  Future<({double rate, TripStart start})?> _startingRate(
    String homeCurrency,
    String localCurrency,
  ) async {
    final quote = await ref
        .read(exchangeRateRepositoryProvider)
        .quote(homeCurrency, localCurrency);
    final rate = quote.rate;
    if (rate != null && rate > Decimal.zero) {
      return (
        rate: rate.toDouble(),
        start: quote.isLive
            ? const TripStart(TripRateSource.live)
            : TripStart(TripRateSource.saved, savedAt: quote.savedAt),
      );
    }
    final reference = travelReferenceRate(homeCurrency, localCurrency);
    if (reference == null) return null;
    return (rate: reference, start: const TripStart(TripRateSource.reference));
  }

  /// Fetches a live `1 home = rate local` quote for the active trip. Returns
  /// `true` when it updated; `false` on no trip or a failed lookup (the last
  /// known rate is kept).
  Future<bool> refreshRate() async {
    final trip = state.activeTrip;
    if (trip == null) return false;
    final quote = await ref
        .read(exchangeRateRepositoryProvider)
        .quote(trip.homeCurrency, trip.localCurrency, forceLive: true);
    final rate = quote.rate;
    if (!quote.isLive || rate == null || rate <= Decimal.zero) return false;
    state = state.copyWith(exchangeRate: rate.toDouble());
    await _persist();
    return true;
  }

  /// Sets a user-entered rate. Pass `persist: false` while the user is still
  /// typing so only the final value is saved (and synced).
  void updateExchangeRate(double newRate, {bool persist = true}) {
    if (!(newRate > 0) || !newRate.isFinite) return;
    if (newRate != state.exchangeRate) {
      state = state.copyWith(exchangeRate: newRate);
    }
    if (persist) unawaited(_persist());
  }

  void addForeignFee(TravelFee fee) {
    if (state.activeTrip == null) return;
    final currentFees = [...state.activeTrip!.foreignFees, fee];
    final updatedTrip = state.activeTrip!.copyWith(foreignFees: currentFees);
    state = state.copyWith(activeTrip: updatedTrip);
    unawaited(_persist());
  }

  /// Saves in the background; a failure shows the sync-failed message.
  Future<void> _persist() async {
    try {
      await _write();
    } catch (error) {
      OfflineStore.errors.add(error);
    }
  }

  Future<void> _write() => ref
      .read(travelStorageProvider)
      .write(
        'travel_mode_v1',
        jsonEncode({
          'trip': state.activeTrip?.toJson(),
          'rate': state.exchangeRate,
        }),
      );

  void resetTrip() {
    state = state.copyWith(clearTrip: true, exchangeRate: 1.0);
    unawaited(_persist());
  }
}

/// Built-in reference rates (`1 home = rate local`) for starting a trip with
/// no network and no saved rates; either direction of a listed pair works.
/// Null for any other pair: the user is asked instead of assuming 1.
@visibleForTesting
double? travelReferenceRate(String homeCurrency, String localCurrency) {
  final home = homeCurrency.toUpperCase();
  final local = localCurrency.toUpperCase();
  final direct = _referenceRates[home]?[local];
  if (direct != null) return direct;
  final inverse = _referenceRates[local]?[home];
  return inverse == null ? null : 1 / inverse;
}

const _referenceRates = <String, Map<String, double>>{
  'USD': {'EUR': 0.92, 'JPY': 156.40, 'GBP': 0.79, 'CAD': 1.36, 'AUD': 1.50},
  'THB': {
    'USD': 0.027,
    'EUR': 0.025,
    'JPY': 4.30,
    'GBP': 0.021,
    'CAD': 0.037,
    'AUD': 0.041,
    'SGD': 0.036,
  },
};

final travelModeProvider = NotifierProvider<TravelModeNotifier, TravelState>(
  () {
    return TravelModeNotifier();
  },
);
