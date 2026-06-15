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
  String format({String? locale}) {
    final formatter = NumberFormat.simpleCurrency(
      locale: locale,
      name: currency,
    );
    return formatter.format(amount.toDouble());
  }
}
