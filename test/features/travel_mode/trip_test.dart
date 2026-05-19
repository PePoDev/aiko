import 'package:aiko/core/money/money.dart';
import 'package:aiko/features/travel_mode/application/travel_mode_service.dart';
import 'package:aiko/features/travel_mode/domain/trip.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('totals foreign transaction fees', () {
    final trip = Trip(
      name: 'Tokyo',
      homeCurrency: 'USD',
      localCurrency: 'JPY',
      budget: Money.parse('1000', 'USD'),
      foreignFees: [Money.parse('2', 'USD'), Money.parse('3', 'USD')],
    );

    expect(
      const TravelModeService().totalForeignFees(trip).amount.toString(),
      '5',
    );
  });
}
