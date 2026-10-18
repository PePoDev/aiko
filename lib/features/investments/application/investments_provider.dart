import 'package:cloud_functions/cloud_functions.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/money/money.dart';
import '../../../core/firebase/firebase_backend.dart';
import '../../../core/network/network_errors.dart';
import '../../../core/storage/device_values.dart';
import '../data/investment_holding_repository.dart';
import '../domain/investment_holding.dart';
import 'price_refresh.dart';

class InvestmentsNotifier extends AsyncNotifier<List<InvestmentHolding>> {
  @override
  Future<List<InvestmentHolding>> build() async {
    final repo = ref.watch(investmentHoldingRepositoryProvider);
    return repo.list();
  }

  /// Saves a new or edited holding (matched by id). The current list stays on
  /// screen while saving; a failure is rethrown for the caller to report and
  /// leaves the list unchanged.
  ///
  /// The list is updated in memory rather than read back: right after a
  /// signed-in write, Firestore's cache may still answer a query with the
  /// rows from before it.
  Future<void> saveHolding(InvestmentHolding holding) async {
    final repo = ref.read(investmentHoldingRepositoryProvider);
    final saved = await repo.save(holding);
    await _update(repo, (holdings) => withHolding(holdings, saved));
  }

  /// Removes a holding; same contract as [saveHolding].
  Future<void> deleteHolding(String id) async {
    final repo = ref.read(investmentHoldingRepositoryProvider);
    await repo.delete(id);
    await _update(repo, (holdings) => withoutHolding(holdings, id));
  }

  /// Applies [change] to the list on screen, or reads the list when none is
  /// loaded yet.
  Future<void> _update(
    InvestmentHoldingRepository repo,
    List<InvestmentHolding> Function(List<InvestmentHolding>) change,
  ) async {
    if (!ref.mounted) return;
    final current = state.value;
    final holdings = current == null ? await repo.list() : change(current);
    if (ref.mounted) state = AsyncData(holdings);
  }

  /// Fetches live prices through the `marketFeed` function: one call per
  /// symbol and currency, stopping before the per-minute limit, and saves
  /// only holdings whose price changed. Needs the cloud backend and an
  /// account (the function refuses guests, so nothing is asked then).
  Future<PriceRefreshResult> refreshPrices() async {
    final current = state.value;
    if (current == null || current.isEmpty) {
      return const PriceRefreshResult();
    }
    if (!FirebaseBackend.isConfigured) {
      return const PriceRefreshResult.needsCloud();
    }
    if (cloudFeatureNeedsSignIn()) {
      return const PriceRefreshResult.needsSignIn();
    }

    final repo = ref.read(investmentHoldingRepositoryProvider);
    final fetched = await fetchQuotes(
      uniqueQuoteKeys(current),
      fetch: _fetchLivePrice,
      limiter: ref.read(marketQuoteLimiterProvider),
    );

    final outcome = applyQuotes(
      current,
      fetched.quotes,
      offline: fetched.offline,
    );
    if (outcome.result.updated > 0) {
      await ref
          .read(deviceValuesProvider)
          .write(
            pricesUpdatedAtKey(FirebaseBackend.userId),
            DateTime.now().toUtc().toIso8601String(),
          );
      if (ref.mounted) ref.invalidate(pricesUpdatedAtProvider);
    }
    if (outcome.changed.isNotEmpty) {
      final saved = <InvestmentHolding>[];
      for (final holding in outcome.changed) {
        saved.add(await repo.save(holding));
      }
      await _update(
        repo,
        (holdings) => saved.fold(holdings, (list, h) => withHolding(list, h)),
      );
    }
    return outcome.result;
  }

  Future<Money> _fetchLivePrice(QuoteKey key) async {
    final response = await FirebaseBackend.functions
        .httpsCallable('marketFeed', options: _quoteOptions)
        .call({'symbol': key.symbol, 'currency': key.currency});
    final data = Map<String, dynamic>.from(response.data as Map);
    final price = Decimal.tryParse(data['price'].toString());
    if (price == null || price <= Decimal.zero) {
      throw FormatException('Invalid price for ${key.symbol}');
    }
    return Money(amount: price, currency: key.currency);
  }
}

/// A quote that takes longer than this counts as no connection, so a weak
/// signal can't stall the refresh for the 60 s default per symbol. Longer
/// than the server gives its market provider (30 s), so a slow provider
/// comes back as that one quote failing, not as "offline".
final _quoteOptions = HttpsCallableOptions(
  timeout: const Duration(seconds: 35),
);

/// [holdings] with [saved] in place of the holding with its id, or added;
/// ordered by symbol like the repository's list.
List<InvestmentHolding> withHolding(
  List<InvestmentHolding> holdings,
  InvestmentHolding saved,
) => [
  for (final holding in holdings)
    if (holding.id != saved.id) holding,
  saved,
]..sort((a, b) => a.symbol.compareTo(b.symbol));

/// [holdings] without the holding [id].
List<InvestmentHolding> withoutHolding(
  List<InvestmentHolding> holdings,
  String id,
) => [
  for (final holding in holdings)
    if (holding.id != id) holding,
];

/// The device value that holds when live prices last refreshed for [userId].
String pricesUpdatedAtKey(String? userId) =>
    'prices_updated_at:${userId ?? 'local'}';

/// When live prices last refreshed on this device (at least one holding got
/// a quote), or null when that is not known here.
final pricesUpdatedAtProvider = FutureProvider.autoDispose<DateTime?>((
  ref,
) async {
  final raw = await ref
      .watch(deviceValuesProvider)
      .read(pricesUpdatedAtKey(FirebaseBackend.userId));
  return raw == null ? null : DateTime.tryParse(raw)?.toLocal();
});

final investmentsProvider =
    AsyncNotifierProvider.autoDispose<
      InvestmentsNotifier,
      List<InvestmentHolding>
    >(() {
      return InvestmentsNotifier();
    });

/// Shared for the app's lifetime so the market-data budget holds across
/// visits to the portfolio screen.
final marketQuoteLimiterProvider = Provider<MarketQuoteLimiter>(
  (ref) => MarketQuoteLimiter(),
);
