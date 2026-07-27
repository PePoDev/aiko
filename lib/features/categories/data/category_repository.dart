import '../../../brick/offline_model_mappers.dart';
import '../../../brick/repository.dart';
import '../../../brick/models/category.model.dart';
import '../../../core/offline/offline_store.dart';
import '../../../core/offline/offline_user_context.dart';
import '../domain/category.dart';
import '../domain/category_defaults.dart';

class CategoryRepository {
  const CategoryRepository({
    OfflineStore? store,
    OfflineUserContext? userContext,
  }) : _storeOverride = store,
       _userContextOverride = userContext;

  final OfflineStore? _storeOverride;
  final OfflineUserContext? _userContextOverride;

  OfflineStore get _store => _storeOverride ?? OfflineStore();
  OfflineUserContext get _userContext =>
      _userContextOverride ?? OfflineUserContext();

  Future<String> currentUserId() => _userContext.resolveUserId();

  Future<List<Category>> list({String? userId}) async {
    final ownerId = userId ?? await currentUserId();
    final categories = await _store.get<OfflineCategory>(
      query: Query(where: [Where.exact('userId', ownerId)]),
    );

    return categories
        .map((category) => category.toDomain())
        .toList(growable: false);
  }

  Future<Category> save(Category category) async {
    final currentList = await list();
    if (!category.isDefault) {
      final duplicate = currentList.any(
        (item) =>
            item.isActive &&
            category.isActive &&
            !item.isDefault &&
            item.id != category.id &&
            item.parentId == category.parentId &&
            item.type == category.type &&
            item.name.toLowerCase() == category.name.toLowerCase(),
      );
      if (duplicate) {
        throw ArgumentError('Category name already exists.');
      }
    }

    final userId = await currentUserId();
    final categoryToSave = category.createdAt == null
        ? category.copyWith(createdAt: DateTime.now().toUtc())
        : category;
    final saved = await _store.upsert(categoryToSave.toOffline(userId: userId));
    return saved.toDomain();
  }

  Future<void> delete(String id) async {
    if (CategoryDefaults.allIds.contains(id)) {
      throw StateError('Default categories cannot be deleted.');
    }

    final userId = await _userContext.resolveUserId();
    final categories = await _store.get<OfflineCategory>(
      query: Query(
        where: [Where.exact('id', id), Where.exact('userId', userId)],
        limit: 1,
      ),
    );
    if (categories.isEmpty) {
      return;
    }
    if (categories.first.toDomain().isDefault) {
      throw StateError('Default categories cannot be deleted.');
    }
    await _store.delete(categories.first);
  }
}
