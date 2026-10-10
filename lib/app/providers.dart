import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/config/app_config.dart';
import '../core/notifications/transaction_reminder_service.dart';
import '../features/dashboard/application/dashboard_summary_builder.dart';
import '../features/transactions/data/transaction_repository.dart';
import '../features/accounts/application/shared_limit_resolver.dart';
import '../features/accounts/data/account_repository.dart';
import '../features/accounts/domain/account.dart';
import '../features/categories/data/category_repository.dart';
import '../features/categories/data/category_group_repository.dart';
import '../features/categories/domain/category.dart';
import '../features/categories/domain/category_defaults.dart';
import '../features/dashboard/domain/app_notification.dart';
import '../features/dashboard/domain/dashboard_due_item.dart';
import '../features/dashboard/domain/dashboard_summary.dart';
import '../features/investments/application/allocation_service.dart';
import '../features/overview/application/budget_insights_service.dart';
import '../features/overview/application/cash_flow_service.dart';
import '../features/overview/application/goal_forecast_service.dart';
import '../features/overview/application/monthly_report_service.dart';
import '../features/overview/domain/monthly_report.dart';
import '../features/investments/application/investments_provider.dart';
import '../features/settings/data/profile_repository.dart';
import '../features/settings/domain/profile.dart';
import '../features/transactions/domain/transaction.dart';
import '../features/investments/data/investment_holding_repository.dart';
import '../core/money/money.dart';
import '../core/money/exchange_rate_service.dart';
import '../core/firebase/firebase_backend.dart';
import '../core/offline/firestore_sync_state.dart';
import '../core/offline/offline_user_context.dart';
import '../l10n/app_localizations.dart';
import 'locale_controller.dart';

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepository();
});

/// Live FX rates for the transaction form's currency conversion. Overridable in
/// tests so widget tests don't hit the network.
final exchangeRateServiceProvider = Provider<ExchangeRateService>((ref) {
  return const ExchangeRateService();
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
      // Top up bounded reminder series (once per launch; no-op on web).
      unawaited(
        TransactionReminderService.instance.resyncBounded(transactions),
      );
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
    // Reconciled balances are written back, so only reconcile once both
    // collections reflect the server; a stale cache must not overwrite a newer
    // balance from another device.
    if (FirebaseBackend.userId != null &&
        !FirestoreSyncState.instance.allServerSynced(const [
          'accounts',
          'transactions',
        ])) {
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
      return await repo.list();
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
      final userId = await repo.currentUserId();
      final storedCategories = await repo.list(userId: userId);
      // Keep the merged category list cached across tab switches so the
      // Overview / Categories screens render instantly on return; pull-to-
      // refresh recomputes it on demand. A failed load is not cached.
      ref.keepAlive();
      return _combineWithDefaults(storedCategories, userId: userId);
    } catch (error, stackTrace) {
      // Surface to `AikoScreenState.error`; a broken offline store must
      // render a recoverable empty/error widget, not crash the provider tree.
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  List<Category> _combineWithDefaults(
    List<Category> storedCategories, {
    required String userId,
  }) {
    if (userId.startsWith(OfflineUserContext.localUserIdPrefix)) {
      final overlays = <String, Category>{
        for (final category in storedCategories)
          if (CategoryDefaults.allIds.contains(category.id))
            category.id: category,
      };
      final customCategories =
          storedCategories
              .where(
                (category) => !CategoryDefaults.allIds.contains(category.id),
              )
              .where((category) => category.isActive)
              .toList(growable: false)
            ..sort(_compareCustomCategories);
      final defaults = CategoryDefaults.all.map((template) {
        final overlay = overlays[template.id];
        return overlay == null
            ? template
            : template.copyWith(
                monthlyLimit: overlay.monthlyLimit,
                budgetPeriod: overlay.budgetPeriod,
                rolloverUnused: overlay.rolloverUnused,
                budgetEnabled: overlay.budgetEnabled,
                alertThresholds: overlay.alertThresholds,
              );
      });
      return [...defaults, ...customCategories];
    }

    final clones = <String, Category>{
      for (final category in storedCategories)
        if (category.templateId != null) category.templateId!: category,
    };
    final legacy = <String, Category>{
      for (final category in storedCategories)
        if (category.templateId == null &&
            CategoryDefaults.allIds.contains(category.id))
          category.id: category,
    };
    final activeCustomCategories = storedCategories
        .where(
          (category) =>
              category.templateId == null &&
              !CategoryDefaults.allIds.contains(category.id) &&
              category.isActive,
        )
        .map(
          (category) =>
              CategoryDefaults.normalizeForUser(category, userId: userId),
        )
        .toList(growable: false);
    activeCustomCategories.sort(_compareCustomCategories);

    final defaults = CategoryDefaults.all.map((template) {
      final stored = clones[template.id] ?? legacy[template.id];
      return stored == null
          ? CategoryDefaults.cloneForUser(userId: userId, template: template)
          : CategoryDefaults.normalizeForUser(stored, userId: userId);
    });

    return [...defaults, ...activeCustomCategories];
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
      final userId = await repo.currentUserId();
      final storedCategories = await repo.list(userId: userId);
      return _combineWithDefaults(storedCategories, userId: userId);
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
      final userId = await repo.currentUserId();
      final storedCategories = await repo.list(userId: userId);
      return _combineWithDefaults(storedCategories, userId: userId);
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
      final userId = await repo.currentUserId();
      return _merge(await repo.list(userId: userId), userId: userId);
    } catch (error, stackTrace) {
      // Surface to `AikoScreenState.error`; offline + secure-storage broken
      // must render a recoverable error widget, not a provider-tree crash.
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  List<CategoryGroup> _merge(
    List<CategoryGroup> storedGroups, {
    required String userId,
  }) {
    if (userId.startsWith(OfflineUserContext.localUserIdPrefix)) {
      final overlays = <String, CategoryGroup>{
        for (final group in storedGroups)
          if (CategoryGroupDefaults.systemIds.contains(group.id))
            group.id: group,
      };
      final userGroups = storedGroups
          .where((group) => !CategoryGroupDefaults.systemIds.contains(group.id))
          .toList(growable: false);
      final defaults = CategoryGroupDefaults.all.map((template) {
        final overlay = overlays[template.id];
        return overlay == null
            ? template
            : template.copyWith(budgetLimit: overlay.budgetLimit);
      });
      return [...userGroups, ...defaults];
    }

    final clones = <String, CategoryGroup>{
      for (final group in storedGroups)
        if (group.templateId != null) group.templateId!: group,
    };
    final legacy = <String, CategoryGroup>{
      for (final group in storedGroups)
        if (group.templateId == null &&
            CategoryGroupDefaults.systemIds.contains(group.id))
          group.id: group,
    };
    final userGroups = storedGroups
        .where(
          (group) =>
              group.templateId == null &&
              !CategoryGroupDefaults.systemIds.contains(group.id),
        )
        .toList(growable: false);
    final defaults = CategoryGroupDefaults.all.map((template) {
      final stored = clones[template.id] ?? legacy[template.id];
      return stored == null
          ? CategoryGroupDefaults.cloneForUser(
              userId: userId,
              template: template,
            )
          : CategoryGroupDefaults.normalizeForUser(stored, userId: userId);
    });
    return [...userGroups, ...defaults];
  }

  Future<void> saveGroup(CategoryGroup group) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(categoryGroupRepositoryProvider);
      await repo.save(group);
      final userId = await repo.currentUserId();
      return _merge(await repo.list(userId: userId), userId: userId);
    });
    if (state.hasError) {
      Error.throwWithStackTrace(state.error!, state.stackTrace!);
    }
  }

  /// Deletes a group. Categories assigned to it are moved back to "Ungrouped"
  /// by clearing their `groupId`, then the categories list is refreshed.
  Future<void> deleteGroup(String id) async {
    final currentGroups = state.value;
    if (currentGroups != null &&
        currentGroups.any((group) => group.id == id && group.isDefault)) {
      throw StateError('Default category groups cannot be deleted.');
    }
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
      final userId = await groupRepo.currentUserId();
      return _merge(await groupRepo.list(userId: userId), userId: userId);
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

/// Exchange rates quoted against a base currency, fetched once per session
/// (one request) and only by callers that hold foreign-currency amounts.
/// Empty when offline; callers leave unconverted amounts out and say so.
final fxRatesProvider = FutureProvider.autoDispose
    .family<Map<String, Decimal>, String>((ref, baseCurrency) async {
      final rates = await ref
          .read(exchangeRateServiceProvider)
          .fetchRates(baseCurrency);
      if (rates == null) return const {};
      ref.keepAlive();
      return rates;
    });

final dashboardSummaryProvider = FutureProvider.autoDispose<DashboardSummary>((
  ref,
) async {
  try {
    final accounts = await ref.watch(accountsProvider.future);
    final transactions = await ref.watch(transactionsProvider.future);
    String baseCurrency;
    try {
      baseCurrency = (await ref.watch(profileProvider.future)).baseCurrency;
    } catch (_) {
      baseCurrency = kDefaultBaseCurrency;
    }
    final now = DateTime.now();
    final needsRates = foreignCurrencies(
      baseCurrency: baseCurrency,
      accounts: accounts,
      transactions: transactions,
      now: now,
    ).isNotEmpty;
    final rates = needsRates
        ? await ref.watch(fxRatesProvider(baseCurrency).future)
        : const <String, Decimal>{};
    final summary = buildDashboardSummary(
      accounts: accounts,
      transactions: transactions,
      converter: CurrencyConverter(baseCurrency, rates),
      now: now,
    );
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

/// Monthly Report figures derived live from the user's real transactions and
/// categories. No mock data — returns an empty-but-valid report when there is
/// nothing logged this month.
final monthlyReportProvider = FutureProvider.autoDispose<MonthlyReport>((
  ref,
) async {
  final transactions = await ref.watch(transactionsProvider.future);
  final categories = await ref.watch(categoriesProvider.future);
  final report = const MonthlyReportService().build(
    transactions: transactions,
    categories: categories,
    asOf: DateTime.now(),
    l10n: _l10nOf(ref),
  );
  ref.keepAlive();
  return report;
});

/// Cash-flow overview (this month's in/out/net + 12-month net trend) from real
/// transactions.
final cashFlowOverviewProvider = FutureProvider.autoDispose<CashFlowOverview>((
  ref,
) async {
  final transactions = await ref.watch(transactionsProvider.future);
  final result = const CashFlowService().overview(
    transactions: transactions,
    asOf: DateTime.now(),
  );
  ref.keepAlive();
  return result;
});

/// Cash-flow Sankey breakdown (income vs outflow grouped by budget group).
final cashFlowSankeyProvider = FutureProvider.autoDispose<CashFlowSankey>((
  ref,
) async {
  final transactions = await ref.watch(transactionsProvider.future);
  final categories = await ref.watch(categoriesProvider.future);
  final result = const CashFlowService().sankey(
    transactions: transactions,
    categories: categories,
    asOf: DateTime.now(),
  );
  ref.keepAlive();
  return result;
});

/// Safe-to-spend leftover breakdown from real income, spending and budgets.
final safeToSpendProvider = FutureProvider.autoDispose<SafeToSpend>((
  ref,
) async {
  final transactions = await ref.watch(transactionsProvider.future);
  final categories = await ref.watch(categoriesProvider.future);
  final result = const BudgetInsightsService().safeToSpend(
    transactions: transactions,
    categories: categories,
    asOf: DateTime.now(),
  );
  ref.keepAlive();
  return result;
});

/// Portfolio allocation by asset class from real investment holdings.
final portfolioAllocationProvider =
    FutureProvider.autoDispose<PortfolioAllocation>((ref) async {
      final holdings = await ref.watch(investmentsProvider.future);
      final result = const AllocationService().build(holdings);
      ref.keepAlive();
      return result;
    });

/// Monte Carlo goal forecast for a single goal account, keyed by goal id so the
/// 1,000-run simulation is computed once and cached (stable across rebuilds).
/// Returns null when the goal no longer exists.
final goalForecastProvider = FutureProvider.autoDispose
    .family<GoalForecast?, String>((ref, goalId) async {
      final goals = await ref.watch(accountsProvider.future);
      Account? goal;
      for (final a in goals) {
        if (a.id == goalId && a.type == AccountType.goal) {
          goal = a;
          break;
        }
      }
      if (goal == null) return null;
      final forecast = const GoalForecastService().forecast(goal);
      ref.keepAlive();
      return forecast;
    });

final dashboardDueItemsProvider =
    FutureProvider.autoDispose<List<DashboardDueItem>>((ref) async {
      try {
        final accounts = await ref.watch(accountsProvider.future);
        final items = buildDashboardDueItems(
          accounts: accounts,
          asOf: DateTime.now(),
          l10n: _l10nOf(ref),
        );
        ref.keepAlive();
        return items;
      } catch (error, stackTrace) {
        // Surface to `AikoScreenState.error`; offline + secure-storage broken
        // must render a recoverable error widget, not a provider-tree crash.
        Error.throwWithStackTrace(error, stackTrace);
      }
    });

/// Strings for the selected language. Providers that build user-facing text
/// watch the language, so their text updates when it changes.
AppLocalizations _l10nOf(Ref ref) => lookupAppLocalizations(
  ref.watch(appLocaleControllerProvider).value?.locale ??
      AppLocaleController.fallbackLocale,
);

/// Notifications derived live from the user's real local data (budget
/// breaches, upcoming bills, goal milestones). No notifications table — this
/// recomputes on each open. Returns an empty list when nothing is noteworthy.
final notificationsProvider = FutureProvider.autoDispose<List<AppNotification>>(
  (ref) async {
    try {
      final transactions = await ref.watch(transactionsProvider.future);
      final categories = await ref.watch(categoriesProvider.future);
      final accounts = await ref.watch(accountsProvider.future);
      final dueItems = await ref.watch(dashboardDueItemsProvider.future);
      return buildNotifications(
        transactions: transactions,
        categories: categories,
        accounts: accounts,
        dueItems: dueItems,
        asOf: DateTime.now(),
        l10n: _l10nOf(ref),
      );
    } catch (error, stackTrace) {
      // Surface to `AikoScreenState.error`; a broken offline store renders a
      // recoverable error widget instead of crashing the provider tree.
      Error.throwWithStackTrace(error, stackTrace);
    }
  },
);

/// All accounts with `type = goal`, derived from [accountsProvider].
final goalAccountsDerivedProvider = Provider<AsyncValue<List<Account>>>((ref) {
  final accountsAsync = ref.watch(accountsProvider);
  return accountsAsync.whenData(
    (accounts) => accounts
        .where((a) => a.type == AccountType.goal)
        .toList(growable: false),
  );
});
