import 'package:aiko/app/providers.dart';
import 'package:aiko/core/money/exchange_rates.dart';
import 'package:aiko/core/money/money.dart';
import 'package:aiko/features/investments/application/investments_provider.dart';
import 'package:aiko/features/investments/domain/investment_holding.dart';
import 'package:aiko/features/settings/domain/profile.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ProviderContainer containerFor(
    List<InvestmentHolding> holdings,
    Map<String, Decimal> rates, {
    bool live = true,
    DateTime? fetchedAt,
  }) {
    final container = ProviderContainer(
      overrides: [
        profileProvider.overrideWith(
          (ref) async => const Profile(
            id: 'u',
            displayName: 'Aiko user',
            email: 'user@example.com',
            baseCurrency: 'THB',
            country: 'TH',
            securityStatus: SecurityStatus.notConfigured,
          ),
        ),
        investmentsProvider.overrideWith(() => _Holdings(holdings)),
        fxRatesProvider.overrideWithBuild(
          (ref, notifier) async => ExchangeRates(
            base: notifier.base,
            rates: rates,
            fetchedAt: fetchedAt ?? DateTime(2026, 10, 17),
            isLive: live,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  InvestmentHolding holding(String id, String assetClass, Money price) {
    return InvestmentHolding(
      id: id,
      symbol: id.toUpperCase(),
      assetClass: assetClass,
      quantity: Decimal.one,
      averageCost: price,
      currentPrice: price,
    );
  }

  test('holdings in other currencies are converted before sharing', () async {
    final container = containerFor(
      [
        holding('set', 'stocks', Money.parse('1000', 'THB')),
        // 100 USD at 1 THB = 0.03 USD is 3,333.33 THB.
        holding('bnd', 'bonds', Money.parse('100', 'USD')),
      ],
      {'USD': Decimal.parse('0.03')},
    );

    final allocation = await container.read(portfolioAllocationProvider.future);

    expect(allocation.total.currency, 'THB');
    expect(allocation.holdingCount, 2);
    expect(allocation.slices.first.assetClass, 'bonds');
    expect(allocation.slices.first.percent, closeTo(76.92, 0.01));
    expect(allocation.slices.last.percent, closeTo(23.08, 0.01));
    expect(allocation.leftOut, isEmpty);
    // Live rates: no "Rates as of" note.
    expect(allocation.ratesAsOf, isNull);
  });

  test('holdings with no rate are left out and named', () async {
    final container = containerFor([
      holding('set', 'stocks', Money.parse('1000', 'THB')),
      holding('bnd', 'bonds', Money.parse('100', 'USD')),
    ], const {});

    final allocation = await container.read(portfolioAllocationProvider.future);

    expect(allocation.holdingCount, 1);
    expect(allocation.slices.single.assetClass, 'stocks');
    expect(allocation.slices.single.percent, 100);
    expect(allocation.leftOut.map((h) => h.symbol), ['BND']);
  });

  test('all holdings left out is not "no holdings yet"', () async {
    final container = containerFor([
      holding('bnd', 'bonds', Money.parse('100', 'USD')),
    ], const {});

    final allocation = await container.read(portfolioAllocationProvider.future);

    expect(allocation.holdingCount, 0);
    expect(allocation.hasHoldings, isTrue);
    expect(allocation.leftOut, hasLength(1));
    // Nothing counted: the (zero) total is in the base currency, not USD.
    expect(allocation.total, Money.zero('THB'));
  });

  test('saved rates say how old they are', () async {
    final fetchedAt = DateTime(2026, 10, 15, 9, 30);
    final container = containerFor(
      [
        holding('set', 'stocks', Money.parse('1000', 'THB')),
        holding('bnd', 'bonds', Money.parse('100', 'USD')),
      ],
      {'USD': Decimal.parse('0.03')},
      live: false,
      fetchedAt: fetchedAt,
    );

    final allocation = await container.read(portfolioAllocationProvider.future);

    expect(allocation.holdingCount, 2);
    expect(allocation.ratesAsOf, fetchedAt);
  });
}

class _Holdings extends InvestmentsNotifier {
  _Holdings(this.holdings);
  final List<InvestmentHolding> holdings;

  @override
  Future<List<InvestmentHolding>> build() async => holdings;
}
