import '../../../brick/models/investment_holding.model.dart';
import '../../../brick/offline_model_mappers.dart';
import '../../../brick/repository.dart';
import '../../../core/offline/offline_store.dart';
import '../../../core/offline/offline_user_context.dart';
import '../domain/investment_holding.dart';

class InvestmentHoldingRepository {
  const InvestmentHoldingRepository();

  Future<List<InvestmentHolding>> list() async {
    final userId = await OfflineUserContext().resolveUserId();
    final holdings = await OfflineStore().get<OfflineInvestmentHolding>(
      query: Query(
        where: [Where.exact('userId', userId)],
        orderBy: const [OrderBy.asc('symbol')],
      ),
    );

    return holdings
        .map((holding) => holding.toDomain())
        .toList(growable: false);
  }

  Future<InvestmentHolding> save(InvestmentHolding holding) async {
    final userId = await OfflineUserContext().resolveUserId();
    final saved = await OfflineStore().upsert(
      holding.toOffline(userId: userId),
    );
    return saved.toDomain();
  }

  Future<void> delete(String id) async {
    final userId = await OfflineUserContext().resolveUserId();
    final holdings = await OfflineStore().get<OfflineInvestmentHolding>(
      query: Query(
        where: [Where.exact('id', id), Where.exact('userId', userId)],
        limit: 1,
      ),
    );
    if (holdings.isEmpty) {
      return;
    }
    await OfflineStore().delete(holdings.first);
  }
}
