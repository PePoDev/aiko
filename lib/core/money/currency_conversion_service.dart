import 'exchange_rate.dart';
import 'money.dart';

class CurrencyConversionService {
  const CurrencyConversionService({this.rates = const []});

  final List<ExchangeRate> rates;

  Money convert(Money money, String targetCurrency) {
    final normalizedTarget = targetCurrency.toUpperCase();
    if (money.currency == normalizedTarget) {
      return money;
    }

    ExchangeRate? rate;
    for (final candidate in rates) {
      if (candidate.matches(money.currency, normalizedTarget)) {
        rate = candidate;
        break;
      }
    }

    if (rate == null) {
      throw ArgumentError(
        'Missing exchange rate: ${money.currency} -> $normalizedTarget',
      );
    }

    return Money(amount: money.amount * rate.rate, currency: normalizedTarget);
  }

  Money sumAs(Iterable<Money> values, String targetCurrency) {
    return values.fold(
      Money.zero(targetCurrency),
      (total, item) => total + convert(item, targetCurrency),
    );
  }
}
