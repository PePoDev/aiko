import 'package:aiko/brick/models/category.model.dart';
import 'package:aiko/brick/offline_model_mappers.dart';
import 'package:aiko/brick/repository.dart';
import 'package:aiko/core/offline/offline_store.dart';
import 'package:aiko/core/offline/offline_user_context.dart';
import 'package:aiko/features/categories/data/category_repository.dart';
import 'package:aiko/features/categories/domain/category.dart';
import 'package:aiko/features/categories/domain/category_defaults.dart';
import 'package:brick_sqlite/brick_sqlite.dart' show SqliteModel;
import 'package:flutter_test/flutter_test.dart';

void main() {
  const userId = '11111111-1111-4111-8111-111111111111';

  test('custom category can share a name with a built-in clone', () async {
    final store = _CategoryStore([
      CategoryDefaults.cloneForUser(
        userId: userId,
        template: CategoryDefaults.all.singleWhere(
          (category) => category.id == CategoryDefaults.coffeeId,
        ),
      ).toOffline(userId: userId),
    ]);
    final repository = CategoryRepository(
      store: store,
      userContext: const _FixedUserContext(userId),
    );

    final saved = await repository.save(
      const Category(
        id: 'dddddddd-0000-4000-8000-000000000001',
        userId: userId,
        name: 'Coffee',
        type: CategoryType.expense,
        group: CategoryBudgetGroup.custom,
      ),
    );

    expect(saved.id, 'dddddddd-0000-4000-8000-000000000001');
    expect(store.categories, hasLength(2));
  });
}

class _FixedUserContext implements OfflineUserContext {
  const _FixedUserContext(this.userId);

  final String userId;

  @override
  Future<String> resolveUserId() async => userId;
}

class _CategoryStore implements OfflineStore {
  _CategoryStore([List<OfflineCategory>? categories])
    : categories = categories ?? [];

  final List<OfflineCategory> categories;

  @override
  bool get canSyncRemote => false;

  @override
  Future<List<TModel>> get<TModel extends SqliteModel>({
    Query? query,
    OfflineReadPolicy? policy,
  }) async => categories.whereType<TModel>().toList();

  @override
  Future<TModel> upsert<TModel extends SqliteModel>(
    TModel model, {
    Query? query,
  }) async {
    final category = model as OfflineCategory;
    categories.removeWhere((item) => item.id == category.id);
    categories.add(category);
    return model;
  }

  @override
  Future<void> upsertBatch<TModel extends SqliteModel>(
    List<TModel> models,
  ) async {
    for (final model in models) {
      await upsert<TModel>(model);
    }
  }

  @override
  Future<bool> delete<TModel extends SqliteModel>(
    TModel model, {
    Query? query,
    bool localOnly = false,
  }) async => false;
}
