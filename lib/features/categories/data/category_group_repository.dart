import '../../../core/offline/offline_store.dart';
import '../../../core/offline/offline_user_context.dart';
import '../../../core/offline/records/records.dart';
import '../domain/category.dart';
import '../domain/category_defaults.dart';

class CategoryGroupRepository {
  const CategoryGroupRepository({
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

  Future<List<CategoryGroup>> list({String? userId}) async {
    final ownerId = userId ?? await currentUserId();
    final groups = await _store.get<OfflineCategoryGroup>(
      query: RecordQuery(ownerId: ownerId),
    );

    final domain = groups.map((group) => group.toDomain()).toList();
    domain.sort(compareGroups);
    return domain;
  }

  /// Saves [group]. A custom group can't take the name of another group,
  /// default groups included (a guest's list holds only the defaults they
  /// edited). Only a new name is checked: a group that already shares its
  /// name (made on two devices while offline, or brought in from a guest)
  /// can still be edited.
  Future<CategoryGroup> save(CategoryGroup group) async {
    // Built-in clones keep canonical identity and only their budget is edited.
    if (!group.isSystem) {
      final currentList = await list();
      final name = group.name.toLowerCase();
      final stored = currentList.where((item) => item.id == group.id);
      final renamed = stored.isEmpty || stored.first.name.toLowerCase() != name;
      final taken = {
        for (final item in currentList)
          if (item.id != group.id) item.name.toLowerCase(),
        for (final template in CategoryGroupDefaults.all)
          template.name.toLowerCase(),
      };
      if (renamed && taken.contains(name)) {
        throw ArgumentError('A group with this name already exists.');
      }
    }

    final userId = await currentUserId();
    // Default clones keep their stored createdAt (see CategoryRepository).
    final groupToSave = group.createdAt == null && !group.isDefault
        ? group.copyWith(createdAt: DateTime.now().toUtc())
        : group;
    final saved = await _store.upsert(groupToSave.toOffline(userId: userId));
    return saved.toDomain();
  }

  /// Deletes the current user's custom group [id]. With a [batch], the
  /// delete is staged there for the caller to commit instead.
  Future<void> delete(String id, {RecordBatch? batch}) async {
    final userId = await currentUserId();
    final groups = await _store.get<OfflineCategoryGroup>(
      query: RecordQuery(ownerId: userId, id: id, limit: 1),
    );
    if (groups.isEmpty) {
      return;
    }
    if (groups.first.toDomain().isDefault) {
      throw StateError('Default category groups cannot be deleted.');
    }
    if (batch != null) {
      batch.delete(groups.first);
    } else {
      await _store.delete(groups.first);
    }
  }

  /// The order groups are listed in.
  static int compareGroups(CategoryGroup a, CategoryGroup b) {
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
