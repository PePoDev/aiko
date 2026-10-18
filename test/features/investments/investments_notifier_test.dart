import 'package:aiko/app/providers.dart';
import 'package:aiko/core/money/money.dart';
import 'package:aiko/features/investments/application/investments_provider.dart';
import 'package:aiko/features/investments/data/investment_holding_repository.dart';
import 'package:aiko/features/investments/domain/investment_holding.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

InvestmentHolding _holding(String id, String symbol, {String price = '10'}) =>
    InvestmentHolding(
      id: id,
      symbol: symbol,
      assetClass: 'Stocks',
      quantity: Decimal.one,
      averageCost: Money.parse('5', 'USD'),
      currentPrice: Money.parse(price, 'USD'),
    );

/// Answers [list] with the rows it started with, as a cache query served
/// before a write is applied would.
class _StaleRepository extends InvestmentHoldingRepository {
  _StaleRepository(this.rows);

  final List<InvestmentHolding> rows;
  var lists = 0;

  @override
  Future<List<InvestmentHolding>> list() async {
    lists++;
    return rows;
  }

  @override
  Future<InvestmentHolding> save(InvestmentHolding holding) async => holding;

  @override
  Future<void> delete(String id) async {}
}

void main() {
  late _StaleRepository repository;
  late ProviderContainer container;

  setUp(() {
    repository = _StaleRepository([
      _holding('1', 'AAPL'),
      _holding('2', 'VTI'),
    ]);
    container = ProviderContainer(
      overrides: [
        investmentHoldingRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
  });

  List<String> symbols() => [
    for (final holding in container.read(investmentsProvider).requireValue)
      '${holding.symbol}:${holding.currentPrice.amount}',
  ];

  test('a saved holding shows at once, without reading back', () async {
    final sub = container.listen(investmentsProvider, (_, _) {});
    addTearDown(sub.close);
    await container.read(investmentsProvider.future);

    final notifier = container.read(investmentsProvider.notifier);
    await notifier.saveHolding(_holding('3', 'BND'));
    await notifier.saveHolding(_holding('1', 'AAPL', price: '12'));

    expect(symbols(), ['AAPL:12', 'BND:10', 'VTI:10']);
    expect(repository.lists, 1);
  });

  test('a deleted holding leaves the list at once', () async {
    final sub = container.listen(investmentsProvider, (_, _) {});
    addTearDown(sub.close);
    await container.read(investmentsProvider.future);

    await container.read(investmentsProvider.notifier).deleteHolding('1');

    expect(symbols(), ['VTI:10']);
    expect(repository.lists, 1);
  });

  test('withHolding replaces by id and keeps symbol order', () {
    final list = withHolding([
      _holding('1', 'AAPL'),
      _holding('2', 'VTI'),
    ], _holding('2', 'BND'));
    expect(list.map((h) => '${h.id}:${h.symbol}'), ['1:AAPL', '2:BND']);
    expect(withoutHolding(list, '1').map((h) => h.id), ['2']);
  });
}
