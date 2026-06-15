import 'package:intl/intl.dart';

import '../money/money.dart';

export 'money_formatter.dart';

/// Shared, locale-aware formatters. Hoist `DateFormat` and
/// `NumberFormat` here as `static final` so hot widgets / services don't
/// allocate a new formatter on every build. Callers that need a
/// locale-specific variant should still construct their own (e.g. via
/// `DateFormat.yMMMd(locale)`) — these are the *defaults* the app falls
/// back to when the caller doesn't know the locale yet.
class AikoFormatters {
  const AikoFormatters._();

  // Date formatters. Read by dashboard, transaction list, insights, and
  // exports; allocating these on every build costs ~1ms per call.
  static final DateFormat dayMonth = DateFormat('EEE, MMM d');
  static final DateFormat dayMonthYear = DateFormat('EEE, MMM d, yyyy');
  static final DateFormat monthDay = DateFormat('MMM d');
  static final DateFormat isoDate = DateFormat('yyyy-MM-dd');
  static final DateFormat isoDateTime = DateFormat('yyyy-MM-dd HH:mm');

  // Number formatters.
  static final NumberFormat compactNumber = NumberFormat.compact();
  static final NumberFormat percentPattern = NumberFormat.percentPattern();

  static String money(Money value) => value.format();

  static String percentValue(num value) => '${value.toStringAsFixed(0)}%';
}
