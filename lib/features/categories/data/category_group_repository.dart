import '../../../brick/models/category_group.model.dart';
import '../../../brick/offline_model_mappers.dart';
import '../../../brick/repository.dart';
import '../../../core/offline/offline_store.dart';
import '../../../core/offline/offline_user_context.dart';
import '../domain/category.dart';

class CategoryGroupRepository {
  const CategoryGroupRepository();

  Future<String> currentUserId() => OfflineUserContext().resolveUserId();

  Future<List<CategoryGroup>> list({String? userId}) async {
    final ownerId = userId ?? await currentUserId();
    final groups = await OfflineStore().get<OfflineCategoryGroup>(
      query: Query(where: [Where.exact('userId', ownerId)]),
    );

    final domain = groups.map((group) => group.toDomain()).toList();
    domain.sort(_compareGroups);
    return domain;
  }

  Future<CategoryGroup> save(CategoryGroup group) async {
    // Built-in clones keep canonical identity and only their budget is edited.
    if (!group.isSystem) {
      final currentList = await list();
      final duplicate = currentList.any(
        (item) =>
            item.id != group.id &&
            item.name.toLowerCase() == group.name.toLowerCase(),
      );
      if (duplicate) {
        throw ArgumentError('A group with this name already exists.');
      }
    }

    final userId = await currentUserId();
    final groupToSave = group.createdAt == null
        ? group.copyWith(createdAt: DateTime.now().toUtc())
        : group;
    final saved = await OfflineStore().upsert(
      groupToSave.toOffline(userId: userId),
    );
    return saved.toDomain();
  }

  Future<void> delete(String id) async {
    final userId = await OfflineUserContext().resolveUserId();
    final groups = await OfflineStore().get<OfflineCategoryGroup>(
      query: Query(
        where: [Where.exact('id', id), Where.exact('userId', userId)],
        limit: 1,
      ),
    );
    if (groups.isEmpty) {
      return;
    }
    if (groups.first.toDomain().isDefault) {
      throw StateError('Default category groups cannot be deleted.');
    }
    await OfflineStore().delete(groups.first);
  }

  int _compareGroups(CategoryGroup a, CategoryGroup b) {
    final bySort = a.sortOrder.compareTo(b.sortOrder);
    if (bySort != 0) {
      return bySort;
    }
    final createdAtA = a.createdAt;
    final createdAtB = b.createdAt;
    if (createdAtA != null && createdAtB != null) {
      final byCreatedAt = createdAtA.compareTo(createdAtB);
      if (byCreatedAt != 0) {
        return byCreatedAt;
      }
    }
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  }
}
