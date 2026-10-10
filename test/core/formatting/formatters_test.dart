import 'package:aiko/core/money/money.dart';
import 'package:aiko/core/money/supported_currencies.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

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

    test('follows a change of the default locale', () {
      final previous = Intl.defaultLocale;
      addTearDown(() => Intl.defaultLocale = previous);
      final money = Money.parse('1234.5', 'EUR');

      Intl.defaultLocale = 'en_US';
      expect(money.format(), '€1,234.50');
      expect(money.format(), '€1,234.50');
      Intl.defaultLocale = 'de_DE';
      expect(money.format(), contains('1.234,50'));
      expect(Money.parse('2', 'USD').format(), contains('2,00'));
      Intl.defaultLocale = 'en_US';
      expect(money.format(), '€1,234.50');
    });
  });

  group('kAikoSupportedCurrencies', () {
    test('contains the expected base currencies', () {
      expect(kAikoSupportedCurrencies, containsAll(['USD', 'EUR', 'THB']));
    });
  });
}
