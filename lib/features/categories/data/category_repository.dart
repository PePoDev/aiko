import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;

import '../../../brick/offline_model_mappers.dart';
import '../../../brick/repository.dart';
import '../../../brick/models/category.model.dart';
import '../../../core/offline/offline_store.dart';
import '../../../core/offline/offline_user_context.dart';
import '../application/category_service.dart';
import '../domain/category.dart';

class CategoryRepository {
  const CategoryRepository();

  Future<List<Category>> list() async {
    final userId = await OfflineUserContext().resolveUserId();
    final categories = await OfflineStore().get<OfflineCategory>(
      query: Query(
        where: [Where.exact('userId', userId)],
      ),
    );

    return categories
        .map((category) => category.toDomain())
        .toList(growable: false);
  }

  /// Persists any built-in default categories that are not yet stored so that
  /// transactions referencing a `default-*` category id satisfy the Supabase
  /// foreign key on `transactions.category_id`. Without this, the defaults are
  /// only generated in memory and never exist remotely, so every categorized
  /// transaction is rejected by Supabase and stuck retrying in the offline
  /// queue. Idempotent: only missing defaults are inserted.
  Future<int> ensureDefaultsPersisted() async {
    final userId = await OfflineUserContext().resolveUserId();
    final existing = await OfflineStore().get<OfflineCategory>(
      query: Query(where: [Where.exact('userId', userId)]),
      policy: OfflineFirstGetPolicy.localOnly,
    );
    final existingIds = existing.map((category) => category.id).toSet();

    final defaults = const CategoryService().defaultCategoriesFor(userId);
    var seeded = 0;
    for (final category in defaults) {
      if (existingIds.contains(category.id)) {
        continue;
      }
      await OfflineStore().upsert(category.toOffline(userId: userId));
      seeded++;
    }

    if (kDebugMode && seeded > 0) {
      debugPrint(
        '[aiko-sync] seeded $seeded default categories for $userId',
      );
    }
    return seeded;
  }

  Future<Category> save(Category category) async {
    final currentList = await list();
    if (category.isDefault &&
        currentList.any((item) => item.id == category.id)) {
      throw StateError('Default categories cannot be edited.');
    }

    final duplicate = currentList.any(
      (item) =>
          item.isActive &&
          category.isActive &&
          item.id != category.id &&
          item.parentId == category.parentId &&
          item.type == category.type &&
          item.name.toLowerCase() == category.name.toLowerCase(),
    );
    if (duplicate) {
      throw ArgumentError('Category name already exists.');
    }

    final userId = await OfflineUserContext().resolveUserId();
    final categoryToSave =
        category.createdAt == null && !category.isDefault
        ? category.copyWith(createdAt: DateTime.now())
        : category;
    final saved = await OfflineStore().upsert(
      categoryToSave.toOffline(userId: userId),
    );
    return saved.toDomain();
  }

  Future<void> delete(String id) async {
    if (id.startsWith('default-')) {
      throw StateError('Default categories cannot be deleted.');
    }

    final userId = await OfflineUserContext().resolveUserId();
    final categories = await OfflineStore().get<OfflineCategory>(
      query: Query(
        where: [Where.exact('id', id), Where.exact('userId', userId)],
        limit: 1,
      ),
    );
    if (categories.isEmpty) {
      return;
    }
    await OfflineStore().delete(categories.first);
  }
}
