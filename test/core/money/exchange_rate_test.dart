import 'package:aiko/core/money/currency_conversion_service.dart';
import 'package:aiko/core/money/exchange_rate.dart';
import 'package:aiko/core/money/money.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('converts money with manual exchange rates', () {
    final service = CurrencyConversionService(
      rates: [
        ExchangeRate.manual(
          fromCurrency: 'EUR',
          toCurrency: 'USD',
          rate: '1.10',
          effectiveAt: DateTime(2026, 5, 19),
        ),
      ],
    );

    final converted = service.convert(Money.parse('10', 'EUR'), 'USD');

    expect(converted.currency, 'USD');
    expect(converted.amount.toString(), '11');
  });

  test('rejects missing cross-currency rate', () {
    const service = CurrencyConversionService();

    expect(
      () => service.convert(Money.parse('10', 'EUR'), 'USD'),
      throwsArgumentError,
    );
  });
}
