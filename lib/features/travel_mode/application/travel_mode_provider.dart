import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/trip.dart';
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

  void createTrip(Trip trip) {
    // Pick standard default exchange rates to feel realistic
    double rate = 1.0;
    if (trip.homeCurrency == 'USD') {
      rate = switch (trip.localCurrency) {
        'EUR' => 0.92,
        'JPY' => 156.40,
        'GBP' => 0.79,
        'CAD' => 1.36,
        'AUD' => 1.50,
        _ => 1.0,
      };
    } else if (trip.homeCurrency == 'THB') {
      rate = switch (trip.localCurrency) {
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
    state = TravelState(activeTrip: trip, exchangeRate: rate);
  }

  void updateExchangeRate(double newRate) {
    state = state.copyWith(exchangeRate: newRate);
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
