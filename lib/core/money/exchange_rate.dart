import 'package:decimal/decimal.dart';

class ExchangeRate {
  ExchangeRate({
    required this.fromCurrency,
    required this.toCurrency,
    required this.rate,
    required this.effectiveAt,
    this.source = 'manual',
  }) : assert(fromCurrency.length == 3),
       assert(toCurrency.length == 3);

  factory ExchangeRate.manual({
    required String fromCurrency,
    required String toCurrency,
    required String rate,
    required DateTime effectiveAt,
  }) {
    return ExchangeRate(
      fromCurrency: fromCurrency.toUpperCase(),
      toCurrency: toCurrency.toUpperCase(),
      rate: Decimal.parse(rate),
      effectiveAt: effectiveAt,
    );
  }

  final String fromCurrency;
  final String toCurrency;
  final Decimal rate;
  final DateTime effectiveAt;
  final String source;

  bool matches(String from, String to) {
    return fromCurrency == from.toUpperCase() && toCurrency == to.toUpperCase();
  }
}
