import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../domain/investment_holding.dart';
import 'live_market_feed_service.dart';

class InvestmentsNotifier extends AsyncNotifier<List<InvestmentHolding>> {
  final LiveMarketFeedService _feedService = const LiveMarketFeedService();

  @override
  Future<List<InvestmentHolding>> build() async {
    final repo = ref.watch(investmentHoldingRepositoryProvider);
    return repo.list();
  }

  Future<void> addHolding(InvestmentHolding holding) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(investmentHoldingRepositoryProvider);
      await repo.save(holding);
      return repo.list();
    });
    if (state.hasError) {
      Error.throwWithStackTrace(state.error!, state.stackTrace!);
    }
  }

  Future<void> deleteHolding(String id) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(investmentHoldingRepositoryProvider);
      await repo.delete(id);
      return repo.list();
    });
    if (state.hasError) {
      Error.throwWithStackTrace(state.error!, state.stackTrace!);
    }
  }

  Future<void> refreshPrices() async {
    final current = state.whenOrNull(data: (holdings) => holdings);
    if (current == null || current.isEmpty) {
      return;
    }

    final updated = <InvestmentHolding>[];
    for (final holding in current) {
      try {
        final newPrice = await _feedService.fetchLivePrice(
          holding.symbol,
          currency: holding.currency,
        );
        updated.add(holding.copyWith(currentPrice: newPrice));
      } catch (_) {
        updated.add(holding);
      }
    }

    final repo = ref.read(investmentHoldingRepositoryProvider);
    for (final holding in updated) {
      await repo.save(holding);
    }

    state = await AsyncValue.guard(() => repo.list());
  }
}

final investmentsProvider =
    AsyncNotifierProvider.autoDispose<
      InvestmentsNotifier,
      List<InvestmentHolding>
    >(() {
      return InvestmentsNotifier();
    });
