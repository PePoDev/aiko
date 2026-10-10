import 'dart:math';

import '../../../core/money/money.dart';
import '../domain/investment_holding.dart';

/// One market quote: a symbol priced in a currency.
typedef QuoteKey = ({String symbol, String currency});

QuoteKey quoteKeyFor(InvestmentHolding holding) => (
  symbol: holding.symbol.trim().toUpperCase(),
  currency: holding.currency.toUpperCase(),
);

/// The distinct quotes [holdings] need, in first-seen order. Holdings with
/// the same symbol and currency share one call.
List<QuoteKey> uniqueQuoteKeys(Iterable<InvestmentHolding> holdings) => {
  for (final holding in holdings) quoteKeyFor(holding),
}.toList(growable: false);

/// What a price refresh did, counted in holdings, for the screen to report.
class PriceRefreshResult {
  const PriceRefreshResult({
    this.updated = 0,
    this.failed = 0,
    this.deferred = 0,
    this.needsCloud = false,
  });

  /// Live prices need the cloud backend, so nothing was tried.
  const PriceRefreshResult.needsCloud() : this(needsCloud: true);

  /// Holdings that got a fresh quote. Only those whose price changed are
  /// saved.
  final int updated;

  /// Holdings whose quote failed; they keep their last price.
  final int failed;

  /// Holdings left for a later refresh to stay within the market-data limit.
  final int deferred;

  final bool needsCloud;
}

/// Applies fetched [quotes] to [holdings]. A key mapped to null failed; a key
/// missing from [quotes] was not requested (deferred). Returns the holdings
/// whose price changed (the only ones worth saving) and the counts.
({List<InvestmentHolding> changed, PriceRefreshResult result}) applyQuotes(
  List<InvestmentHolding> holdings,
  Map<QuoteKey, Money?> quotes,
) {
  final changed = <InvestmentHolding>[];
  var updated = 0;
  var failed = 0;
  var deferred = 0;
  for (final holding in holdings) {
    final key = quoteKeyFor(holding);
    if (!quotes.containsKey(key)) {
      deferred++;
      continue;
    }
    final price = quotes[key];
    if (price == null) {
      failed++;
      continue;
    }
    updated++;
    if (price != holding.currentPrice) {
      changed.add(holding.copyWith(currentPrice: price));
    }
  }
  return (
    changed: changed,
    result: PriceRefreshResult(
      updated: updated,
      failed: failed,
      deferred: deferred,
    ),
  );
}

/// Client-side budget for the `marketFeed` function, which refuses more than
/// [maxCalls] calls per user per [window]. A refresh stops before the budget
/// runs out and leaves the remaining holdings for later.
class MarketQuoteLimiter {
  MarketQuoteLimiter({
    this.maxCalls = 30,
    this.window = const Duration(minutes: 1),
  });

  final int maxCalls;
  final Duration window;
  final _calls = <DateTime>[];

  /// Calls still allowed at [now] (a sliding window, at least as strict as
  /// the server's fixed one).
  int remaining(DateTime now) {
    _calls.removeWhere((call) => now.difference(call) >= window);
    return max(0, maxCalls - _calls.length);
  }

  void record(DateTime now) => _calls.add(now);
}
