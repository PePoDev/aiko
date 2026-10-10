import 'dart:async';
import 'dart:convert';
import '../../../core/storage/secure_storage_service.dart';
import '../../../core/storage/synced_preferences.dart';
import '../../../core/offline/offline_store.dart';
import 'package:decimal/decimal.dart';
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

class TravelModeNotifier extends Notifier<TravelState> {
  @override
  TravelState build() {
    ref.listen(storedTravelProvider, (previous, next) {
      if (next.hasValue) state = next.requireValue;
    });
    return ref.read(storedTravelProvider).asData?.value ?? const TravelState();
  }

  /// Starts a trip immediately with a sensible offline default rate, then
  /// refines it with a live quote when the network is available, and saves
  /// once. The home and local currencies must differ.
  Future<void> createTrip(Trip trip) async {
    if (trip.homeCurrency == trip.localCurrency) {
      throw ArgumentError.value(
        trip.localCurrency,
        'localCurrency',
        'Must differ from the home currency',
      );
    }
    await ref.read(storedTravelProvider.future);
    state = TravelState(
      activeTrip: trip,
      exchangeRate: _fallbackRate(trip.homeCurrency, trip.localCurrency),
    );
    await _fetchLiveRate();
    await _persist();
  }

  /// Fetches a live `1 home = rate local` quote for the active trip. Returns
  /// `true` when it updated; `false` on no trip or a failed lookup (the last
  /// known rate is kept).
  Future<bool> refreshRate() async {
    final updated = await _fetchLiveRate();
    if (updated) await _persist();
    return updated;
  }

  Future<bool> _fetchLiveRate() async {
    final trip = state.activeTrip;
    if (trip == null) return false;
    final rate = await ref
        .read(exchangeRateServiceProvider)
        .fetchRate(trip.homeCurrency, trip.localCurrency);
    if (rate == null || rate <= Decimal.zero) return false;
    state = state.copyWith(exchangeRate: rate.toDouble());
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

  /// Standard reference rates so a trip feels realistic offline / before the
  /// live quote arrives.
  double _fallbackRate(String homeCurrency, String localCurrency) {
    if (homeCurrency == 'USD') {
      return switch (localCurrency) {
        'EUR' => 0.92,
        'JPY' => 156.40,
        'GBP' => 0.79,
        'CAD' => 1.36,
        'AUD' => 1.50,
        _ => 1.0,
      };
    } else if (homeCurrency == 'THB') {
      return switch (localCurrency) {
        'USD' => 0.027,
        'EUR' => 0.025,
        'JPY' => 4.30,
        'GBP' => 0.021,
        'CAD' => 0.037,
        'AUD' => 0.041,
        'SGD' => 0.036,
        _ => 1.0,
      };
    }
    return 1.0;
  }

  void addForeignFee(TravelFee fee) {
    if (state.activeTrip == null) return;
    final currentFees = [...state.activeTrip!.foreignFees, fee];
    final updatedTrip = state.activeTrip!.copyWith(foreignFees: currentFees);
    state = state.copyWith(activeTrip: updatedTrip);
    unawaited(_persist());
  }

  Future<void> _persist() async {
    try {
      await ref
          .read(travelStorageProvider)
          .write(
            'travel_mode_v1',
            jsonEncode({
              'trip': state.activeTrip?.toJson(),
              'rate': state.exchangeRate,
            }),
          );
    } catch (error) {
      OfflineStore.errors.add(error);
    }
  }

  void resetTrip() {
    state = state.copyWith(clearTrip: true, exchangeRate: 1.0);
    unawaited(_persist());
  }
}

final travelModeProvider = NotifierProvider<TravelModeNotifier, TravelState>(
  () {
    return TravelModeNotifier();
  },
);
