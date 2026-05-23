import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/investment_holding.dart';
import 'live_market_feed_service.dart';
import '../../../core/money/money.dart';

class PortfolioState {
  const PortfolioState({
    required this.holdings,
    this.isRefreshing = false,
  });

  final List<InvestmentHolding> holdings;
  final bool isRefreshing;

  PortfolioState copyWith({
    List<InvestmentHolding>? holdings,
    bool? isRefreshing,
  }) {
    return PortfolioState(
      holdings: holdings ?? this.holdings,
      isRefreshing: isRefreshing ?? this.isRefreshing,
    );
  }
}

class PortfolioNotifier extends Notifier<PortfolioState> {
  final LiveMarketFeedService feedService = const LiveMarketFeedService();

  @override
  PortfolioState build() {
    return PortfolioState(
      holdings: [
        InvestmentHolding(
          symbol: 'VTI',
          assetClass: 'Stocks',
          quantity: 10,
          averageCost: Money.parse('180', 'USD'),
          currentPrice: Money.parse('240', 'USD'),
        ),
        InvestmentHolding(
          symbol: 'BND',
          assetClass: 'Bonds',
          quantity: 5,
          averageCost: Money.parse('75', 'USD'),
          currentPrice: Money.parse('72', 'USD'),
        ),
      ],
    );
  }

  Future<void> refreshPrices() async {
    state = state.copyWith(isRefreshing: true);
    try {
      final updatedHoldings = <InvestmentHolding>[];
      for (final holding in state.holdings) {
        final newPrice = await feedService.fetchLivePrice(holding.symbol);
        updatedHoldings.add(
          InvestmentHolding(
            symbol: holding.symbol,
            assetClass: holding.assetClass,
            quantity: holding.quantity,
            averageCost: holding.averageCost,
            currentPrice: newPrice,
          ),
        );
      }
      state = state.copyWith(holdings: updatedHoldings, isRefreshing: false);
    } catch (_) {
      state = state.copyWith(isRefreshing: false);
    }
  }

  void addHolding(InvestmentHolding holding) {
    // If the holding symbol already exists, average it out or replace it
    final existingIndex = state.holdings.indexWhere((h) => h.symbol.toUpperCase() == holding.symbol.toUpperCase());
    if (existingIndex != -1) {
      final existing = state.holdings[existingIndex];
      final newQuantity = existing.quantity + holding.quantity;
      if (newQuantity <= 0) {
        deleteHolding(holding.symbol);
        return;
      }
      // Weighted average cost: (Qty1 * Cost1 + Qty2 * Cost2) / TotalQty
      final totalCostVal = (existing.quantity * existing.averageCost.amount.toDouble()) + 
                           (holding.quantity * holding.averageCost.amount.toDouble());
      final newAverageCost = Money.parse((totalCostVal / newQuantity).toStringAsFixed(2), holding.averageCost.currency);

      final updated = InvestmentHolding(
        symbol: existing.symbol,
        assetClass: existing.assetClass,
        quantity: newQuantity,
        averageCost: newAverageCost,
        currentPrice: holding.currentPrice,
      );

      final newHoldings = [...state.holdings];
      newHoldings[existingIndex] = updated;
      state = state.copyWith(holdings: newHoldings);
    } else {
      state = state.copyWith(holdings: [...state.holdings, holding]);
    }
  }

  void deleteHolding(String symbol) {
    state = state.copyWith(
      holdings: state.holdings.where((h) => h.symbol.toUpperCase() != symbol.toUpperCase()).toList(),
    );
  }
}

final portfolioProvider =
    NotifierProvider<PortfolioNotifier, PortfolioState>(() {
  return PortfolioNotifier();
});
