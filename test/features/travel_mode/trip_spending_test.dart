import 'package:aiko/core/money/money.dart';
import 'package:aiko/features/travel_mode/application/trip_spending.dart';
import 'package:aiko/features/travel_mode/domain/trip.dart';
import 'package:flutter_test/flutter_test.dart';

Trip _trip({List<TravelFee> fees = const []}) => Trip(
  name: 'Tokyo',
  homeCurrency: 'THB',
  localCurrency: 'JPY',
  budget: Money.parse('10000', 'THB'),
  foreignFees: fees,
);

void main() {
  group('tripSpending', () {
    test('converts local fees and adds home fees once', () {
      final spending = tripSpending(
        _trip(
          fees: [
            TravelFee(amount: Money.parse('4300', 'JPY')),
            TravelFee(amount: Money.parse('500', 'THB'), merchant: 'Hotel'),
          ],
        ),
        4.3,
      );
      expect(spending.spentHome, Money.parse('1500', 'THB'));
      expect(spending.remainingHome, Money.parse('8500', 'THB'));
      expect(spending.remainingLocal, Money.parse('36550', 'JPY'));
      expect(spending.spentRatio, closeTo(0.15, 1e-9));
    });

    test('keeps a THB to USD rate below 0.1', () {
      final trip = Trip(
        name: 'NYC',
        homeCurrency: 'THB',
        localCurrency: 'USD',
        budget: Money.parse('100000', 'THB'),
        foreignFees: [TravelFee(amount: Money.parse('27', 'USD'))],
      );
      final spending = tripSpending(trip, 0.027);
      expect(spending.spentHome, Money.parse('1000', 'THB'));
      expect(spending.remainingLocal, Money.parse('2673', 'USD'));
    });

    test('remaining budget stops at zero when over budget', () {
      final spending = tripSpending(
        _trip(fees: [TravelFee(amount: Money.parse('12000', 'THB'))]),
        4.3,
      );
      expect(spending.remainingHome, Money.zero('THB'));
      expect(spending.spentRatio, closeTo(1.2, 1e-9));
    });
  });

  group('formatRate', () {
    test('shows up to 4 significant digits', () {
      expect(formatRate(0.027345, locale: 'en'), '0.02735');
      expect(formatRate(0.021, locale: 'en'), '0.021');
      expect(formatRate(4.3, locale: 'en'), '4.3');
      expect(formatRate(156.4, locale: 'en'), '156.4');
      expect(formatRate(16234.4, locale: 'en'), '16,234');
    });
  });

  group('TravelFee json', () {
    test('keeps the merchant and reads fees saved without one', () {
      final fee = TravelFee(
        amount: Money.parse('12.5', 'JPY'),
        merchant: 'Ramen bar',
      );
      final restored = TravelFee.fromJson(fee.toJson());
      expect(restored.amount, fee.amount);
      expect(restored.merchant, 'Ramen bar');

      final legacy = TravelFee.fromJson({'amount': '3', 'currency': 'JPY'});
      expect(legacy.amount, Money.parse('3', 'JPY'));
      expect(legacy.merchant, isNull);
    });
  });
}
