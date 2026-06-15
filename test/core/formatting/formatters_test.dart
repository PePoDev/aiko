import 'package:aiko/core/formatting/formatters.dart';
import 'package:aiko/core/money/money.dart';
import 'package:aiko/core/money/supported_currencies.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AikoFormatters.money', () {
    test('zero USD formats as the zero amount', () {
      expect(AikoFormatters.money(Money.zero('USD')), contains('0.00'));
    });

    test('positive amount formats with currency symbol', () {
      final result = AikoFormatters.money(Money.parse('1234.56', 'USD'));
      // Default locale uses the en_US grouping and the "$" symbol.
      expect(result, contains('1,234.56'));
      expect(result, contains(r'$'));
    });
  });

  group('AikoFormatters.percentValue', () {
    test('whole number is followed by %', () {
      expect(AikoFormatters.percentValue(0), '0%');
      expect(AikoFormatters.percentValue(50), '50%');
      expect(AikoFormatters.percentValue(100), '100%');
    });

    test('fractional value is rounded to a whole number', () {
      expect(AikoFormatters.percentValue(33.4), '33%');
      expect(AikoFormatters.percentValue(66.6), '67%');
    });
  });

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
