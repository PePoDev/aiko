import 'package:aiko/core/money/money.dart';
import 'package:aiko/core/money/supported_currencies.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MoneyFormatter.format', () {
    test('uses the currency of the receiver', () {
      final result = Money.parse('5', 'EUR').format();
      expect(result, contains('5'));
      expect(result, contains('€'));
    });

    test('honours an explicit locale', () {
      // The German formatting puts the currency symbol after the value and
      // uses '.' as thousands separator.
      final result = Money.parse('1234.5', 'EUR').format(locale: 'de_DE');
      expect(result, contains('1.234,50'));
      expect(result, contains('€'));
    });
  });

  group('kAikoSupportedCurrencies', () {
    test('contains the expected base currencies', () {
      expect(kAikoSupportedCurrencies, containsAll(['USD', 'EUR', 'THB']));
    });
  });
}
