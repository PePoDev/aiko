import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/l10n.dart';

/// The small print under totals that add up other currencies: what was left
/// out because there is no exchange rate at all, and, when the rates saved
/// on the device were used (offline), how old they are.
class FxRatesNote extends StatelessWidget {
  const FxRatesNote({
    this.excludedCurrencies = const {},
    this.leftOutHoldings = const [],
    this.ratesAsOf,
    super.key,
  });

  /// Currencies left out of the totals.
  final Set<String> excludedCurrencies;

  /// Holdings left out, named instead of [excludedCurrencies] when given
  /// (for example "AAPL (USD)").
  final List<String> leftOutHoldings;

  /// When the saved rates were used, the time they were fetched.
  final DateTime? ratesAsOf;

  /// Whether there is anything to say.
  static bool applies({
    Set<String> excludedCurrencies = const {},
    List<String> leftOutHoldings = const [],
    DateTime? ratesAsOf,
  }) =>
      excludedCurrencies.isNotEmpty ||
      leftOutHoldings.isNotEmpty ||
      ratesAsOf != null;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final style = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final asOf = ratesAsOf;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (leftOutHoldings.isNotEmpty)
          Text(
            l10n.netHoldingsLeftOut(leftOutHoldings.join(', ')),
            style: style,
          )
        else if (excludedCurrencies.isNotEmpty)
          Text(
            l10n.dashExcludedCurrencies(
              (excludedCurrencies.toList()..sort()).join(', '),
            ),
            style: style,
          ),
        if (asOf != null)
          Text(l10n.netRatesAsOf(ratesAsOfLabel(asOf)), style: style),
      ],
    );
  }
}

/// [time] as the "Rates as of …" note shows it, in the app's language.
String ratesAsOfLabel(DateTime time) =>
    DateFormat.yMMMd().add_Hm().format(time.toLocal());
