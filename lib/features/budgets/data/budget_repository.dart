import '../../../core/money/money.dart';
import '../../../brick/offline_model_mappers.dart';
import '../../../brick/repository.dart';
import '../../../brick/models/budget.model.dart';
import '../../../core/offline/offline_store.dart';
import '../../../core/offline/offline_user_context.dart';
import '../domain/budget.dart';

class BudgetRepository {
  const BudgetRepository();

  Future<List<Budget>> list() async {
    final userId = await OfflineUserContext().resolveUserId();
    final budgets = await OfflineStore().get<OfflineBudget>(
      query: Query(
        where: [Where.exact('userId', userId)],
        orderBy: const [OrderBy.desc('periodStart')],
      ),
    );

    return budgets.map((budget) => budget.toDomain()).toList(growable: false);
  }

  Future<Budget> save(Budget budget) async {
    if (budget.amount.amount <= Money.zero(budget.amount.currency).amount) {
      throw ArgumentError('Budget amount must be positive.');
    }

    final userId = await OfflineUserContext().resolveUserId();
    final saved = await OfflineStore().upsert(budget.toOffline(userId: userId));
    return saved.toDomain();
  }
}
