import 'package:decimal/decimal.dart';
import 'package:intl/intl.dart';

class Money implements Comparable<Money> {
  Money({required this.amount, required this.currency})
    : assert(currency.length == 3, 'Currency must be ISO 4217-like');

  factory Money.zero(String currency) =>
      Money(amount: Decimal.zero, currency: currency.toUpperCase());

  factory Money.parse(String value, String currency) =>
      Money(amount: Decimal.parse(value), currency: currency.toUpperCase());

  final Decimal amount;
  final String currency;

  Money operator +(Money other) {
    _assertSameCurrency(other);
    return Money(amount: amount + other.amount, currency: currency);
  }

  Money operator -(Money other) {
    _assertSameCurrency(other);
    return Money(amount: amount - other.amount, currency: currency);
  }

  Money times(Decimal multiplier) {
    return Money(amount: amount * multiplier, currency: currency);
  }

  Money dividedByInt(int divisor, {int scale = 6}) {
    if (divisor == 0) {
      throw ArgumentError.value(divisor, 'divisor', 'Cannot divide by zero');
    }
    return Money(
      amount: (amount / Decimal.fromInt(divisor)).toDecimal(
        scaleOnInfinitePrecision: scale,
      ),
      currency: currency,
    );
  }

  bool get isNegative => amount < Decimal.zero;
  bool get isPositive => amount > Decimal.zero;

  String format({String? locale}) {
    final formatter = NumberFormat.simpleCurrency(
      locale: locale,
      name: currency,
    );
    return formatter.format(amount.toDouble());
  }

  Map<String, dynamic> toJson() => {
    'amount': amount.toString(),
    'currency': currency,
  };

  void _assertSameCurrency(Money other) {
    if (currency != other.currency) {
      throw ArgumentError('Currency mismatch: $currency != ${other.currency}');
    }
  }

  @override
  int compareTo(Money other) {
    _assertSameCurrency(other);
    return amount.compareTo(other.amount);
  }

  @override
  bool operator ==(Object other) {
    return other is Money &&
        other.amount == amount &&
        other.currency == currency;
  }

  @override
  int get hashCode => Object.hash(amount, currency);
}
