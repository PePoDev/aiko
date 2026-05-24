import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/transactions/data/transaction_repository.dart';
import '../features/accounts/data/account_repository.dart';
import '../features/categories/application/category_service.dart';
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
import '../features/bills/data/bill_subscription_repository.dart';
import '../features/bills/domain/bill_subscription.dart';
import '../core/money/money.dart';

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

final billSubscriptionRepositoryProvider = Provider<BillSubscriptionRepository>(
  (ref) {
    return const BillSubscriptionRepository();
  },
);

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

  Future<FinanceTransaction> saveTransaction(
    FinanceTransaction transaction,
  ) async {
    late final FinanceTransaction saved;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(transactionRepositoryProvider);
      saved = await repo.save(transaction);
      return repo.list();
    });
    if (state.hasError) {
      Error.throwWithStackTrace(state.error!, state.stackTrace!);
    }
    return saved;
  }

  Future<void> addTransaction(FinanceTransaction transaction) async {
    await saveTransaction(transaction);
  }

  Future<void> deleteTransaction(String id) async {
    final previousTransactions = state.hasValue ? state.value : null;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(transactionRepositoryProvider);
      await repo.delete(id);
      final transactions = previousTransactions ?? await repo.list();
      return transactions
          .where((transaction) => transaction.id != id)
          .toList(growable: false);
    });
    if (state.hasError) {
      Error.throwWithStackTrace(state.error!, state.stackTrace!);
    }
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
    await saveAccount(account);
  }

  Future<void> saveAccount(Account account) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(accountRepositoryProvider);
      await repo.save(account);
      return repo.list();
    });
    if (state.hasError) {
      Error.throwWithStackTrace(state.error!, state.stackTrace!);
    }
  }

  Future<void> deleteAccount(String id) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(accountRepositoryProvider);
      await repo.delete(id);
      return repo.list();
    });
    if (state.hasError) {
      Error.throwWithStackTrace(state.error!, state.stackTrace!);
    }
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
    final categories = await repo.list();
    if (categories.isNotEmpty) {
      return categories;
    }

    final defaults = const CategoryService().defaultCategoriesFor('local-user');
    for (final category in defaults) {
      await repo.save(category);
    }
    return repo.list();
  }

  Future<void> addCategory(Category category) async {
    await saveCategory(category);
  }

  Future<void> saveCategory(Category category) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(categoryRepositoryProvider);
      await repo.save(category);
      return repo.list();
    });
    if (state.hasError) {
      Error.throwWithStackTrace(state.error!, state.stackTrace!);
    }
  }

  Future<void> deleteCategory(String id) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(categoryRepositoryProvider);
      await repo.delete(id);
      return repo.list();
    });
    if (state.hasError) {
      Error.throwWithStackTrace(state.error!, state.stackTrace!);
    }
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
    await saveBudget(budget);
  }

  Future<void> saveBudget(Budget budget) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(budgetRepositoryProvider);
      await repo.save(budget);
      return repo.list();
    });
    if (state.hasError) {
      Error.throwWithStackTrace(state.error!, state.stackTrace!);
    }
  }

  Future<void> deleteBudget(String id) async {
    if (id == Budget.dailySpendingId) {
      throw StateError('The Daily Spending budget cannot be deleted.');
    }
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(budgetRepositoryProvider);
      await repo.delete(id);
      return repo.list();
    });
    if (state.hasError) {
      Error.throwWithStackTrace(state.error!, state.stackTrace!);
    }
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

  Future<void> deleteGoal(String id) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(goalRepositoryProvider);
      await repo.delete(id);
      return repo.list();
    });
  }
}

final goalsProvider =
    AsyncNotifierProvider.autoDispose<GoalsNotifier, List<Goal>>(() {
      return GoalsNotifier();
    });

class BillSubscriptionsNotifier extends AsyncNotifier<List<BillSubscription>> {
  // In-memory fallback for offline/mock mode when no session exists
  final List<BillSubscription> _localFallback = [
    BillSubscription(
      id: 'local-bill-1',
      merchant: 'Streaming Plus',
      amount: Money.parse('18', 'USD'),
      billingCycle: BillingCycle.monthly,
      nextBillingDate: DateTime(2026, 6, 1),
    ),
    BillSubscription(
      id: 'local-bill-2',
      merchant: 'Cloud Trial',
      amount: Money.parse('29', 'USD'),
      billingCycle: BillingCycle.monthly,
      nextBillingDate: DateTime(2026, 5, 28),
      categoryId: 'trial',
    ),
  ];

  @override
  Future<List<BillSubscription>> build() async {
    final repo = ref.watch(billSubscriptionRepositoryProvider);
    try {
      return await repo.list();
    } catch (_) {
      // Offline/Mock fallback
      return _localFallback;
    }
  }

  Future<void> addBillSubscription(BillSubscription bill) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(billSubscriptionRepositoryProvider);
      try {
        await repo.save(bill);
        return await repo.list();
      } catch (_) {
        // Fallback local update
        final idx = _localFallback.indexWhere((b) => b.id == bill.id);
        if (idx != -1) {
          _localFallback[idx] = bill;
        } else {
          _localFallback.add(bill);
        }
        return [..._localFallback];
      }
    });
  }

  Future<void> deleteBillSubscription(String id) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(billSubscriptionRepositoryProvider);
      try {
        await repo.delete(id);
        return await repo.list();
      } catch (_) {
        // Fallback local update
        _localFallback.removeWhere((b) => b.id == id);
        return [..._localFallback];
      }
    });
  }
}

final billSubscriptionsProvider =
    AsyncNotifierProvider.autoDispose<
      BillSubscriptionsNotifier,
      List<BillSubscription>
    >(() {
      return BillSubscriptionsNotifier();
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
