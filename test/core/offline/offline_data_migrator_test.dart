import 'package:aiko/brick/models/category.model.dart';
import 'package:aiko/brick/models/category_group.model.dart';
import 'package:aiko/brick/models/transaction.model.dart';
import 'package:aiko/brick/repository.dart';
import 'package:aiko/core/offline/offline_data_migrator.dart';
import 'package:aiko/core/offline/offline_store.dart';
import 'package:aiko/features/categories/domain/category_defaults.dart';
import 'package:brick_sqlite/brick_sqlite.dart' show SqliteModel;
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'claims defaults in dependency order and removes old local ids',
    () async {
      const localUserId = 'local:test-user';
      const realUserId = '11111111-1111-4111-8111-111111111111';
      final store = _ClaimStore([
        OfflineCategoryGroup(
          id: CategoryGroupDefaults.foodAndDrinkId,
          userId: localUserId,
          name: 'Food & Drink',
          budgetAmount: '5000',
          budgetCurrency: 'THB',
        ),
        OfflineCategory(
          id: CategoryDefaults.coffeeId,
          userId: localUserId,
          name: 'Coffee',
          type: 'expense',
          categoryGroup: 'wants',
          groupId: CategoryGroupDefaults.foodAndDrinkId,
          budgetAmount: '3000',
          budgetCurrency: 'THB',
        ),
        OfflineTransaction(
          id: 'transaction',
          userId: localUserId,
          accountId: 'account',
          type: 'expense',
          amount: '10',
          currency: 'THB',
          date: DateTime(2026, 7, 26),
          categoryId: CategoryDefaults.coffeeId,
        ),
      ]);
      final migrator = OfflineDataMigrator(store: store);

      final migrated = await migrator.claimAnonymousData(realUserId);

      expect(migrated, 3);
      expect(store.upsertOrder, [
        OfflineCategoryGroup,
        OfflineCategory,
        OfflineTransaction,
      ]);
      expect(store.localOnlyDeletes, hasLength(2));

      final group = store.rows.whereType<OfflineCategoryGroup>().single;
      expect(group.templateId, CategoryGroupDefaults.foodAndDrinkId);
      expect(group.createdAt, isNotNull);
      expect(
        group.id,
        CategoryGroupDefaults.cloneIdForUser(
          userId: realUserId,
          templateId: CategoryGroupDefaults.foodAndDrinkId,
        ),
      );

      final category = store.rows.whereType<OfflineCategory>().single;
      expect(category.templateId, CategoryDefaults.coffeeId);
      expect(category.createdAt, isNotNull);
      expect(
        category.groupId,
        CategoryGroupDefaults.cloneIdForUser(
          userId: realUserId,
          templateId: CategoryGroupDefaults.foodAndDrinkId,
        ),
      );

      final transaction = store.rows.whereType<OfflineTransaction>().single;
      expect(
        transaction.categoryId,
        CategoryDefaults.cloneIdForUser(
          userId: realUserId,
          templateId: CategoryDefaults.coffeeId,
        ),
      );
      expect(await migrator.claimAnonymousData(realUserId), 0);
    },
  );
}

class _ClaimStore implements OfflineStore {
  _ClaimStore(this.rows);

  final List<SqliteModel> rows;
  final List<Type> upsertOrder = [];
  final List<SqliteModel> localOnlyDeletes = [];

  @override
  bool get canSyncRemote => false;

  @override
  Future<List<TModel>> get<TModel extends SqliteModel>({
    Query? query,
    OfflineReadPolicy? policy,
  }) async => rows.whereType<TModel>().toList();

  @override
  Future<TModel> upsert<TModel extends SqliteModel>(
    TModel model, {
    Query? query,
  }) async {
    upsertOrder.add(TModel);
    final id = _idOf(model);
    rows.removeWhere((row) => row.runtimeType == TModel && _idOf(row) == id);
    rows.add(model);
    return model;
  }

  @override
  Future<bool> delete<TModel extends SqliteModel>(
    TModel model, {
    Query? query,
    bool localOnly = false,
  }) async {
    if (localOnly) localOnlyDeletes.add(model);
    return rows.remove(model);
  }

  String _idOf(SqliteModel model) {
    if (model is OfflineCategoryGroup) return model.id;
    if (model is OfflineCategory) return model.id;
    if (model is OfflineTransaction) return model.id;
    throw StateError('Unexpected ${model.runtimeType}');
  }
}
