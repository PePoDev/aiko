import 'package:decimal/decimal.dart';
import 'package:intl/intl.dart';

import '../../../core/money/money.dart';
import '../domain/trip.dart';

/// A trip's spending at a rate of `1 home = rate local`.
class TripSpending {
  const TripSpending({
    required this.spentHome,
    required this.remainingHome,
    required this.remainingLocal,
    required this.spentRatio,
  });

  /// Local fees converted to the home currency plus fees charged in it.
  final Money spentHome;

  /// Budget left in the home currency, never below zero.
  final Money remainingHome;

  /// [remainingHome] in the local currency.
  final Money remainingLocal;

  /// Share of the budget spent (above 1 when over budget).
  final double spentRatio;
}

Decimal _decimalRate(double rate) => Decimal.parse(rate.toString());

/// [local] converted to [homeCurrency] at `1 home = rate local`.
Money localToHome(Money local, double rate, String homeCurrency) {
  if (rate <= 0) {
    throw ArgumentError.value(rate, 'rate', 'Rate must be positive');
  }
  return Money(
    amount: (local.amount / _decimalRate(rate)).toDecimal(
      scaleOnInfinitePrecision: 10,
    ),
    currency: homeCurrency,
  );
}

/// [home] converted to [localCurrency] at `1 home = rate local`.
Money homeToLocal(Money home, double rate, String localCurrency) =>
    Money(amount: home.amount * _decimalRate(rate), currency: localCurrency);

TripSpending tripSpending(Trip trip, double rate) {
  var spent = Money.zero(trip.homeCurrency);
  for (final fee in trip.foreignFees) {
    if (fee.currency == trip.homeCurrency) {
      spent += fee.amount;
    } else if (fee.currency == trip.localCurrency && rate > 0) {
      spent += localToHome(fee.amount, rate, trip.homeCurrency);
    }
  }
  final budget = trip.budget;
  final left = budget - spent;
  final remaining = left.isNegative ? Money.zero(trip.homeCurrency) : left;
  return TripSpending(
    spentHome: spent,
    remainingHome: remaining,
    remainingLocal: rate > 0
        ? homeToLocal(remaining, rate, trip.localCurrency)
        : Money.zero(trip.localCurrency),
    spentRatio: budget.isPositive ? spent.ratio(budget) : 0,
  );
}

/// An exchange rate with up to 4 significant digits (0.02734, 4.3, 156.4);
/// rates of 1,000 and above keep their whole part (16,230).
String formatRate(double rate, {String? locale}) {
  final format = NumberFormat.decimalPattern(locale);
  if (rate.abs() >= 1000) {
    format.maximumFractionDigits = 0;
  } else {
    format
      ..significantDigitsInUse = true
      ..minimumSignificantDigits = 1
      ..maximumSignificantDigits = 4;
  }
  return format.format(rate);
}
