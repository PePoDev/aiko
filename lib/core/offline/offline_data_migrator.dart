import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';

import '../../features/categories/domain/category_defaults.dart';
import '../../features/transactions/data/transaction_attachment_repository.dart';
import '../firebase/firebase_backend.dart';
import 'firestore_sync_state.dart' show DocumentRead;
import 'offline_store.dart';
import 'offline_user_context.dart';
import 'records/records.dart';

/// Reassigns rows that were created while signed out (under an anonymous
/// `local:<uuid>` user id) to the real Firebase user id after sign-in.
///
/// Without this, data captured before signing in is orphaned: every repository
/// query filters by the currently resolved user id, so once that id flips from
/// `local:<uuid>` to the real UUID the earlier rows silently disappear from the
/// UI even though they are still in the local database.
///
/// Each reclaimed row is re-upserted under the real user id. Signed in, rows go
/// to Firestore in batches of [OfflineStore.maxBatchWrites] (handed to the SDK,
/// which uploads them when online) and the local copies are deleted; a batch
/// the server rejects is put back locally so the next claim retries it.
/// Signed out, rows are updated in the local store in place.
///
/// The account may already have what the guest made:
/// - A default category or group the guest gave a budget is that default's
///   clone in the account. The guest's budget goes on it only while the
///   account's clone still has the default budget, and only the budget
///   fields are written (the rules keep the rest of a clone fixed).
/// - A custom category or group named like one the account has becomes that
///   one (the guest's transactions and subcategories move to it), as the
///   repositories don't allow two of the same name. Its budget goes on that
///   one, budget fields only, when that one has none.
///
/// While the account's record can't be read, such a budget waits on this
/// device for a later claim into the same account ([waitingOwner]); no
/// other account's claim takes it.
///
/// Guest attachments are handed over too ([claimFiles]) and their uploads
/// queued.
class OfflineDataMigrator {
  /// [firestore] defaults to the app's; [serverTimeout] bounds asking the
  /// server for an account's default clone that isn't cached.
  OfflineDataMigrator({
    OfflineStore? store,
    Future<int> Function(String realUserId)? claimFiles,
    FirebaseFirestore? firestore,
    this.serverTimeout = const Duration(seconds: 10),
  }) : _store = store ?? OfflineStore(),
       _firestore = firestore,
       _claimFiles =
           claimFiles ??
           TransactionAttachmentRepository().claimGuestAttachments;

  final OfflineStore _store;
  final FirebaseFirestore? _firestore;
  final Future<int> Function(String realUserId) _claimFiles;
  final Duration serverTimeout;

  /// Guest custom categories and groups that became the account's own of the
  /// same name, by guest id (filled by [claimAnonymousData]).
  final _mergedIds = <String, String>{};

  /// The owner of guest categories and groups kept on this device until
  /// their budget can be claimed into [userId]'s account. Not `local:`, so
  /// guests and other accounts' claims leave them alone.
  static String waitingOwner(String userId) => 'claim:$userId';

  /// The id the category a guest record pointed at ([categoryId]) has in the
  /// account of [userId] after [claimAnonymousData].
  String? claimedCategoryId(String userId, String? categoryId) =>
      _mergedIds[categoryId] ??
      CategoryDefaults.categoryIdForUser(
        userId: userId,
        categoryId: categoryId,
      );

  /// Claims every locally-created row for [realUserId]. Returns the number of
  /// rows reassigned. Safe to call repeatedly: it is a no-op once nothing is
  /// orphaned, and it never throws (failures are logged in debug only).
  Future<int> claimAnonymousData(String realUserId) async {
    if (realUserId.isEmpty ||
        realUserId.startsWith(OfflineUserContext.localUserIdPrefix)) {
      return 0;
    }
    _mergedIds.clear();
    final merged = <OfflineRecord>[];
    final waiting = <OfflineRecord>[];

    // Order matters: parents are queued before rows that reference them.
    var migrated = 0;
    migrated += await _claim<OfflineAccount>(
      (row) => row.toDomain().toOffline(userId: realUserId),
    );
    migrated += await _claimGroups(realUserId, merged, waiting);
    migrated += await _claimCategories(realUserId, merged, waiting);
    migrated += await _claim<OfflineTransaction>((row) {
      final transaction = row.toDomain();
      return transaction
          .copyWith(
            categoryId: claimedCategoryId(realUserId, transaction.categoryId),
          )
          .toOffline(userId: realUserId);
    });

    migrated += await _claim<OfflineInvestmentHolding>(
      (row) => row.toDomain().toOffline(userId: realUserId),
    );
    // Gone once nothing points at them any more; until then a repeated claim
    // (after the app was closed midway) merges them again.
    await _dropLocal(merged);
    await _keepWaiting(waiting, realUserId);
    // Attachment metadata and bytes live in the file cache, not the record
    // store; this never throws.
    migrated += await _claimFiles(realUserId);

    if (kDebugMode) {
      debugPrint(
        '[aiko-sync] claimAnonymousData reassigned $migrated rows to '
        '$realUserId',
      );
    }
    return migrated;
  }

  Future<int> _claim<TModel extends OfflineRecord>(
    TModel Function(TModel row) reassign,
  ) async {
    try {
      return await _claimRows(await _orphans<TModel>(), reassign);
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[aiko-sync] claim $TModel failed: $error');
      }
      return 0;
    }
  }

  /// The guest rows of [TModel], and those waiting for [waitingFor]'s
  /// account ([waitingOwner]).
  Future<List<TModel>> _orphans<TModel extends OfflineRecord>({
    String? waitingFor,
  }) async {
    final waiting = waitingFor == null ? null : waitingOwner(waitingFor);
    final rows = await _store.get<TModel>(localOnly: true);
    return rows
        .where((row) {
          final owner = row.ownerId ?? '';
          return owner.startsWith(OfflineUserContext.localUserIdPrefix) ||
              owner == waiting;
        })
        .toList(growable: false);
  }

  Future<int> _claimRows<TModel extends OfflineRecord>(
    List<TModel> orphans,
    TModel Function(TModel row) reassign,
  ) async {
    // One batch (one server acknowledgement) per chunk, not one per row.
    for (
      var start = 0;
      start < orphans.length;
      start += OfflineStore.maxBatchWrites
    ) {
      final chunk = orphans.sublist(
        start,
        min(start + OfflineStore.maxBatchWrites, orphans.length),
      );
      final claimed = chunk.map(reassign).toList(growable: false);
      final staleRemoved = Completer<void>();
      await _store.upsertBatch<TModel>(
        claimed,
        // Put the guest rows back once their local copies are gone.
        onRejected: (_) =>
            unawaited(staleRemoved.future.whenComplete(() => _restore(chunk))),
      );
      try {
        await _removeStale(chunk, [
          for (final record in claimed) RecordCodecs.of<TModel>().idOf(record),
        ]);
      } finally {
        staleRemoved.complete();
      }
    }
    return orphans.length;
  }

  /// Deletes the local guest rows of [chunk] that were claimed as [claimedIds]
  /// (in order): all of them signed in, where they now live in Firestore;
  /// signed out, those stored again under another id.
  Future<void> _removeStale<TModel extends OfflineRecord>(
    List<TModel> chunk,
    List<String> claimedIds,
  ) async {
    final codec = RecordCodecs.of<TModel>();
    final stale = RecordBatch();
    for (var i = 0; i < chunk.length; i++) {
      if (_store.canSyncRemote || claimedIds[i] != codec.idOf(chunk[i])) {
        stale.delete(chunk[i]);
      }
    }
    await _store.commit(stale, localOnly: true);
  }

  Future<void> _dropLocal(List<OfflineRecord> rows) async {
    if (rows.isEmpty) return;
    final batch = RecordBatch();
    for (final row in rows) {
      batch.delete(row);
    }
    try {
      await _store.commit(batch, localOnly: true);
    } catch (error) {
      if (kDebugMode) debugPrint('[aiko-sync] dropping merged rows: $error');
    }
  }

  /// Keeps the guest [rows] whose budget couldn't be claimed yet for a later
  /// claim into [userId]'s account only: they move to [waitingOwner].
  Future<void> _keepWaiting(List<OfflineRecord> rows, String userId) async {
    final owner = waitingOwner(userId);
    final batch = RecordBatch();
    for (final row in rows) {
      if (row.ownerId == owner) continue;
      final codec = RecordCodecs.forRecord(row);
      batch
        ..delete(row)
        ..add(
          RecordWrite.put(
            collection: codec.collection,
            id: codec.idOf(row),
            ownerId: owner,
            row: {...codec.toRow(row), 'user_id': owner},
          ),
        );
    }
    if (batch.isEmpty) return;
    try {
      await _store.commit(batch, localOnly: true);
    } catch (error) {
      if (kDebugMode) debugPrint('[aiko-sync] keeping waiting rows: $error');
    }
  }

  Future<int> _claimGroups(
    String userId,
    List<OfflineRecord> merged,
    List<OfflineRecord> waiting,
  ) async {
    try {
      final orphans = await _orphans<OfflineCategoryGroup>(waitingFor: userId);
      if (orphans.isEmpty) return 0;
      final overlays = [
        for (final row in orphans)
          if (row.toDomain().isDefault) row,
      ];
      final custom = [
        for (final row in orphans)
          if (!row.toDomain().isDefault) row,
      ];
      final kept = <OfflineCategoryGroup>[];
      final budgeted = <(OfflineCategoryGroup, String)>[];
      if (custom.isNotEmpty) {
        final taken = <String, String>{
          for (final group in await _accountRecords<OfflineCategoryGroup>(
            userId,
          ))
            group.name.toLowerCase(): group.id,
        };
        // Default groups take their names even before they are seeded.
        for (final template in CategoryGroupDefaults.all) {
          taken.putIfAbsent(
            template.name.toLowerCase(),
            () => CategoryGroupDefaults.cloneIdForUser(
              userId: userId,
              templateId: template.id,
            ),
          );
        }
        for (final row in custom) {
          final name = row.name.toLowerCase();
          final match = taken[name];
          if (match == null) {
            kept.add(row);
            taken[name] = row.id;
          } else {
            _mergedIds[row.id] = match;
            if (_groupHasBudget(row)) {
              budgeted.add((row, match));
            } else {
              merged.add(row);
            }
          }
        }
      }
      OfflineCategoryGroup clone(OfflineCategoryGroup row) =>
          CategoryGroupDefaults.normalizeForUser(
            row.toDomain(),
            userId: userId,
          ).toOffline(userId: userId);
      final claimed =
          custom.length -
          kept.length +
          await _claimRows<OfflineCategoryGroup>(kept, clone) +
          await _claimOverlays<OfflineCategoryGroup>(
            userId,
            overlays,
            clone: clone,
            defaultBudget: (row) => CategoryGroupDefaults.cloneForUser(
              userId: userId,
              template: CategoryGroupDefaults
                  .byId[row.toDomain().effectiveTemplateId]!,
            ).toOffline(userId: userId),
            sameBudget: _sameGroupBudget,
            budgetFields: _groupBudgetFields,
            waiting: waiting,
          );
      await _mergeBudgets<OfflineCategoryGroup>(
        userId,
        budgeted,
        hasBudget: _groupHasBudget,
        budgetFields: _groupBudgetFields,
        merged: merged,
        waiting: waiting,
      );
      return claimed;
    } catch (error) {
      if (kDebugMode) debugPrint('[aiko-sync] claim groups failed: $error');
      return 0;
    }
  }

  Future<int> _claimCategories(
    String userId,
    List<OfflineRecord> merged,
    List<OfflineRecord> waiting,
  ) async {
    try {
      final orphans = await _orphans<OfflineCategory>(waitingFor: userId);
      if (orphans.isEmpty) return 0;
      final overlays = [
        for (final row in orphans)
          if (row.toDomain().isDefault) row,
      ];
      // Parents first, so their subcategories match under the parent's
      // account id.
      final custom = [
        for (final row in orphans)
          if (!row.toDomain().isDefault && row.parentId == null) row,
        for (final row in orphans)
          if (!row.toDomain().isDefault && row.parentId != null) row,
      ];
      final kept = <OfflineCategory>[];
      final budgeted = <(OfflineCategory, String)>[];
      if (custom.isNotEmpty) {
        String key(String name, String type, String? parentId) =>
            '${name.toLowerCase()}\u0000$type\u0000${parentId ?? ''}';
        final taken = <String, String>{
          for (final category in await _accountRecords<OfflineCategory>(userId))
            if (category.isActive && !category.toDomain().isDefault)
              key(category.name, category.type, category.parentId): category.id,
        };
        for (final row in custom) {
          final rowKey = key(
            row.name,
            row.type,
            claimedCategoryId(userId, row.parentId),
          );
          final match = row.isActive ? taken[rowKey] : null;
          if (match == null) {
            kept.add(row);
            if (row.isActive) taken[rowKey] = row.id;
          } else {
            _mergedIds[row.id] = match;
            if (_categoryHasBudget(row)) {
              budgeted.add((row, match));
            } else {
              merged.add(row);
            }
          }
        }
      }
      OfflineCategory clone(OfflineCategory row) {
        final category = row.toDomain();
        return CategoryDefaults.normalizeForUser(
          category.copyWith(
            groupId: _mergedIds[category.groupId] ?? category.groupId,
            parentId: claimedCategoryId(userId, category.parentId),
          ),
          userId: userId,
        ).toOffline(userId: userId);
      }

      final claimed =
          custom.length -
          kept.length +
          await _claimRows<OfflineCategory>(kept, clone) +
          await _claimOverlays<OfflineCategory>(
            userId,
            overlays,
            clone: clone,
            defaultBudget: (row) => CategoryDefaults.cloneForUser(
              userId: userId,
              template:
                  CategoryDefaults.byId[row.toDomain().effectiveTemplateId]!,
            ).toOffline(userId: userId),
            sameBudget: _sameCategoryBudget,
            budgetFields: _categoryBudgetFields,
            waiting: waiting,
          );
      await _mergeBudgets<OfflineCategory>(
        userId,
        budgeted,
        hasBudget: _categoryHasBudget,
        budgetFields: _categoryBudgetFields,
        merged: merged,
        waiting: waiting,
      );
      return claimed;
    } catch (error) {
      if (kDebugMode) debugPrint('[aiko-sync] claim categories failed: $error');
      return 0;
    }
  }

  /// Claims the guest's budgets on defaults ([overlays]) into the account's
  /// clones of those defaults ([clone] gives the clone with the guest's
  /// budget, [defaultBudget] one with the default budget). Separate from the
  /// guest's own categories, so a write the server refuses never holds those
  /// up; a refused budget is not retried (the account keeps its own). An
  /// overlay whose clone can't be read goes to [waiting].
  Future<int> _claimOverlays<TModel extends OfflineRecord>(
    String userId,
    List<TModel> overlays, {
    required TModel Function(TModel row) clone,
    required TModel Function(TModel row) defaultBudget,
    required bool Function(TModel a, TModel b) sameBudget,
    required List<String> budgetFields,
    required List<OfflineRecord> waiting,
  }) async {
    if (overlays.isEmpty) return 0;
    final codec = RecordCodecs.of<TModel>();
    final claimed = [for (final row in overlays) clone(row)];
    final accounts = await Future.wait([
      for (final record in claimed)
        _readAccountRow<TModel>(userId, codec.idOf(record)),
    ]);
    final done = <TModel>[];
    final doneIds = <String>[];
    final writes = <RecordWrite>[];
    for (var i = 0; i < overlays.length; i++) {
      final read = accounts[i];
      // What the account has is unknown (offline): a later claim decides.
      if (!read.known) {
        waiting.add(overlays[i]);
        continue;
      }
      final guest = claimed[i];
      final id = codec.idOf(guest);
      done.add(overlays[i]);
      doneIds.add(id);
      final guestRow = codec.toRow(guest);
      final accountRow = read.data;
      if (accountRow == null) {
        writes.add(
          RecordWrite.put(
            collection: codec.collection,
            id: id,
            ownerId: userId,
            row: guestRow,
          ),
        );
        continue;
      }
      final TModel account;
      try {
        account = codec.fromRow(accountRow);
      } catch (_) {
        continue; // Unreadable here: leave the account's as it is.
      }
      if (sameBudget(account, guest)) continue;
      // A budget the account set on this default stays.
      if (!sameBudget(account, defaultBudget(overlays[i]))) continue;
      writes.add(
        _budgetWrite(
          codec.collection,
          userId,
          id,
          accountRow,
          guestRow,
          budgetFields,
        ),
      );
    }
    await _commitWrites(writes);
    await _removeStale(done, doneIds);
    return done.length;
  }

  /// Carries the budget of each guest row of [merges] onto the account's
  /// record of the same name it became (by id) when that one has none,
  /// writing only the budget fields. The guest rows go once decided
  /// ([merged]); one whose account record can't be read goes to [waiting].
  Future<void> _mergeBudgets<TModel extends OfflineRecord>(
    String userId,
    List<(TModel, String)> merges, {
    required bool Function(TModel row) hasBudget,
    required List<String> budgetFields,
    required List<OfflineRecord> merged,
    required List<OfflineRecord> waiting,
  }) async {
    if (merges.isEmpty) return;
    final codec = RecordCodecs.of<TModel>();
    final accounts = await Future.wait([
      for (final (_, id) in merges) _readAccountRow<TModel>(userId, id),
    ]);
    final decided = <TModel>[];
    final writes = <RecordWrite>[];
    for (var i = 0; i < merges.length; i++) {
      final (guest, id) = merges[i];
      final read = accounts[i];
      if (!read.known) {
        waiting.add(guest);
        continue;
      }
      decided.add(guest);
      final accountRow = read.data;
      if (accountRow == null) continue;
      try {
        // A budget the account set stays.
        if (hasBudget(codec.fromRow(accountRow))) continue;
      } catch (_) {
        continue; // Unreadable here: leave the account's as it is.
      }
      writes.add(
        _budgetWrite(
          codec.collection,
          userId,
          id,
          accountRow,
          codec.toRow(guest),
          budgetFields,
        ),
      );
    }
    await _commitWrites(writes);
    merged.addAll(decided);
  }

  /// The account's [accountRow] (record [id]) with the [budgetFields] of
  /// [guestRow]: nothing else changes (the rules keep the rest of a default
  /// clone fixed).
  static RecordWrite _budgetWrite(
    String collection,
    String userId,
    String id,
    Map<String, dynamic> accountRow,
    Map<String, dynamic> guestRow,
    List<String> budgetFields,
  ) => RecordWrite.put(
    collection: collection,
    id: id,
    ownerId: userId,
    row: {
      ...accountRow,
      'id': id,
      'user_id': userId,
      for (final field in budgetFields) field: guestRow[field],
      'updated_at': guestRow['updated_at'],
    },
  );

  /// Commits [writes] to the account in batches of at most
  /// [OfflineStore.maxBatchWrites].
  Future<void> _commitWrites(List<RecordWrite> writes) async {
    for (
      var start = 0;
      start < writes.length;
      start += OfflineStore.maxBatchWrites
    ) {
      final batch = RecordBatch();
      for (final write in writes.sublist(
        start,
        min(start + OfflineStore.maxBatchWrites, writes.length),
      )) {
        batch.add(write);
      }
      await _store.commit(batch);
    }
  }

  /// The account's [TModel] records (the cache, or briefly the server, signed
  /// in); empty when they can't be read.
  Future<List<TModel>> _accountRecords<TModel extends OfflineRecord>(
    String userId,
  ) async {
    try {
      return await _store.get<TModel>(query: RecordQuery(ownerId: userId));
    } catch (_) {
      return const [];
    }
  }

  /// The account's [TModel] row [id]: from the local store signed out;
  /// signed in, from the cache, else the server, or unknown when it can't be
  /// reached within [serverTimeout].
  Future<DocumentRead> _readAccountRow<TModel extends OfflineRecord>(
    String userId,
    String id,
  ) async {
    final codec = RecordCodecs.of<TModel>();
    if (!_store.canSyncRemote) {
      final rows = await _store.get<TModel>(
        query: RecordQuery(ownerId: userId, id: id, limit: 1),
        localOnly: true,
      );
      return rows.isEmpty
          ? const DocumentRead.missing()
          : DocumentRead.found(codec.toRow(rows.first));
    }
    final doc = (_firestore ?? FirebaseBackend.firestore)
        .collection('users')
        .doc(userId)
        .collection(codec.collection)
        .doc(id);
    try {
      final cached = await doc.get(const GetOptions(source: Source.cache));
      final data = cached.data();
      if (data != null) return DocumentRead.found(data);
    } catch (_) {
      // Not in the cache.
    }
    try {
      final remote = await doc
          .get(const GetOptions(source: Source.server))
          .timeout(serverTimeout);
      final data = remote.data();
      return data == null
          ? const DocumentRead.missing()
          : DocumentRead.found(data);
    } catch (_) {
      return const DocumentRead.unknown();
    }
  }

  /// The server rejected a claimed chunk: put the guest rows back so the next
  /// claim tries again instead of losing them.
  Future<void> _restore(List<OfflineRecord> rows) async {
    final batch = RecordBatch();
    for (final row in rows) {
      batch.upsert(row);
    }
    try {
      await _store.commit(batch, localOnly: true);
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[aiko-sync] restoring rejected claim failed: $error');
      }
    }
  }
}

/// The fields of a default clone's row that hold its budget: the only ones
/// (with `updated_at` and `version`) that may change on a clone.
const _categoryBudgetFields = [
  'budget_amount',
  'budget_currency',
  'budget_period',
  'budget_rollover',
  'budget_enabled',
  'alert_thresholds',
];
const _groupBudgetFields = ['budget_amount', 'budget_currency'];

bool _sameAmount(String? a, String? b) {
  if (a == null || b == null) return a == b;
  final x = Decimal.tryParse(a);
  return x != null && x == Decimal.tryParse(b);
}

bool _sameCategoryBudget(OfflineCategory a, OfflineCategory b) =>
    _sameAmount(a.budgetAmount, b.budgetAmount) &&
    (a.budgetAmount == null || a.budgetCurrency == b.budgetCurrency) &&
    a.budgetPeriod == b.budgetPeriod &&
    a.budgetRollover == b.budgetRollover &&
    a.budgetEnabled == b.budgetEnabled &&
    listEquals(a.alertThresholds, b.alertThresholds);

bool _sameGroupBudget(OfflineCategoryGroup a, OfflineCategoryGroup b) =>
    _sameAmount(a.budgetAmount, b.budgetAmount) &&
    (a.budgetAmount == null || a.budgetCurrency == b.budgetCurrency);

/// A null amount or currency is no budget.
bool _categoryHasBudget(OfflineCategory row) =>
    row.budgetAmount != null && row.budgetCurrency != null;

bool _groupHasBudget(OfflineCategoryGroup row) =>
    row.budgetAmount != null && row.budgetCurrency != null;
