import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/transactions/data/transaction_repository.dart';
import '../features/accounts/application/shared_limit_resolver.dart';
import '../features/accounts/data/account_repository.dart';
import '../features/accounts/domain/account.dart';
import '../features/categories/data/category_repository.dart';
import '../features/categories/data/category_group_repository.dart';
import '../features/categories/domain/category.dart';
import '../features/categories/domain/category_defaults.dart';
import '../features/dashboard/data/dashboard_due_item_repository.dart';
import '../features/dashboard/data/dashboard_repository.dart';
import '../features/dashboard/domain/dashboard_due_item.dart';
import '../features/dashboard/domain/dashboard_summary.dart';
import '../features/insights/data/aiko_insight_repository.dart';
import '../features/insights/domain/aiko_insight.dart';
import '../features/settings/data/profile_repository.dart';
import '../features/settings/domain/profile.dart';
import '../features/transactions/domain/transaction.dart';
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
    try {
      final repo = ref.watch(categoryRepositoryProvider);
      final customCategories = await repo.list();
      // Keep the merged category list cached across tab switches so the
      // Overview / Categories screens render instantly on return; pull-to-
      // refresh recomputes it on demand. A failed load is not cached.
      ref.keepAlive();
      return _combineWithDefaults(customCategories);
    } catch (error, stackTrace) {
      // Surface to `AikoScreenState.error`; a broken offline store must
      // render a recoverable empty/error widget, not crash the provider tree.
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  List<Category> _combineWithDefaults(List<Category> customCategories) {
    final nonDefaultCategories = customCategories
        .where((cat) => !cat.isDefault)
        .toList(growable: false);
    final activeCustomCategories = nonDefaultCategories
        .where((cat) => cat.isActive)
        .toList(growable: false);
    activeCustomCategories.sort(_compareCustomCategories);

    final defaults = CategoryDefaults.all;

    // Inactive custom rows act as tombstones so deleted custom categories do not
    // reappear as generated defaults with the same name/type.
    final customKeys = nonDefaultCategories
        .map((cat) => '${cat.name.toLowerCase()}-${cat.type.name}')
        .toSet();

    // Stored rows carrying a default's id are budget overlays: the default
    // stays read-only, but the user's limit/period/rollover ride on top.
    final overlays = <String, Category>{
      for (final cat in customCategories)
        if (cat.isDefault) cat.id: cat,
    };

    final uniqueDefaults = defaults
        .where((cat) {
          final key = '${cat.name.toLowerCase()}-${cat.type.name}';
          return !customKeys.contains(key);
        })
        .map((cat) {
          final overlay = overlays[cat.id];
          return overlay == null
              ? cat
              : cat.copyWith(
                  monthlyLimit: overlay.monthlyLimit,
                  budgetPeriod: overlay.budgetPeriod,
                  rolloverUnused: overlay.rolloverUnused,
                  budgetEnabled: overlay.budgetEnabled,
                  alertThresholds: overlay.alertThresholds,
                );
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
        await repo.save(category.copyWith(isActive: false));
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
    try {
      final repo = ref.watch(categoryGroupRepositoryProvider);
      return _merge(await repo.list());
    } catch (error, stackTrace) {
      // Surface to `AikoScreenState.error`; offline + secure-storage broken
      // must render a recoverable error widget, not a provider-tree crash.
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  /// Combines stored groups with the 13 in-memory defaults. A stored row whose
  /// id matches a default group is a per-user *budget overlay*: the default
  /// stays read-only but its [CategoryGroup.budgetLimit] rides on top. The 13
  /// defaults always sort after the user's own groups, in declared order.
  List<CategoryGroup> _merge(List<CategoryGroup> storedGroups) {
    final overlays = <String, CategoryGroup>{
      for (final group in storedGroups)
        if (group.isSystem) group.id: group,
    };
    final userGroups = storedGroups
        .where((group) => !group.isSystem)
        .toList(growable: false);
    final defaults = CategoryGroupDefaults.all.map((group) {
      final overlay = overlays[group.id];
      return overlay == null
          ? group
          : group.copyWith(budgetLimit: overlay.budgetLimit);
    });
    return [...userGroups, ...defaults];
  }

  Future<void> saveGroup(CategoryGroup group) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(categoryGroupRepositoryProvider);
      await repo.save(group);
      return _merge(await repo.list());
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
      return _merge(await groupRepo.list());
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

// PR5 of the budgets -> categories / goals -> accounts merge: the
// `BudgetsNotifier`, `GoalsNotifier`, `budgetsProvider`, and `goalsProvider`
// are gone. Budgets are stored on `Category`; goals are accounts with
// `type = AccountType.goal`. Use `categoriesProvider` / `accountsProvider`
// (and the derived `goalAccountsDerivedProvider` for the merge-friendly views).

final profileProvider = FutureProvider.autoDispose<Profile>((ref) {
  try {
    final repo = ref.watch(profileRepositoryProvider);
    return repo.load();
  } catch (error, stackTrace) {
    // Surface to `AikoScreenState.error`; offline + secure-storage broken
    // must render a recoverable error widget, not a provider-tree crash.
    Error.throwWithStackTrace(error, stackTrace);
  }
});

final aikoInsightsProvider = FutureProvider.autoDispose<List<AikoInsight>>((
  ref,
) async {
  try {
    final repo = ref.watch(aikoInsightRepositoryProvider);
    return repo.list();
  } catch (error, stackTrace) {
    // Surface to `AikoScreenState.error`; offline + secure-storage broken
    // must render a recoverable error widget, not a provider-tree crash.
    Error.throwWithStackTrace(error, stackTrace);
  }
});

/// Single source of truth for the Supabase runtime configuration that the app
/// compiled with. `AikoSupabase` (`lib/core/supabase/`) owns the
/// *initialised* client; this provider only exposes the raw env values so
/// callers (e.g. the chat engine) can decide between cloud and offline paths
/// without re-reading `String.fromEnvironment` themselves.
class AikoSupabaseConfig {
  const AikoSupabaseConfig({required this.url});
  final String url;
  bool get isConfigured => url.isNotEmpty;
}

final aikoSupabaseConfigProvider = Provider<AikoSupabaseConfig>((ref) {
  const url = String.fromEnvironment('SUPABASE_URL');
  return AikoSupabaseConfig(url: url);
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

// ---------------------------------------------------------------------------
// Budgets -> Categories and Goals -> Accounts merge (PR2)
// ---------------------------------------------------------------------------
//
// The new derived providers below let the dashboard and detail screens read
// budget / goal data from the `categories` and `accounts` providers without
// touching the legacy `BudgetRepository` / `GoalRepository`. PR5 removes
// those repositories entirely.

/// All accounts with `type = goal`. Source of truth for the dashboard's
/// Aiko Goal Simulator panel and the goal detail screens.
final goalAccountsDerivedProvider = Provider<AsyncValue<List<Account>>>((ref) {
  final accountsAsync = ref.watch(accountsProvider);
  return accountsAsync.whenData(
    (accounts) => accounts
        .where((a) => a.type == AccountType.goal)
        .toList(growable: false),
  );
});
