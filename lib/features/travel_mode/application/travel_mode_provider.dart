import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/trip.dart';
import '../../../app/providers.dart';
import '../../../core/money/money.dart';

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

class TravelModeNotifier extends Notifier<TravelState> {
  @override
  TravelState build() {
    return const TravelState();
  }

  /// Starts a trip immediately with a sensible offline default rate, then
  /// refines it with a live quote when the network is available.
  Future<void> createTrip(Trip trip) async {
    state = TravelState(
      activeTrip: trip,
      exchangeRate: _fallbackRate(trip.homeCurrency, trip.localCurrency),
    );
    await refreshRate();
  }

  /// Fetches a live `1 home = rate local` quote for the active trip. Returns
  /// `true` when it updated; `false` on no trip or a failed lookup (the last
  /// known rate is kept).
  Future<bool> refreshRate() async {
    final trip = state.activeTrip;
    if (trip == null) return false;
    final rate = await ref
        .read(exchangeRateServiceProvider)
        .fetchRate(trip.homeCurrency, trip.localCurrency);
    if (rate == null) return false;
    state = state.copyWith(exchangeRate: rate.toDouble());
    return true;
  }

  void updateExchangeRate(double newRate) {
    state = state.copyWith(exchangeRate: newRate);
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

  void addForeignFee(Money fee) {
    if (state.activeTrip == null) return;
    final currentFees = [...state.activeTrip!.foreignFees, fee];
    final updatedTrip = state.activeTrip!.copyWith(foreignFees: currentFees);
    state = state.copyWith(activeTrip: updatedTrip);
  }

  void resetTrip() {
    state = state.copyWith(clearTrip: true, exchangeRate: 1.0);
  }
}

final travelModeProvider = NotifierProvider<TravelModeNotifier, TravelState>(
  () {
    return TravelModeNotifier();
  },
);
