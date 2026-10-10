import '../../../core/money/money.dart';
import '../../dashboard/application/dashboard_summary_builder.dart';
import '../domain/investment_holding.dart';

/// Holdings re-priced into one currency so totals and allocation can add them
/// up. [excludedCurrencies] lists currencies with no rate; their holdings are
/// left out of [holdings] (the screen says so).
typedef PortfolioValuation = ({
  String currency,
  List<InvestmentHolding> holdings,
  Set<String> excludedCurrencies,
});

/// Re-prices [holdings] into the converter's base currency.
PortfolioValuation valueHoldingsIn(
  List<InvestmentHolding> holdings,
  CurrencyConverter converter,
) {
  final base = converter.baseCurrency;
  final valued = <InvestmentHolding>[];
  final excluded = <String>{};
  for (final holding in holdings) {
    if (holding.currency.toUpperCase() == base) {
      valued.add(holding);
      continue;
    }
    final price = converter.toBase(holding.currentPrice);
    final cost = converter.toBase(holding.averageCost);
    if (price == null || cost == null) {
      excluded.add(holding.currency.toUpperCase());
      continue;
    }
    valued.add(
      holding.copyWith(
        currentPrice: Money(amount: price, currency: base),
        averageCost: Money(amount: cost, currency: base),
      ),
    );
  }
  return (currency: base, holdings: valued, excludedCurrencies: excluded);
}
