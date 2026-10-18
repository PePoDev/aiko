import '../core/money/money.dart';
import '../features/investments/application/portfolio_valuation.dart';
import '../features/transactions/application/legacy_opening_balances.dart';
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/config/app_config.dart';
import '../core/notifications/transaction_reminder_service.dart';
import '../features/dashboard/application/dashboard_summary_builder.dart';
import '../features/transactions/application/transaction_totals.dart';
import '../features/dashboard/application/notification_dismissals.dart';
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
import '../core/money/exchange_rate_service.dart';
import '../core/money/exchange_rates.dart';
import '../core/firebase/firebase_backend.dart';
import '../core/offline/firestore_sync_state.dart';
import '../core/offline/offline_store.dart';
import '../core/offline/offline_user_context.dart';
import '../core/storage/secure_storage_service.dart';
import '../core/storage/synced_preferences.dart';
import '../l10n/app_localizations.dart';
import 'exchange_rates_provider.dart';
import 'locale_controller.dart';

export 'exchange_rates_provider.dart';

/// Commits the record batches that keep multi-record changes atomic (both
/// legs of a transfer with their balances, an account with its opening
/// balance, ...). Overridden in tests together with the repositories.
final offlineStoreProvider = Provider<OfflineStore>((ref) => OfflineStore());

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
      var transactions = await repo.list();
      transactions = await _convertLegacyOpeningBalances(repo, transactions);
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

  /// Opening balances saved before they became adjustments counted as
  /// income or spending; rewrite them once as signed adjustments (the
  /// balance effect is the same), in one batch. Best-effort: a failed write
  /// is retried on the next load.
  Future<List<FinanceTransaction>> _convertLegacyOpeningBalances(
    TransactionRepository repo,
    List<FinanceTransaction> transactions,
  ) async {
    final fixes = legacyOpeningBalanceFixes(transactions);
    if (fixes.isEmpty) return transactions;
    try {
      final batch = RecordBatch();
      final saved = <String, FinanceTransaction>{
        for (final fix in fixes) fix.id: await repo.save(fix, batch: batch),
      };
      // Each fix stands alone, so a very large set may take several batches.
      await ref.read(offlineStoreProvider).commit(batch, allowChunks: true);
      return [for (final t in transactions) saved[t.id] ?? t];
    } catch (_) {
      // Leave them as they were; the next load tries again.
      return transactions;
    }
  }

  /// Saves [transaction] (insert or update) and keeps account balances in
  /// step. The list updates in place: no loading flash, and a failed save
  /// leaves the previous list showing before rethrowing.
  Future<FinanceTransaction> saveTransaction(
    FinanceTransaction transaction, {
    bool updateAccountBalance = true,
  }) async {
    final saved = await saveTransactions([
      transaction,
    ], updateAccountBalance: updateAccountBalance);
    return saved.single;
  }

  /// Saves several rows (both legs of a transfer) together with the account
  /// balances they change as one atomic write, and updates the list once. A
  /// failure saves nothing, keeps the previous list and is rethrown.
  Future<List<FinanceTransaction>> saveTransactions(
    List<FinanceTransaction> transactions, {
    bool updateAccountBalance = true,
  }) async {
    final repo = ref.read(transactionRepositoryProvider);
    final current = state.value ?? await repo.list();
    final batch = RecordBatch();
    final replaced = <FinanceTransaction>[];
    final saved = <FinanceTransaction>[];
    for (final transaction in transactions) {
      final previousTransaction = _transactionById(current, transaction.id);
      if (previousTransaction != null) replaced.add(previousTransaction);
      saved.add(await repo.save(transaction, batch: batch));
    }
    final accounts = updateAccountBalance
        ? await _stageAccountBalances(batch, removed: replaced, added: saved)
        : const <Account>[];
    await ref.read(offlineStoreProvider).commit(batch);
    _showSavedAccounts(accounts);
    if (ref.mounted) {
      state = AsyncValue.data(
        upsertTransactionsByDate(state.value ?? current, saved),
      );
    }
    return saved;
  }

  /// Shows rows that were already written together with another record (an
  /// account's opening balance), without reading the list again.
  void showSaved(List<FinanceTransaction> saved) {
    final current = state.value;
    if (current == null) {
      ref.invalidateSelf();
      return;
    }
    state = AsyncValue.data(upsertTransactionsByDate(current, saved));
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

  /// Deletes [id] and, for a linked transfer leg, its partner leg too, so a
  /// transfer never loses one side, together with the balance changes as one
  /// atomic write. Returns the ids removed. A failure deletes nothing, keeps
  /// the previous list and rethrows.
  Future<List<String>> deleteTransaction(String id) async {
    final repo = ref.read(transactionRepositoryProvider);
    final current = state.value ?? await repo.list();
    final target = _transactionById(current, id);
    final partners = target == null
        ? const <FinanceTransaction>[]
        : transferPartnersOf(target, current);
    final batch = RecordBatch();
    await repo.delete(id, batch: batch);
    for (final partner in partners) {
      await repo.delete(partner.id, batch: batch);
    }
    final accounts = await _stageAccountBalances(
      batch,
      removed: [?target, ...partners],
    );
    await ref.read(offlineStoreProvider).commit(batch);
    _showSavedAccounts(accounts);
    final deletedIds = {id, for (final partner in partners) partner.id};
    if (ref.mounted) {
      state = AsyncValue.data([
        for (final transaction in state.value ?? current)
          if (!deletedIds.contains(transaction.id)) transaction,
      ]);
    }
    return deletedIds.toList(growable: false);
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

  /// Stages into [batch] the account balances that change when [removed]
  /// rows are taken out of the ledger and [added] rows go in. Returns the
  /// changed accounts. Accounts that can't be read are left alone; the next
  /// load reconciles their balances.
  Future<List<Account>> _stageAccountBalances(
    RecordBatch batch, {
    Iterable<FinanceTransaction> removed = const [],
    Iterable<FinanceTransaction> added = const [],
  }) async {
    final List<Account> accounts;
    try {
      accounts = await ref.read(accountsProvider.future);
    } catch (_) {
      return const [];
    }
    final originalById = {for (final account in accounts) account.id: account};
    final updatedById = {...originalById};
    for (final transaction in removed) {
      final account = updatedById[transaction.accountId];
      if (account != null) {
        updatedById[account.id] = account.copyWith(
          currentBalance: transaction.reverseFromAccountBalance(
            account.currentBalance,
          ),
        );
      }
    }
    for (final transaction in added) {
      final account = updatedById[transaction.accountId];
      if (account != null) {
        updatedById[account.id] = account.copyWith(
          currentBalance: transaction.applyToAccountBalance(
            account.currentBalance,
          ),
        );
      }
    }
    final repo = ref.read(accountRepositoryProvider);
    return [
      for (final account in updatedById.values)
        if (originalById[account.id]!.currentBalance != account.currentBalance)
          await repo.save(account, batch: batch),
    ];
  }

  /// Shows balances that were written with this notifier's batch.
  void _showSavedAccounts(List<Account> accounts) {
    if (accounts.isEmpty || !ref.mounted) return;
    ref.read(accountsProvider.notifier).showSaved(accounts);
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
      final accountsById = {
        for (final account in accounts) account.id: account,
      };

      // One pass over the ledger, in order: each account's balance replays
      // only its own transactions.
      final balances = <String, Money>{};
      for (final transaction in transactions) {
        final account = accountsById[transaction.accountId];
        if (account == null) {
          continue;
        }
        balances[account.id] = transaction.applyToAccountBalance(
          balances[account.id] ?? Money.zero(account.currency),
        );
      }

      final repo = ref.read(accountRepositoryProvider);
      final batch = RecordBatch();
      final changed = <Account>[];
      for (final account in accounts) {
        final balance = balances[account.id];
        if (balance != null && balance != account.currentBalance) {
          changed.add(
            await repo.save(
              account.copyWith(currentBalance: balance),
              batch: batch,
            ),
          );
        }
      }
      // Each balance stands alone; many accounts may take several batches.
      await ref.read(offlineStoreProvider).commit(batch, allowChunks: true);
      _showSavedAccounts(changed);
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

  /// Saves [account] and, when given, the [adjustment] transaction that backs
  /// its balance (a new account's opening balance or an edited balance) as
  /// one atomic write. The adjustment doesn't move the balance again.
  Future<void> saveAccount(
    Account account, {
    FinanceTransaction? adjustment,
  }) async {
    final previous = state.value;
    FinanceTransaction? savedAdjustment;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(accountRepositoryProvider);
      final batch = RecordBatch();
      final saved = await repo.save(account, batch: batch);
      if (adjustment != null) {
        savedAdjustment = await ref
            .read(transactionRepositoryProvider)
            .save(adjustment, batch: batch);
      }
      await ref.read(offlineStoreProvider).commit(batch);
      return previous == null ? repo.list() : _withSaved(previous, [saved]);
    });
    if (state.hasError) {
      Error.throwWithStackTrace(state.error!, state.stackTrace!);
    }
    final shownAdjustment = savedAdjustment;
    if (shownAdjustment != null && ref.exists(transactionsProvider)) {
      ref.read(transactionsProvider.notifier).showSaved([shownAdjustment]);
    }
  }

  /// Shows accounts that were already written (balances kept in step with
  /// transactions) without reading the list again.
  void showSaved(List<Account> saved) {
    final current = state.value;
    if (current == null) {
      ref.invalidateSelf();
      return;
    }
    state = AsyncValue.data(_withSaved(current, saved));
  }

  /// [current] with [saved] accounts replaced or added, in the repository's
  /// order (by name).
  static List<Account> _withSaved(List<Account> current, List<Account> saved) {
    final savedById = {for (final account in saved) account.id: account};
    final merged = [
      for (final account in current) savedById.remove(account.id) ?? account,
      ...savedById.values,
    ];
    final sorted = [...merged]..sort((a, b) => a.name.compareTo(b.name));
    for (var i = 0; i < merged.length; i++) {
      // Same order as before (balance updates): keep equal names in place.
      if (merged[i].name != sorted[i].name) return sorted;
    }
    return merged;
  }

  /// Deletes the account together with every transaction recorded on it, so
  /// none keep counting toward totals under an unknown account, and releases
  /// cards that shared its limit, as one write. Returns the deleted
  /// transactions (callers cancel their reminders).
  Future<List<FinanceTransaction>> deleteAccount(String id) async {
    final previousAccounts = state.value;
    final children = SharedLimitResolver.resolve(
      accounts: previousAccounts ?? const <Account>[],
      deletedId: id,
    );
    var deleted = const <FinanceTransaction>[];
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final transactionRepo = ref.read(transactionRepositoryProvider);
      deleted = [
        for (final transaction in await transactionRepo.list())
          if (transaction.accountId == id) transaction,
      ];
      final repo = ref.read(accountRepositoryProvider);
      final batch = RecordBatch();
      // The account is going away, so there is no balance to keep in step
      // per transaction. Transactions go first: a ledger too large for one
      // batch is deleted in several, and a failure part-way leaves the
      // account in place to retry.
      for (final transaction in deleted) {
        await transactionRepo.delete(transaction.id, batch: batch);
      }
      final released = [
        for (final child in children) await repo.save(child, batch: batch),
      ];
      await repo.delete(id, batch: batch);
      await ref.read(offlineStoreProvider).commit(batch, allowChunks: true);
      return previousAccounts == null
          ? repo.list()
          : _withSaved([
              for (final account in previousAccounts)
                if (account.id != id) account,
            ], released);
    });
    if (deleted.isNotEmpty) {
      ref.invalidate(transactionsProvider);
    }
    if (state.hasError) {
      Error.throwWithStackTrace(state.error!, state.stackTrace!);
    }
    return deleted;
  }
}

final accountsProvider =
    AsyncNotifierProvider.autoDispose<AccountsNotifier, List<Account>>(() {
      return AccountsNotifier();
    });

/// [stored] with [saved] in place of the record with its id (or added).
List<T> _withSavedRecord<T>(
  List<T> stored,
  T saved,
  String Function(T record) idOf,
) {
  final id = idOf(saved);
  final index = stored.indexWhere((record) => idOf(record) == id);
  if (index < 0) return [...stored, saved];
  return [...stored]..[index] = saved;
}

class CategoriesNotifier extends AsyncNotifier<List<Category>> {
  /// The stored categories the list was last built from, and whose they are:
  /// a save updates them in memory instead of reading the store again, which
  /// signed in on Android can be served before the write is applied.
  List<Category>? _stored;
  String? _storedFor;

  @override
  Future<List<Category>> build() async {
    try {
      final repo = ref.watch(categoryRepositoryProvider);
      final userId = await repo.currentUserId();
      final storedCategories = await repo.list(userId: userId);
      _stored = storedCategories;
      _storedFor = userId;
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
      final saved = await repo.save(category);
      final userId = await repo.currentUserId();
      final stored = _stored;
      final storedCategories = stored != null && _storedFor == userId
          ? _withSavedRecord(stored, saved, (category) => category.id)
          : await repo.list(userId: userId);
      _stored = storedCategories;
      _storedFor = userId;
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
      final stored = _stored;
      if (category == null || category.isDefault) {
        await repo.delete(id);
        if (stored != null) {
          _stored = [
            for (final item in stored)
              if (item.id != id) item,
          ];
        }
      } else {
        final archived = await repo.save(category.copyWith(isActive: false));
        if (stored != null) {
          _stored = _withSavedRecord(stored, archived, (item) => item.id);
        }
      }
      if (previousCategories != null) {
        return previousCategories
            .where((category) => category.id != id)
            .toList(growable: false);
      }
      final userId = await repo.currentUserId();
      final storedCategories = await repo.list(userId: userId);
      _stored = storedCategories;
      _storedFor = userId;
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

/// Every category a transaction can point at, for looking names up: the
/// active list from [categoriesProvider] plus archived (deleted) custom
/// categories, so older transactions keep showing their category. Pickers,
/// lists and budgets use [categoriesProvider], which leaves archived ones out.
final allCategoriesProvider = FutureProvider.autoDispose<List<Category>>((
  ref,
) async {
  final active = await ref.watch(categoriesProvider.future);
  final repo = ref.watch(categoryRepositoryProvider);
  final userId = await repo.currentUserId();
  return withArchivedCategories(active, await repo.list(userId: userId));
});

/// [active] followed by the archived custom categories in [stored] that it
/// does not already contain.
List<Category> withArchivedCategories(
  List<Category> active,
  List<Category> stored,
) {
  final activeIds = {for (final category in active) category.id};
  return [
    ...active,
    for (final category in stored)
      if (!category.isActive &&
          !category.isDefault &&
          !activeIds.contains(category.id))
        category,
  ];
}

class CategoryGroupsNotifier extends AsyncNotifier<List<CategoryGroup>> {
  /// The stored groups the list was last built from, and whose they are
  /// (see [CategoriesNotifier]).
  List<CategoryGroup>? _stored;
  String? _storedFor;

  @override
  Future<List<CategoryGroup>> build() async {
    try {
      final repo = ref.watch(categoryGroupRepositoryProvider);
      final userId = await repo.currentUserId();
      final storedGroups = await repo.list(userId: userId);
      _stored = storedGroups;
      _storedFor = userId;
      return _merge(storedGroups, userId: userId);
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
      final saved = await repo.save(group);
      final userId = await repo.currentUserId();
      final stored = _stored;
      final storedGroups = stored != null && _storedFor == userId
          ? (_withSavedRecord(stored, saved, (group) => group.id)
              ..sort(CategoryGroupRepository.compareGroups))
          : await repo.list(userId: userId);
      _stored = storedGroups;
      _storedFor = userId;
      return _merge(storedGroups, userId: userId);
    });
    if (state.hasError) {
      Error.throwWithStackTrace(state.error!, state.stackTrace!);
    }
  }

  /// Deletes a group. Categories assigned to it are moved back to "Ungrouped"
  /// by clearing their `groupId` in the same atomic write as the delete; then
  /// the categories list is refreshed.
  Future<void> deleteGroup(String id) async {
    final currentGroups = state.value;
    if (currentGroups != null &&
        currentGroups.any((group) => group.id == id && group.isDefault)) {
      throw StateError('Default category groups cannot be deleted.');
    }
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final categoryRepo = ref.read(categoryRepositoryProvider);
      final groupRepo = ref.read(categoryGroupRepositoryProvider);
      final batch = RecordBatch();
      for (final category in await categoryRepo.list()) {
        if (category.groupId == id) {
          await categoryRepo.save(
            category.copyWith(groupId: null),
            batch: batch,
          );
        }
      }
      await groupRepo.delete(id, batch: batch);
      await ref.read(offlineStoreProvider).commit(batch);
      final stored = _stored;
      if (stored != null) {
        _stored = [
          for (final group in stored)
            if (group.id != id) group,
        ];
      }
      if (currentGroups != null) {
        return [
          for (final group in currentGroups)
            if (group.id != id) group,
        ];
      }
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
        : ExchangeRates.none(baseCurrency);
    // A failed or saved-copy result is fetched again on each recompute
    // (pull-to-refresh, data changes); new rates recompute the summary.
    if (needsRates) {
      ref.read(fxRatesProvider(baseCurrency).notifier).retryIfStale();
    }
    final summary = buildDashboardSummary(
      accounts: accounts,
      transactions: transactions,
      converter: CurrencyConverter.from(rates),
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
/// Monthly report for the calendar month containing the key (pass the
/// month's first day, e.g. `DateTime(2026, 10)`).
final monthlyReportProvider = FutureProvider.autoDispose
    .family<MonthlyReport, DateTime>((ref, month) async {
      final transactions = await ref.watch(transactionsProvider.future);
      final categories = await ref.watch(categoriesProvider.future);
      final report = const MonthlyReportService().build(
        transactions: transactions,
        categories: categories,
        asOf: DateTime(month.year, month.month),
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
      String baseCurrency;
      try {
        baseCurrency = (await ref.watch(profileProvider.future)).baseCurrency;
      } catch (_) {
        baseCurrency = kDefaultBaseCurrency;
      }
      // Holdings in other currencies are re-priced into the base currency
      // (like the Investments screen) so their shares add up; holdings with
      // no rate are left out and listed so the screen can say so.
      final needsRates = holdings.any(
        (holding) =>
            holding.currency.toUpperCase() != baseCurrency.toUpperCase(),
      );
      final rates = needsRates
          ? await ref.watch(fxRatesProvider(baseCurrency).future)
          : ExchangeRates.none(baseCurrency);
      if (needsRates) {
        ref.read(fxRatesProvider(baseCurrency).notifier).retryIfStale();
      }
      final valued = valueHoldingsIn(holdings, CurrencyConverter.from(rates));
      final result = const AllocationService().build(
        valued.holdings,
        leftOut: valued.excludedHoldings,
        ratesAsOf: valued.ratesAsOf,
      );
      ref.keepAlive();
      return result;
    });

/// Monte Carlo goal forecast for a single goal account, keyed by goal id so the
/// 1,000-run simulation is computed once and cached (stable across rebuilds).
/// The saving rate comes from the goal account's own transactions. Returns
/// null when the goal no longer exists; a goal missing its target or date, or
/// past its date, comes back blocked instead of simulated.
final goalForecastProvider = FutureProvider.autoDispose
    .family<GoalForecastOutcome?, String>((ref, goalId) async {
      final goals = await ref.watch(accountsProvider.future);
      Account? goal;
      for (final a in goals) {
        if (a.id == goalId && a.type == AccountType.goal) {
          goal = a;
          break;
        }
      }
      if (goal == null) return null;
      final transactions = await ref.watch(transactionsProvider.future);
      final outcome = const GoalForecastService().evaluate(goal, transactions);
      ref.keepAlive();
      return outcome;
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

/// Every notification derived live from the user's real local data (budget
/// breaches, upcoming bills, goal milestones), dismissed or not. No
/// notifications table — this recomputes on each open.
final allNotificationsProvider =
    FutureProvider.autoDispose<List<AppNotification>>((ref) async {
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
    });

/// Where dismissed notification ids are kept (a synced preference); overridden
/// in tests.
final notificationDismissalStorageProvider = Provider<SecureStorageService>(
  (ref) => SyncedPreferences(),
);

/// Ids of the notifications the user dismissed (see
/// [NotificationDismissalStore]).
class NotificationDismissalsNotifier extends AsyncNotifier<Set<String>> {
  NotificationDismissalStore get _store => NotificationDismissalStore(
    ref.read(notificationDismissalStorageProvider),
  );

  @override
  Future<Set<String>> build() => NotificationDismissalStore(
    ref.watch(notificationDismissalStorageProvider),
  ).load();

  /// Writes one dismissal at a time, so quick taps don't overwrite each other.
  Future<void> _writes = Future.value();

  Future<void> dismiss(String id) {
    final store = _store;
    // Stored ids not among today's notifications belong to past periods and
    // are dropped; without the list, keep everything already dismissed.
    final keep =
        ref.read(allNotificationsProvider).value?.map((n) => n.id).toList() ??
        [...?state.value];
    // Hide it straight away; the write follows.
    state = AsyncData({...?state.value, id});
    return _writes = _writes.then((_) async {
      try {
        final saved = await store.dismiss(id, keep);
        if (ref.mounted) state = AsyncData({...saved, ...?state.value});
      } catch (_) {
        // Storage failed: it stays hidden for this session only.
      }
    });
  }
}

/// Never retried: dismissals that can't be read show every notification
/// straight away instead of keeping the screen loading.
final notificationDismissalsProvider =
    AsyncNotifierProvider.autoDispose<
      NotificationDismissalsNotifier,
      Set<String>
    >(NotificationDismissalsNotifier.new, retry: (_, _) => null);

/// The notifications to show: [allNotificationsProvider] without the ones the
/// user dismissed. Returns an empty list when nothing is noteworthy.
final notificationsProvider = FutureProvider.autoDispose<List<AppNotification>>(
  (ref) async {
    final all = await ref.watch(allNotificationsProvider.future);
    Set<String> dismissed;
    try {
      dismissed = await ref.watch(notificationDismissalsProvider.future);
    } catch (_) {
      // Unreadable dismissals shouldn't hide the notifications themselves.
      dismissed = const {};
    }
    return withoutDismissed(all, dismissed);
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
