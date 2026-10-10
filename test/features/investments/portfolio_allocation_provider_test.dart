import 'package:aiko/app/providers.dart';
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
    Map<String, Decimal> rates,
  ) {
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
        fxRatesProvider.overrideWith((ref, base) async => rates),
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
  });

  test('holdings with no rate are left out', () async {
    final container = containerFor([
      holding('set', 'stocks', Money.parse('1000', 'THB')),
      holding('bnd', 'bonds', Money.parse('100', 'USD')),
    ], const {});

    final allocation = await container.read(portfolioAllocationProvider.future);

    expect(allocation.holdingCount, 1);
    expect(allocation.slices.single.assetClass, 'stocks');
    expect(allocation.slices.single.percent, 100);
  });
}

class _Holdings extends InvestmentsNotifier {
  _Holdings(this.holdings);
  final List<InvestmentHolding> holdings;

  @override
  Future<List<InvestmentHolding>> build() async => holdings;
}
