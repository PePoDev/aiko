import '../../../brick/offline_model_mappers.dart';
import '../../../brick/repository.dart';
import '../../../brick/models/category.model.dart';
import '../../../core/offline/offline_store.dart';
import '../../../core/offline/offline_user_context.dart';
import '../domain/category.dart';
import '../domain/category_defaults.dart';

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
    if (CategoryDefaults.allIds.contains(id)) {
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
