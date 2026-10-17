import '../../../core/offline/offline_store.dart';
import '../../../core/offline/offline_user_context.dart';
import '../../../core/offline/records/records.dart';
import '../domain/investment_holding.dart';

class InvestmentHoldingRepository {
  const InvestmentHoldingRepository({
    OfflineStore? store,
    OfflineUserContext? userContext,
  }) : _storeOverride = store,
       _userContextOverride = userContext;

  final OfflineStore? _storeOverride;
  final OfflineUserContext? _userContextOverride;

  OfflineStore get _store => _storeOverride ?? OfflineStore();
  OfflineUserContext get _userContext =>
      _userContextOverride ?? OfflineUserContext();

  Future<List<InvestmentHolding>> list() async {
    final userId = await _userContext.resolveUserId();
    final holdings = await _store.get<OfflineInvestmentHolding>(
      query: RecordQuery(ownerId: userId, orderBy: 'symbol'),
    );

    return holdings
        .map((holding) => holding.toDomain())
        .toList(growable: false);
  }

  Future<InvestmentHolding> save(InvestmentHolding holding) async {
    final userId = await _userContext.resolveUserId();
    final saved = await _store.upsert(holding.toOffline(userId: userId));
    return saved.toDomain();
  }

  Future<void> delete(String id) async {
    final userId = await _userContext.resolveUserId();
    await _store.commit(
      RecordBatch()..deleteById<OfflineInvestmentHolding>(id, ownerId: userId),
    );
  }
}
