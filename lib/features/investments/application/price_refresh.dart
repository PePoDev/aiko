import 'dart:math';

import 'package:firebase_core/firebase_core.dart';

import '../../../core/money/money.dart';
import '../../../core/network/network_errors.dart';
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
    this.offline = false,
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

  /// The refresh stopped because the server couldn't be reached; holdings
  /// not refreshed keep their last saved price (counted in [deferred]).
  final bool offline;
}

/// Requests the quotes for [keys] one at a time with [fetch], within
/// [limiter]'s budget. A key mapped to null failed; keys left out were not
/// requested. Stops at the server's own limit (`resource-exhausted`), and at
/// the first network failure: that call never reached the server, so it
/// gives its place in the budget back, and the rest would fail the same way.
Future<({Map<QuoteKey, Money?> quotes, bool offline})> fetchQuotes(
  List<QuoteKey> keys, {
  required Future<Money> Function(QuoteKey key) fetch,
  required MarketQuoteLimiter limiter,
  DateTime Function() clock = DateTime.now,
}) async {
  final quotes = <QuoteKey, Money?>{};
  for (final key in keys) {
    final now = clock();
    if (limiter.remaining(now) == 0) break;
    limiter.record(now);
    try {
      quotes[key] = await fetch(key);
    } catch (error) {
      // Over the server's limit anyway (e.g. another device): this and the
      // remaining quotes wait for a later refresh.
      if (error is FirebaseException && error.code == 'resource-exhausted') {
        break;
      }
      if (isNetworkError(error)) {
        limiter.forget(now);
        return (quotes: quotes, offline: true);
      }
      quotes[key] = null;
    }
  }
  return (quotes: quotes, offline: false);
}

/// Applies fetched [quotes] to [holdings]. A key mapped to null failed; a key
/// missing from [quotes] was not requested (deferred). Returns the holdings
/// whose price changed (the only ones worth saving) and the counts.
/// [offline] is passed on to the result.
({List<InvestmentHolding> changed, PriceRefreshResult result}) applyQuotes(
  List<InvestmentHolding> holdings,
  Map<QuoteKey, Money?> quotes, {
  bool offline = false,
}) {
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
      offline: offline,
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

  /// Gives back the call recorded at [call] (it never reached the server).
  void forget(DateTime call) => _calls.remove(call);
}
