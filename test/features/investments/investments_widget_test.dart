import 'package:aiko/core/money/money.dart';
import 'package:aiko/features/investments/application/investments_provider.dart';
import 'package:aiko/features/investments/domain/investment_holding.dart';
import 'package:aiko/features/investments/presentation/investments_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('portfolio screen shows a simple holdings overview', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          investmentsProvider.overrideWith(
            () => _InvestmentsNotifier(_holdings),
          ),
        ],
        child: const MaterialApp(home: InvestmentsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Investments'), findsOneWidget);
    expect(find.text('Investments value'), findsOneWidget);
    expect(find.text('Holdings'), findsOneWidget);
    expect(find.text('Allocation'), findsOneWidget);
    expect(find.text('Capital Gains Tax Estimator'), findsNothing);
    expect(find.textContaining('real-time'), findsNothing);
  });

  testWidgets('portfolio search filters holdings by symbol', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          investmentsProvider.overrideWith(
            () => _InvestmentsNotifier(_holdings),
          ),
        ],
        child: const MaterialApp(home: InvestmentsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Search holdings'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'BND');
    await tester.pump();

    expect(
      find.descendant(of: find.byType(Card), matching: find.text('BND')),
      findsOneWidget,
    );
    expect(find.text('VTI'), findsNothing);
  });
}

final _holdings = [
  InvestmentHolding(
    id: 'test-vti',
    symbol: 'VTI',
    assetClass: 'Stocks',
    quantity: 10,
    averageCost: Money.parse('180', 'USD'),
    currentPrice: Money.parse('240', 'USD'),
  ),
  InvestmentHolding(
    id: 'test-bnd',
    symbol: 'BND',
    assetClass: 'Bonds',
    quantity: 5,
    averageCost: Money.parse('75', 'USD'),
    currentPrice: Money.parse('72', 'USD'),
  ),
];

class _InvestmentsNotifier extends InvestmentsNotifier {
  _InvestmentsNotifier(this._holdings);

  final List<InvestmentHolding> _holdings;

  @override
  Future<List<InvestmentHolding>> build() async => _holdings;

  @override
  Future<void> addHolding(InvestmentHolding holding) async {
    final updated = [..._holdings, holding];
    state = AsyncData(updated);
  }

  @override
  Future<void> deleteHolding(String id) async {
    final updated = _holdings.where((h) => h.id != id).toList(growable: false);
    state = AsyncData(updated);
  }

  @override
  Future<void> refreshPrices() async {}
}
