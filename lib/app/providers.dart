import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/transactions/data/transaction_repository.dart';
import '../features/accounts/application/shared_limit_resolver.dart';
import '../features/accounts/data/account_repository.dart';
import '../features/categories/application/category_service.dart';
import '../features/budgets/data/budget_repository.dart';
import '../features/categories/data/category_repository.dart';
import '../features/categories/data/category_group_repository.dart';
import '../features/dashboard/data/dashboard_due_item_repository.dart';
import '../features/dashboard/data/dashboard_layout_repository.dart';
import '../features/dashboard/data/dashboard_repository.dart';
import '../features/dashboard/domain/dashboard_due_item.dart';
import '../features/dashboard/domain/dashboard_summary.dart';
import '../features/dashboard/domain/dashboard_widget_preference.dart';
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
import '../features/categories/domain/category_defaults.dart';
import '../features/investments/data/investment_holding_repository.dart';
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

final categoryGroupRepositoryProvider = Provider<CategoryGroupRepository>((
  ref,
) {
  return const CategoryGroupRepository();
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

final dashboardLayoutRepositoryProvider = Provider<DashboardLayoutRepository>((
  ref,
) {
  return DashboardLayoutRepository();
});

final investmentHoldingRepositoryProvider =
    Provider<InvestmentHoldingRepository>((ref) {
      return const InvestmentHoldingRepository();
    });

class TransactionsNotifier extends AsyncNotifier<List<FinanceTransaction>> {
  @override
  Future<List<FinanceTransaction>> build() async {
    try {
      final repo = ref.watch(transactionRepositoryProvider);
      final transactions = await repo.list();
      await _reconcileAccountBalances(transactions);
      // Cache the loaded data so leaving and returning to a screen (e.g. the
      // Overview tab) reuses it instead of showing a loading state again. A
      // failed load is not cached, so it still retries on the next visit.
      ref.keepAlive();
      return transactions;
    } catch (error, stackTrace) {
      // Surface the failure to the screen's `AikoScreenState.error` so a
      // broken offline store / secure-storage channel renders a recoverable
      // empty/error widget instead of crashing the provider tree.
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<FinanceTransaction> saveTransaction(
    FinanceTransaction transaction, {
    bool updateAccountBalance = true,
  }) async {
    late final FinanceTransaction saved;
    final previousTransactions = state.hasValue ? state.value : null;
    state = const AsyncValue.loading();
    final nextState = await AsyncValue.guard(() async {
      final repo = ref.read(transactionRepositoryProvider);
      final transactions = previousTransactions ?? await repo.list();
      final previousTransaction = _transactionById(
        transactions,
        transaction.id,
      );
      saved = await repo.save(transaction);
      if (updateAccountBalance) {
        await _syncAccountBalances(
          previousTransaction: previousTransaction,
          nextTransaction: saved,
        );
      }
      return repo.list();
    });
    if (!ref.mounted) {
      return saved;
    }
    state = nextState;
    if (state.hasError) {
      Error.throwWithStackTrace(state.error!, state.stackTrace!);
    }
    return saved;
  }

  Future<void> addTransaction(
    FinanceTransaction transaction, {
    bool updateAccountBalance = true,
  }) async {
    await saveTransaction(
      transaction,
      updateAccountBalance: updateAccountBalance,
    );
  }

  Future<void> deleteTransaction(String id) async {
    final previousTransactions = state.hasValue ? state.value : null;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(transactionRepositoryProvider);
      final transactions = previousTransactions ?? await repo.list();
      final previousTransaction = _transactionById(transactions, id);
      await repo.delete(id);
      await _syncAccountBalances(previousTransaction: previousTransaction);
      return transactions
          .where((transaction) => transaction.id != id)
          .toList(growable: false);
    });
    if (state.hasError) {
      Error.throwWithStackTrace(state.error!, state.stackTrace!);
    }
  }

  FinanceTransaction? _transactionById(
    List<FinanceTransaction> transactions,
    String id,
  ) {
    for (final transaction in transactions) {
      if (transaction.id == id) {
        return transaction;
      }
    }
    return null;
  }

  Future<void> _syncAccountBalances({
    FinanceTransaction? previousTransaction,
    FinanceTransaction? nextTransaction,
  }) async {
    if (previousTransaction == null && nextTransaction == null) {
      return;
    }

    try {
      final accounts = await ref.read(accountsProvider.future);
      final originalById = {
        for (final account in accounts) account.id: account,
      };
      final updatedById = {...originalById};

      if (previousTransaction != null) {
        final account = updatedById[previousTransaction.accountId];
        if (account != null) {
          updatedById[account.id] = account.copyWith(
            currentBalance: previousTransaction.reverseFromAccountBalance(
              account.currentBalance,
            ),
          );
        }
      }

      if (nextTransaction != null) {
        final account = updatedById[nextTransaction.accountId];
        if (account != null) {
          updatedById[account.id] = account.copyWith(
            currentBalance: nextTransaction.applyToAccountBalance(
              account.currentBalance,
            ),
          );
        }
      }

      final accountsNotifier = ref.read(accountsProvider.notifier);
      for (final account in updatedById.values) {
        final original = originalById[account.id];
        if (original != null &&
            original.currentBalance != account.currentBalance) {
          await accountsNotifier.saveAccount(account);
        }
      }
    } catch (_) {
      return;
    }
  }

  Future<void> _reconcileAccountBalances(
    List<FinanceTransaction> transactions,
  ) async {
    if (transactions.isEmpty) {
      return;
    }

    try {
      final accounts = await ref.read(accountsProvider.future);
      final accountsNotifier = ref.read(accountsProvider.notifier);

      for (final account in accounts) {
        final accountTransactions = transactions.where(
          (transaction) => transaction.accountId == account.id,
        );
        if (accountTransactions.isEmpty) {
          continue;
        }

        var balance = Money.zero(account.currency);
        for (final transaction in accountTransactions) {
          balance = transaction.applyToAccountBalance(balance);
        }

        if (balance != account.currentBalance) {
          await accountsNotifier.saveAccount(
            account.copyWith(currentBalance: balance),
          );
        }
      }
    } catch (_) {
      return;
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
    try {
      final repo = ref.watch(accountRepositoryProvider);
      return repo.list();
    } catch (error, stackTrace) {
      // Surface to `AikoScreenState.error`; a recoverable empty state is
      // acceptable for fresh installs even with no secure-storage backend.
      Error.throwWithStackTrace(error, stackTrace);
    }
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
    final previousAccounts = state.value ?? const <Account>[];
    final children = SharedLimitResolver.resolve(
      accounts: previousAccounts,
      deletedId: id,
    );
    for (final c in children) {
      await saveAccount(c);
    }
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
    final customCategories = await repo.list();
    ref.keepAlive();
    return _combineWithDefaults(customCategories);
  }

  List<Category> _combineWithDefaults(List<Category> customCategories) {
    final nonDefaultCategories = customCategories
        .where((cat) => !cat.isDefault)
        .toList(growable: false);
    final activeCustomCategories = nonDefaultCategories
        .where((cat) => cat.isActive)
        .toList(growable: false);
    activeCustomCategories.sort(_compareCustomCategories);

    final userId = nonDefaultCategories.isNotEmpty
        ? nonDefaultCategories.first.userId
        : 'local-user';

    final defaults = const CategoryService().defaultCategoriesFor(userId);

    // Inactive custom rows act as tombstones so deleted custom categories do not
    // reappear as generated defaults with the same name/type.
    final customKeys = nonDefaultCategories
        .map((cat) => '${cat.name.toLowerCase()}-${cat.type.name}')
        .toSet();

    final uniqueDefaults = defaults
        .where((cat) {
          final key = '${cat.name.toLowerCase()}-${cat.type.name}';
          return !customKeys.contains(key);
        })
        .toList(growable: false);

    return [...uniqueDefaults, ...activeCustomCategories];
  }

  int _compareCustomCategories(Category a, Category b) {
    final createdAtA = a.createdAt;
    final createdAtB = b.createdAt;
    if (createdAtA != null && createdAtB != null) {
      final byCreatedAt = createdAtA.compareTo(createdAtB);
      if (byCreatedAt != 0) {
        return byCreatedAt;
      }
    } else if (createdAtA != null) {
      return 1;
    } else if (createdAtB != null) {
      return -1;
    }
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  }

  Future<void> addCategory(Category category) async {
    await saveCategory(category);
  }

  Future<void> saveCategory(Category category) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(categoryRepositoryProvider);
      await repo.save(category);
      final customCategories = await repo.list();
      return _combineWithDefaults(customCategories);
    });
    if (state.hasError) {
      Error.throwWithStackTrace(state.error!, state.stackTrace!);
    }
  }

  Future<void> deleteCategory(String id) async {
    final previousCategories = state.hasValue ? state.value : null;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(categoryRepositoryProvider);
      Category? category;
      for (final item in previousCategories ?? const <Category>[]) {
        if (item.id == id) {
          category = item;
          break;
        }
      }
      if (category == null || category.isDefault) {
        await repo.delete(id);
      } else {
        await repo.save(const CategoryService().archive(category));
      }
      if (previousCategories != null) {
        return previousCategories
            .where((category) => category.id != id)
            .toList(growable: false);
      }
      final customCategories = await repo.list();
      return _combineWithDefaults(customCategories);
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

class CategoryGroupsNotifier extends AsyncNotifier<List<CategoryGroup>> {
  @override
  Future<List<CategoryGroup>> build() async {
    final repo = ref.watch(categoryGroupRepositoryProvider);
    final userGroups = await repo.list();
    // The 13 global default groups are injected in-memory (mirroring how
    // CategoryDefaults are injected into the categories list) and always sort
    // after the user's own groups, in deliberate internal order.
    return [...userGroups, ...CategoryGroupDefaults.all];
  }

  Future<void> saveGroup(CategoryGroup group) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(categoryGroupRepositoryProvider);
      await repo.save(group);
      return repo.list();
    });
    if (state.hasError) {
      Error.throwWithStackTrace(state.error!, state.stackTrace!);
    }
  }

  /// Deletes a group. Categories assigned to it are moved back to "Ungrouped"
  /// by clearing their `groupId`, then the categories list is refreshed.
  Future<void> deleteGroup(String id) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final categoryRepo = ref.read(categoryRepositoryProvider);
      final categories = await categoryRepo.list();
      for (final category in categories) {
        if (category.groupId == id) {
          await categoryRepo.save(category.copyWith(groupId: null));
        }
      }

      final groupRepo = ref.read(categoryGroupRepositoryProvider);
      await groupRepo.delete(id);
      return groupRepo.list();
    });
    if (state.hasError) {
      Error.throwWithStackTrace(state.error!, state.stackTrace!);
    }
    ref.invalidate(categoriesProvider);
  }
}

final categoryGroupsProvider =
    AsyncNotifierProvider.autoDispose<
      CategoryGroupsNotifier,
      List<CategoryGroup>
    >(() {
      return CategoryGroupsNotifier();
    });

class BudgetsNotifier extends AsyncNotifier<List<Budget>> {
  @override
  Future<List<Budget>> build() async {
    try {
      final repo = ref.watch(budgetRepositoryProvider);
      final budgets = await repo.list();
      ref.keepAlive();
      return budgets;
    } catch (error, stackTrace) {
      // Surface to `AikoScreenState.error`; offline + secure-storage broken
      // must render a recoverable error widget, not a provider-tree crash.
      Error.throwWithStackTrace(error, stackTrace);
    }
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
    try {
      final repo = ref.watch(goalRepositoryProvider);
      final goals = await repo.list();
      ref.keepAlive();
      return goals;
    } catch (error, stackTrace) {
      // Surface to `AikoScreenState.error`; offline + secure-storage broken
      // must render a recoverable error widget, not a provider-tree crash.
      Error.throwWithStackTrace(error, stackTrace);
    }
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

final profileProvider = FutureProvider.autoDispose<Profile>((ref) {
  final repo = ref.watch(profileRepositoryProvider);
  return repo.load();
});

final aikoInsightsProvider = FutureProvider.autoDispose<List<AikoInsight>>((
  ref,
) async {
  final repo = ref.watch(aikoInsightRepositoryProvider);
  return repo.list();
});

final dashboardSummaryProvider = FutureProvider.autoDispose<DashboardSummary>((
  ref,
) async {
  try {
    final repo = ref.watch(dashboardRepositoryProvider);
    final summary = await repo.loadSummary();
    // Keep the computed summary cached across tab switches so the Overview
    // shows instantly on return; pull-to-refresh recomputes it on demand.
    ref.keepAlive();
    return summary;
  } catch (error, stackTrace) {
    // Surface to `AikoScreenState.error`; a broken offline store must render
    // a recoverable error widget on the Overview, not crash the dashboard.
    Error.throwWithStackTrace(error, stackTrace);
  }
});

final dashboardDueItemsProvider =
    FutureProvider.autoDispose<List<DashboardDueItem>>((ref) async {
      try {
        final repo = ref.watch(dashboardDueItemRepositoryProvider);
        final items = await repo.loadUpcomingItems(DateTime.now());
        ref.keepAlive();
        return items;
      } catch (error, stackTrace) {
        // Surface to `AikoScreenState.error`; offline + secure-storage broken
        // must render a recoverable error widget, not a provider-tree crash.
        Error.throwWithStackTrace(error, stackTrace);
      }
    });

class DashboardLayoutNotifier
    extends AsyncNotifier<List<DashboardWidgetPreference>> {
  @override
  Future<List<DashboardWidgetPreference>> build() {
    return ref.watch(dashboardLayoutRepositoryProvider).load();
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    final layout = [...?state.value];
    if (layout.isEmpty) {
      return;
    }
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final item = layout.removeAt(oldIndex);
    layout.insert(newIndex, item);
    await _save(_withPositions(layout));
  }

  Future<void> reorderItem(int oldIndex, int newIndex) async {
    final layout = [...?state.value];
    if (layout.isEmpty) {
      return;
    }
    final item = layout.removeAt(oldIndex);
    layout.insert(newIndex, item);
    await _save(_withPositions(layout));
  }

  Future<void> removeWidget(DashboardWidgetType type) async {
    await _setVisibility(type, false);
  }

  Future<void> addWidget(DashboardWidgetType type) async {
    await _setVisibility(type, true);
  }

  Future<void> resetToDefault() async {
    await _save(DashboardWidgetPreference.defaultLayout);
  }

  Future<void> _setVisibility(DashboardWidgetType type, bool isVisible) async {
    final layout = [
      for (final item in [...?state.value])
        item.type == type ? item.copyWith(isVisible: isVisible) : item,
    ];
    await _save(_withPositions(layout));
  }

  Future<void> _save(List<DashboardWidgetPreference> layout) async {
    state = AsyncData(layout);
    await ref.read(dashboardLayoutRepositoryProvider).save(layout);
  }

  List<DashboardWidgetPreference> _withPositions(
    List<DashboardWidgetPreference> layout,
  ) {
    return [
      for (var index = 0; index < layout.length; index++)
        layout[index].copyWith(position: index),
    ];
  }
}

final dashboardLayoutProvider =
    AsyncNotifierProvider<
      DashboardLayoutNotifier,
      List<DashboardWidgetPreference>
    >(DashboardLayoutNotifier.new);
