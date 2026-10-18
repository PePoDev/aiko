import 'package:aiko/core/money/money.dart';
import 'package:aiko/features/dashboard/application/dashboard_summary_builder.dart';
import 'package:aiko/features/investments/application/portfolio_valuation.dart';
import 'package:aiko/features/investments/application/price_refresh.dart';
import 'package:aiko/features/investments/domain/investment_holding.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

InvestmentHolding _holding(
  String id,
  String symbol, {
  String currency = 'USD',
  String price = '100',
  String cost = '90',
  String quantity = '1',
}) => InvestmentHolding(
  id: id,
  symbol: symbol,
  assetClass: 'Stocks',
  quantity: Decimal.parse(quantity),
  averageCost: Money.parse(cost, currency),
  currentPrice: Money.parse(price, currency),
);

void main() {
  group('uniqueQuoteKeys', () {
    test('asks once per symbol and currency, in first-seen order', () {
      final keys = uniqueQuoteKeys([
        _holding('1', 'vti'),
        _holding('2', 'AAPL'),
        _holding('3', 'VTI'),
        _holding('4', 'VTI', currency: 'THB'),
      ]);
      expect(keys, [
        (symbol: 'VTI', currency: 'USD'),
        (symbol: 'AAPL', currency: 'USD'),
        (symbol: 'VTI', currency: 'THB'),
      ]);
    });
  });

  group('applyQuotes', () {
    test('counts updated, failed and deferred holdings', () {
      final holdings = [
        _holding('1', 'VTI', price: '100'),
        _holding('2', 'VTI', price: '100'),
        _holding('3', 'AAPL', price: '200'),
        _holding('4', 'BTC', price: '50000'),
        _holding('5', 'SPY', price: '400'),
      ];
      final outcome = applyQuotes(holdings, {
        (symbol: 'VTI', currency: 'USD'): Money.parse('105', 'USD'),
        // Unchanged price: refreshed, but nothing to save.
        (symbol: 'AAPL', currency: 'USD'): Money.parse('200.00', 'USD'),
        (symbol: 'BTC', currency: 'USD'): null,
        // SPY was never requested (over the per-minute budget).
      });

      expect(outcome.result.updated, 3);
      expect(outcome.result.failed, 1);
      expect(outcome.result.deferred, 1);
      expect(outcome.result.needsCloud, isFalse);
      expect(outcome.changed.map((h) => h.id), ['1', '2']);
      expect(outcome.changed.first.currentPrice, Money.parse('105', 'USD'));
    });

    test('saves nothing when every price is unchanged', () {
      final outcome = applyQuotes(
        [_holding('1', 'VTI', price: '100')],
        {(symbol: 'VTI', currency: 'USD'): Money.parse('100', 'USD')},
      );
      expect(outcome.changed, isEmpty);
      expect(outcome.result.updated, 1);
    });
  });

  group('MarketQuoteLimiter', () {
    test('allows 30 calls per sliding minute', () {
      final limiter = MarketQuoteLimiter();
      final start = DateTime(2026, 10, 10, 9);
      for (var i = 0; i < 30; i++) {
        expect(limiter.remaining(start), greaterThan(0));
        limiter.record(start);
      }
      expect(limiter.remaining(start), 0);
      expect(limiter.remaining(start.add(const Duration(seconds: 59))), 0);
      expect(limiter.remaining(start.add(const Duration(minutes: 1))), 30);
    });

    test('a forgotten call gives its place back', () {
      final limiter = MarketQuoteLimiter(maxCalls: 2);
      final start = DateTime(2026, 10, 10, 9);
      limiter
        ..record(start)
        ..record(start.add(const Duration(seconds: 1)));
      expect(limiter.remaining(start), 0);
      limiter.forget(start.add(const Duration(seconds: 1)));
      expect(limiter.remaining(start), 1);
    });
  });

  group('fetchQuotes', () {
    final keys = [
      (symbol: 'VTI', currency: 'USD'),
      (symbol: 'AAPL', currency: 'USD'),
      (symbol: 'SPY', currency: 'USD'),
    ];
    final clock = DateTime(2026, 10, 10, 9);

    test('offline stops at once and uses none of the budget', () async {
      final limiter = MarketQuoteLimiter();
      var calls = 0;
      final fetched = await fetchQuotes(
        keys,
        fetch: (key) async {
          calls++;
          throw FirebaseFunctionsException(
            code: 'unavailable',
            message: 'UNAVAILABLE',
          );
        },
        limiter: limiter,
        clock: () => clock,
      );
      expect(fetched.offline, isTrue);
      expect(fetched.quotes, isEmpty);
      expect(calls, 1);
      expect(limiter.remaining(clock), limiter.maxCalls);

      final outcome = applyQuotes(
        [_holding('1', 'VTI'), _holding('2', 'AAPL')],
        fetched.quotes,
        offline: fetched.offline,
      );
      expect(outcome.result.offline, isTrue);
      expect(outcome.result.failed, 0);
      expect(outcome.result.deferred, 2);
    });

    test('a quote that fails on the server counts and continues', () async {
      final limiter = MarketQuoteLimiter();
      final fetched = await fetchQuotes(
        keys,
        fetch: (key) async {
          if (key.symbol == 'AAPL') {
            throw FirebaseFunctionsException(
              code: 'invalid-argument',
              message: 'Invalid symbol or currency.',
            );
          }
          return Money.parse('10', key.currency);
        },
        limiter: limiter,
        clock: () => clock,
      );
      expect(fetched.offline, isFalse);
      expect(fetched.quotes.length, 3);
      expect(fetched.quotes[keys[1]], isNull);
      expect(limiter.remaining(clock), limiter.maxCalls - 3);
    });

    test('a symbol the provider cannot price fails alone, online', () async {
      // The function's own `unavailable` (provider down or unknown symbol)
      // is an answer: the refresh goes on and doesn't say "offline".
      final limiter = MarketQuoteLimiter();
      final fetched = await fetchQuotes(
        keys,
        fetch: (key) async {
          if (key.symbol == 'VTI') {
            throw FirebaseFunctionsException(
              code: 'unavailable',
              message: 'Provider request failed.',
            );
          }
          return Money.parse('10', key.currency);
        },
        limiter: limiter,
        clock: () => clock,
      );
      expect(fetched.offline, isFalse);
      expect(fetched.quotes[keys[0]], isNull);
      expect(fetched.quotes[keys[1]], Money.parse('10', 'USD'));
      expect(fetched.quotes[keys[2]], Money.parse('10', 'USD'));
      expect(limiter.remaining(clock), limiter.maxCalls - 3);
    });

    test('a timeout stops the refresh but keeps its budget slot', () async {
      // The call may have reached the server, which counted it.
      final limiter = MarketQuoteLimiter();
      final fetched = await fetchQuotes(
        keys,
        fetch: (key) async => throw FirebaseFunctionsException(
          code: 'deadline-exceeded',
          message: 'DEADLINE_EXCEEDED',
        ),
        limiter: limiter,
        clock: () => clock,
      );
      expect(fetched.offline, isTrue);
      expect(fetched.quotes, isEmpty);
      expect(limiter.remaining(clock), limiter.maxCalls - 1);
    });

    test('no response on the web counts as offline', () async {
      final limiter = MarketQuoteLimiter();
      final fetched = await fetchQuotes(
        keys,
        fetch: (key) async => throw FirebaseFunctionsException(
          code: 'internal',
          message: 'internal [0]',
        ),
        limiter: limiter,
        clock: () => clock,
      );
      expect(fetched.offline, isTrue);
      expect(limiter.remaining(clock), limiter.maxCalls);
    });

    test("the server's own limit stops the refresh", () async {
      final fetched = await fetchQuotes(
        keys,
        fetch: (key) async {
          if (key.symbol == 'AAPL') {
            throw FirebaseFunctionsException(
              code: 'resource-exhausted',
              message: 'Please try again in a minute.',
            );
          }
          return Money.parse('10', key.currency);
        },
        limiter: MarketQuoteLimiter(),
        clock: () => clock,
      );
      expect(fetched.quotes.keys, [keys.first]);
      expect(fetched.offline, isFalse);
    });
  });

  group('valueHoldingsIn', () {
    test('re-prices other currencies and lists those without a rate', () {
      final valuation = valueHoldingsIn(
        [
          _holding('1', 'PTT', currency: 'THB', price: '35', cost: '30'),
          _holding('2', 'VTI', currency: 'USD', price: '10', cost: '8'),
          _holding('3', 'SAP', currency: 'EUR', price: '100', cost: '90'),
        ],
        // 1 THB = 0.025 USD.
        CurrencyConverter('THB', {'USD': Decimal.parse('0.025')}),
      );

      expect(valuation.currency, 'THB');
      expect(valuation.excludedCurrencies, {'EUR'});
      expect(valuation.holdings.map((h) => h.id), ['1', '2']);
      final vti = valuation.holdings[1];
      expect(vti.currentPrice, Money.parse('400', 'THB'));
      expect(vti.averageCost, Money.parse('320', 'THB'));
      expect(vti.id, '2');
    });
  });
}
