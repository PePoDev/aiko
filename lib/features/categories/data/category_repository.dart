import '../../../brick/offline_model_mappers.dart';
import '../../../brick/repository.dart';
import '../../../brick/models/category.model.dart';
import '../../../core/offline/offline_store.dart';
import '../../../core/offline/offline_user_context.dart';
import '../domain/category.dart';

class CategoryRepository {
  const CategoryRepository();

  Future<List<Category>> list() async {
    final userId = await OfflineUserContext().resolveUserId();
    final categories = await OfflineStore().get<OfflineCategory>(
      query: Query(
        where: [Where.exact('userId', userId)],
        orderBy: const [OrderBy.asc('name')],
      ),
    );

    return categories
        .map((category) => category.toDomain())
        .toList(growable: false);
  }

  Future<Category> save(Category category) async {
    final currentList = await list();
    final duplicate = currentList.any(
      (item) =>
          item.id != category.id &&
          item.parentId == category.parentId &&
          item.name.toLowerCase() == category.name.toLowerCase(),
    );
    if (duplicate) {
      throw ArgumentError('Category name already exists.');
    }

    final userId = await OfflineUserContext().resolveUserId();
    final saved = await OfflineStore().upsert(
      category.toOffline(userId: userId),
    );
    return saved.toDomain();
  }
}
