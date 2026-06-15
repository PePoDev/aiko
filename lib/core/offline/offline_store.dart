import 'package:brick_offline_first_with_supabase/brick_offline_first_with_supabase.dart';
import 'package:flutter/foundation.dart';

import '../../brick/models/account.model.dart';
import '../../brick/models/category.model.dart';
import '../../brick/models/category_group.model.dart';
import '../../brick/models/investment_holding.model.dart';
import '../../brick/models/profile.model.dart';
import '../../brick/models/transaction.model.dart';
import '../../brick/repository.dart';
import '../supabase/supabase_client_provider.dart';

class OfflineStore {
  OfflineStore({AikoBrickRepository? repository})
    : _repository = repository ?? AikoBrickRepository();

  final AikoBrickRepository _repository;

  bool get _canSyncRemote =>
      _repository.remoteSyncEnabled &&
      AikoSupabase.tryClient()?.auth.currentUser != null;

  bool get canSyncRemote => _canSyncRemote;

  OfflineFirstGetPolicy get readPolicy => _canSyncRemote
      ? OfflineFirstGetPolicy.awaitRemoteWhenNoneExist
      : OfflineFirstGetPolicy.localOnly;

  Future<List<TModel>> get<TModel extends OfflineFirstWithSupabaseModel>({
    Query? query,
    OfflineFirstGetPolicy? policy,
  }) async {
    // Honor an explicit policy, and stay local-only when there is no signed-in
    // Supabase session to sync against.
    if (policy != null || !_canSyncRemote) {
      return _repository.get<TModel>(
        query: query,
        policy: policy ?? OfflineFirstGetPolicy.localOnly,
      );
    }

    // Signed in: when nothing is cached locally for this query (e.g. a fresh
    // install signing back into an existing account), await the Supabase fetch
    // so existing rows are returned on the first read instead of an empty list.
    // `alwaysHydrate` alone would return the empty local result immediately and
    // only hydrate in an unawaited background pass, which is why a reinstall
    // previously showed nothing but locally-seeded data.
    final hasLocalData = (await _repository.get<TModel>(
      query: query,
      policy: OfflineFirstGetPolicy.localOnly,
    )).isNotEmpty;

    // Once local data exists, return it immediately but keep refreshing from
    // Supabase in the background so later reads stay in sync across devices.
    return _repository.get<TModel>(
      query: query,
      policy: hasLocalData
          ? OfflineFirstGetPolicy.alwaysHydrate
          : OfflineFirstGetPolicy.awaitRemoteWhenNoneExist,
    );
  }

  Future<TModel> upsert<TModel extends OfflineFirstWithSupabaseModel>(
    TModel model, {
    Query? query,
  }) async {
    if (_canSyncRemote) {
      try {
        final saved = await _repository.upsert<TModel>(
          model,
          query: query,
          policy: OfflineFirstUpsertPolicy.optimisticLocal,
        );
        if (kDebugMode) {
          debugPrint('[aiko-sync] upsert $TModel pushed to Supabase');
        }
        return saved;
      } catch (error) {
        // Brick queues network failures internally; anything surfacing here is
        // a real rejection (RLS, foreign key, schema) worth seeing.
        if (kDebugMode) {
          debugPrint('[aiko-sync] upsert $TModel remote push FAILED: $error');
        }
        rethrow;
      }
    }

    model.primaryKey = await _repository.sqliteProvider.upsert<TModel>(
      model,
      query: query,
      repository: _repository,
    );
    if (kDebugMode) {
      debugPrint(
        '[aiko-sync] upsert $TModel saved LOCAL-ONLY '
        '(remoteSyncEnabled=${_repository.remoteSyncEnabled}, '
        'signedIn=${AikoSupabase.tryClient()?.auth.currentUser != null}) — '
        'will not reach Supabase until sign-in',
      );
    }
    return model;
  }

  /// Soft-deletes [model] by stamping `deletedAt` / bumping `updatedAt` /
  /// `version` and upserting the row back. The row remains in the offline
  /// store (so an offline delete can sync up to Supabase without losing the
  /// record) and the queued PATCH is the only remote-side effect; nothing is
  /// hard-deleted from SQLite (see AGENTS.md §"Sync Fields & Conflict").
  ///
  /// When [localOnly] is true the row is also hard-deleted from SQLite without
  /// queuing a remote update — used to purge rows that never existed in
  /// Supabase (e.g. legacy `default-*` slug categories) so the queue is not
  /// poisoned with a request the server will reject forever.
  Future<bool> delete<TModel extends OfflineFirstWithSupabaseModel>(
    TModel model, {
    Query? query,
    bool localOnly = false,
  }) async {
    if (localOnly) {
      final rowsDeleted = await _repository.sqliteProvider.delete<TModel>(
        model,
        query: query,
        repository: _repository,
      );
      return rowsDeleted > 0;
    }

    final softDeleted = softDelete(model);
    await upsert(softDeleted, query: query);
    return true;
  }

  /// Stamps the soft-delete fields on [model] and returns a fresh instance.
  /// Each syncable model carries `deletedAt` / `updatedAt` /
  /// `version`; the helper centralises the per-type constructor plumbing.
  TModel softDelete<TModel extends OfflineFirstWithSupabaseModel>(
    TModel model,
  ) {
    final now = DateTime.now().toUtc();
    int nextVersion(TModel m) {
      final v = (m as dynamic).version;
      return v is int ? v + 1 : 1;
    }

    if (model is OfflineAccount) {
      return OfflineAccount(
            id: model.id,
            userId: model.userId,
            name: model.name,
            type: model.type,
            currency: model.currency,
            currentBalance: model.currentBalance,
            institution: model.institution,
            includeInNetWorth: model.includeInNetWorth,
            isActive: model.isActive,
            detailsJson: model.detailsJson,
            goalTargetAmount: model.goalTargetAmount,
            goalTargetDate: model.goalTargetDate,
            goalPriority: model.goalPriority,
            updatedAt: now,
            deletedAt: now,
            version: nextVersion(model),
          )
          as TModel;
    }
    if (model is OfflineCategory) {
      return OfflineCategory(
            id: model.id,
            userId: model.userId,
            name: model.name,
            type: model.type,
            categoryGroup: model.categoryGroup,
            groupId: model.groupId,
            parentId: model.parentId,
            icon: model.icon,
            color: model.color,
            budgetEnabled: model.budgetEnabled,
            isActive: model.isActive,
            createdAt: model.createdAt,
            budgetAmount: model.budgetAmount,
            budgetCurrency: model.budgetCurrency,
            budgetPeriod: model.budgetPeriod,
            budgetRollover: model.budgetRollover,
            alertThresholds: model.alertThresholds,
            updatedAt: now,
            deletedAt: now,
            version: nextVersion(model),
          )
          as TModel;
    }
    if (model is OfflineCategoryGroup) {
      return OfflineCategoryGroup(
            id: model.id,
            userId: model.userId,
            name: model.name,
            icon: model.icon,
            color: model.color,
            sortOrder: model.sortOrder,
            createdAt: model.createdAt,
            updatedAt: now,
            deletedAt: now,
            version: nextVersion(model),
          )
          as TModel;
    }
    if (model is OfflineProfile) {
      return OfflineProfile(
            id: model.id,
            displayName: model.displayName,
            email: model.email,
            baseCurrency: model.baseCurrency,
            country: model.country,
            timezone: model.timezone,
            preferredTheme: model.preferredTheme,
            aikoCharacterVisibility: model.aikoCharacterVisibility,
            aikoPersonalitySetting: model.aikoPersonalitySetting,
            onboardingStatus: model.onboardingStatus,
            securityStatus: model.securityStatus,
            updatedAt: now,
            deletedAt: now,
            version: nextVersion(model),
          )
          as TModel;
    }
    if (model is OfflineTransaction) {
      return OfflineTransaction(
            id: model.id,
            userId: model.userId,
            accountId: model.accountId,
            type: model.type,
            amount: model.amount,
            currency: model.currency,
            date: model.date,
            categoryId: model.categoryId,
            merchant: model.merchant,
            note: model.note,
            tags: model.tags,
            status: model.status,
            isRecurring: model.isRecurring,
            recurringFrequency: model.recurringFrequency,
            recurringEndDate: model.recurringEndDate,
            recurringMaxOccurrences: model.recurringMaxOccurrences,
            recurringDayOfWeek: model.recurringDayOfWeek,
            recurringDayOfMonth: model.recurringDayOfMonth,
            recurringMonthOfYear: model.recurringMonthOfYear,
            updatedAt: now,
            deletedAt: now,
            version: nextVersion(model),
          )
          as TModel;
    }
    if (model is OfflineInvestmentHolding) {
      return OfflineInvestmentHolding(
            id: model.id,
            userId: model.userId,
            symbol: model.symbol,
            assetClass: model.assetClass,
            quantity: model.quantity,
            averageCost: model.averageCost,
            currentPrice: model.currentPrice,
            currency: model.currency,
            marketValue: model.marketValue,
            targetAllocationPercent: model.targetAllocationPercent,
            createdAt: model.createdAt,
            updatedAt: now,
            deletedAt: now,
            version: nextVersion(model),
          )
          as TModel;
    }
    throw ArgumentError(
      'softDelete is not wired for ${model.runtimeType}; '
      'add a case to OfflineStore.softDelete when introducing a new syncable '
      'Brick model.',
    );
  }
}
