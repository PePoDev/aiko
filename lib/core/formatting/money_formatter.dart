import 'package:intl/intl.dart';

import '../money/money.dart';

/// Locale-aware formatting helpers for [Money]. The [Money] domain class
/// deliberately does not depend on `package:intl` — only the
/// presentation layer does. Use this extension from widgets / services that
/// already pull in `intl` for date / number formatting.
extension MoneyFormatter on Money {
  /// Format the amount using [NumberFormat.simpleCurrency]. The `name` is
  /// always [currency] so the formatter picks the matching symbol; pass
  /// [locale] to override the system locale (e.g. for tests).
  String format({String? locale}) =>
      _currencyFormat(locale, currency).format(amount.toDouble());
}

/// Building a [NumberFormat] parses locale data, and lists format many
/// amounts per frame, so formatters are reused. The key includes the
/// effective locale, so a language change (a new `Intl.defaultLocale`) gets
/// new formatters.
final _formats = <String, NumberFormat>{};

NumberFormat _currencyFormat(String? locale, String currency) {
  final key = '${locale ?? Intl.getCurrentLocale()}|$currency';
  final cached = _formats[key];
  if (cached != null) return cached;
  // Locales × currencies in use stay small; the bound only guards misuse.
  if (_formats.length >= 256) _formats.clear();
  return _formats[key] = NumberFormat.simpleCurrency(
    locale: locale,
    name: currency,
  );
}
