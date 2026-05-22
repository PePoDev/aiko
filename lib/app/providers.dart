import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/transactions/data/transaction_repository.dart';
import '../features/accounts/data/account_repository.dart';
import '../features/budgets/data/budget_repository.dart';
import '../features/categories/data/category_repository.dart';
import '../features/dashboard/data/dashboard_due_item_repository.dart';
import '../features/dashboard/data/dashboard_repository.dart';
import '../features/dashboard/domain/dashboard_due_item.dart';
import '../features/dashboard/domain/dashboard_summary.dart';
import '../features/goals/data/goal_repository.dart';
import '../features/goals/domain/goal.dart';
import '../features/insights/data/aiko_insight_repository.dart';
import '../features/insights/domain/aiko_insight.dart';
import '../features/settings/data/profile_repository.dart';
import '../features/settings/domain/profile.dart';
import '../features/transactions/domain/transaction.dart';
import '../features/accounts/domain/account.dart';
import '../features/budgets/domain/budget.dart';
import '../features/categories/domain/category.dart';

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepository();
});

final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  return AccountRepository();
});

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return CategoryRepository();
});

final budgetRepositoryProvider = Provider<BudgetRepository>((ref) {
  return BudgetRepository();
});

final goalRepositoryProvider = Provider<GoalRepository>((ref) {
  return const GoalRepository();
});

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return const ProfileRepository();
});

final aikoInsightRepositoryProvider = Provider<AikoInsightRepository>((ref) {
  return const AikoInsightRepository();
});

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return const DashboardRepository();
});

final dashboardDueItemRepositoryProvider = Provider<DashboardDueItemRepository>(
  (ref) {
    return const DashboardDueItemRepository();
  },
);

class TransactionsNotifier extends AsyncNotifier<List<FinanceTransaction>> {
  @override
  Future<List<FinanceTransaction>> build() async {
    final repo = ref.watch(transactionRepositoryProvider);
    return repo.list();
  }

  Future<void> addTransaction(FinanceTransaction transaction) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(transactionRepositoryProvider);
      await repo.save(transaction);
      return repo.list();
    });
  }
}

final transactionsProvider =
    AsyncNotifierProvider.autoDispose<
      TransactionsNotifier,
      List<FinanceTransaction>
    >(() {
      return TransactionsNotifier();
    });

class AccountsNotifier extends AsyncNotifier<List<Account>> {
  @override
  Future<List<Account>> build() async {
    final repo = ref.watch(accountRepositoryProvider);
    return repo.list();
  }

  Future<void> addAccount(Account account) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(accountRepositoryProvider);
      await repo.save(account);
      return repo.list();
    });
  }
}

final accountsProvider =
    AsyncNotifierProvider.autoDispose<AccountsNotifier, List<Account>>(() {
      return AccountsNotifier();
    });

class CategoriesNotifier extends AsyncNotifier<List<Category>> {
  @override
  Future<List<Category>> build() async {
    final repo = ref.watch(categoryRepositoryProvider);
    return repo.list();
  }

  Future<void> addCategory(Category category) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(categoryRepositoryProvider);
      await repo.save(category);
      return repo.list();
    });
  }
}

final categoriesProvider =
    AsyncNotifierProvider.autoDispose<CategoriesNotifier, List<Category>>(() {
      return CategoriesNotifier();
    });

class BudgetsNotifier extends AsyncNotifier<List<Budget>> {
  @override
  Future<List<Budget>> build() async {
    final repo = ref.watch(budgetRepositoryProvider);
    return repo.list();
  }

  Future<void> addBudget(Budget budget) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(budgetRepositoryProvider);
      await repo.save(budget);
      return repo.list();
    });
  }
}

final budgetsProvider =
    AsyncNotifierProvider.autoDispose<BudgetsNotifier, List<Budget>>(() {
      return BudgetsNotifier();
    });

class GoalsNotifier extends AsyncNotifier<List<Goal>> {
  @override
  Future<List<Goal>> build() async {
    final repo = ref.watch(goalRepositoryProvider);
    return repo.list();
  }

  Future<void> addGoal(Goal goal) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(goalRepositoryProvider);
      await repo.save(goal);
      return repo.list();
    });
  }
}

final goalsProvider =
    AsyncNotifierProvider.autoDispose<GoalsNotifier, List<Goal>>(() {
      return GoalsNotifier();
    });

final profileProvider = FutureProvider.autoDispose<Profile>((ref) {
  final repo = ref.watch(profileRepositoryProvider);
  return repo.load();
});

final aikoInsightsProvider = FutureProvider.autoDispose<List<AikoInsight>>((
  ref,
) async {
  final profile = await ref.watch(profileProvider.future);
  final repo = ref.watch(aikoInsightRepositoryProvider);
  return repo.list(aiConsentEnabled: profile.aiConsentEnabled);
});

final dashboardSummaryProvider = FutureProvider.autoDispose<DashboardSummary>((
  ref,
) {
  final repo = ref.watch(dashboardRepositoryProvider);
  return repo.loadSummary();
});

final dashboardDueItemsProvider =
    FutureProvider.autoDispose<List<DashboardDueItem>>((ref) {
      final repo = ref.watch(dashboardDueItemRepositoryProvider);
      return repo.loadUpcomingItems(DateTime.now());
    });
