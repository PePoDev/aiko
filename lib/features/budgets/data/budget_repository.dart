import 'package:uuid/uuid.dart';

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

    final domainBudgets = budgets
        .map((budget) => budget.toDomain())
        .toList(growable: true);
    final dailyIndex = domainBudgets.indexWhere(
      (budget) => budget.isDailySpending,
    );
    if (dailyIndex == -1) {
      domainBudgets.insert(0, _dailySpendingBudget(userId));
    } else {
      domainBudgets[dailyIndex] = _withTodayDailyPeriod(
        domainBudgets[dailyIndex],
      );
    }
    return List.unmodifiable(domainBudgets);
  }

  Future<Budget> save(Budget budget) async {
    if (budget.amount.amount <= Money.zero(budget.amount.currency).amount) {
      throw ArgumentError('Budget amount must be positive.');
    }

    final userId = await OfflineUserContext().resolveUserId();
    final saved = await OfflineStore().upsert(budget.toOffline(userId: userId));
    return saved.toDomain();
  }

  Future<void> delete(String id) async {
    if (id == Budget.dailySpendingId) {
      throw StateError('The Daily Spending budget cannot be deleted.');
    }

    final userId = await OfflineUserContext().resolveUserId();
    final budgets = await OfflineStore().get<OfflineBudget>(
      query: Query(
        where: [Where.exact('id', id), Where.exact('userId', userId)],
        limit: 1,
      ),
    );
    if (budgets.isEmpty) {
      return;
    }
    if (budgets.first.toDomain().isDailySpending) {
      throw StateError('The Daily Spending budget cannot be deleted.');
    }
    await OfflineStore().delete(budgets.first);
  }

  Budget _dailySpendingBudget(String userId) {
    return _withTodayDailyPeriod(
      Budget(
        id: const Uuid().v5(
          Namespace.url.value,
          'aiko:$userId:daily-spending-budget',
        ),
        userId: userId,
        name: 'Daily Spending',
        categoryId: Budget.dailySpendingCategoryId,
        amount: Money.parse('1000', 'THB'),
        periodStart: DateTime(2000),
        periodEnd: DateTime(2000, 1, 1, 23, 59, 59),
        period: BudgetPeriod.daily,
        includedCategoryIds: const [],
        isAppDefined: true,
      ),
    );
  }

  Budget _withTodayDailyPeriod(Budget budget) {
    final today = DateTime.now();
    return budget.copyWith(
      periodStart: DateTime(today.year, today.month, today.day),
      periodEnd: DateTime(today.year, today.month, today.day, 23, 59, 59),
      period: BudgetPeriod.daily,
    );
  }
}
