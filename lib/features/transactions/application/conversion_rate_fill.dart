import 'package:decimal/decimal.dart';

import '../../../core/money/exchange_rates.dart';

/// How the transaction form shows one conversion leg's rate: the text in the
/// rate field and the note under it (null: nothing to explain).
typedef ConversionRateFill = ({String text, FxQuote? note});

/// The rate field after [quote] arrives for a leg showing [current].
///
/// - A live rate replaces whatever is there.
/// - A rate from the copy saved on the device only fills an empty field, and
///   the note says how old it is.
/// - With no rate at all the field stays as it is, so a new pair stays empty
///   (the form refuses to save without a rate) and the note says why. The
///   form never falls back to 1.
///
/// A refresh that fails keeps a rate the field already shows (typed by the
/// user, or fetched earlier).
///
/// The field keeps the rate's full precision, since the amount is converted
/// with it: 1 JPY = 0.004955 GBP rounded to 0.0050 would be 1% off.
ConversionRateFill fillConversionRate({
  required FxQuote quote,
  required ConversionRateFill current,
}) {
  final rate = quote.rate;
  if (rate != null && quote.isLive) {
    return (text: rate.toString(), note: null);
  }
  if (current.text.trim().isNotEmpty) return current;
  if (rate != null) return (text: rate.toString(), note: quote);
  return (text: '', note: quote);
}

/// [rate] for display: four decimals (36.5000), or four significant digits
/// for a rate below 1 (0.004955 rather than 0.0050).
String formatConversionRate(Decimal rate) =>
    rate >= Decimal.one || rate <= Decimal.zero
    ? rate.toStringAsFixed(4)
    : rate.toStringAsPrecision(4);

/// [amount] in the account's currency at [rate], rounded to cents like the
/// "Saves as" preview.
Decimal convertAtRate(Decimal amount, Decimal rate) =>
    (amount * rate).round(scale: 2);
