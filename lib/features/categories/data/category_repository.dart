import '../../../core/offline/offline_store.dart';
import '../../../core/offline/offline_user_context.dart';
import '../../../core/offline/records/records.dart';
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
      query: RecordQuery(ownerId: ownerId),
    );

    return categories
        .map((category) => category.toDomain())
        .toList(growable: false);
  }

  /// Saves [category] for the current user. With a [batch], the write is
  /// staged there for the caller to commit instead.
  ///
  /// A custom category can't take the name of another active one of the same
  /// type and parent. Only a new name (or type, parent, or a restore) is
  /// checked: a category that already shares its name (made on two devices
  /// while offline, or brought in from a guest) can still be edited.
  Future<Category> save(Category category, {RecordBatch? batch}) async {
    final currentList = await list();
    Category? stored;
    for (final item in currentList) {
      if (item.id == category.id) stored = item;
    }
    final identityChanged =
        stored == null ||
        !stored.isActive ||
        stored.name.toLowerCase() != category.name.toLowerCase() ||
        stored.type != category.type ||
        stored.parentId != category.parentId;
    if (!category.isDefault && identityChanged) {
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
    // Default clones keep their stored createdAt (null when seeded at
    // sign-in): security rules only allow their budget fields to change.
    final categoryToSave = category.createdAt == null && !category.isDefault
        ? category.copyWith(createdAt: DateTime.now().toUtc())
        : category;
    final record = categoryToSave.toOffline(userId: userId);
    if (batch != null) {
      batch.upsert(record);
    } else {
      await _store.upsert(record);
    }
    return record.toDomain();
  }

  /// Deletes the current user's custom category [id]. With a [batch], the
  /// delete is staged there for the caller to commit instead.
  Future<void> delete(String id, {RecordBatch? batch}) async {
    if (CategoryDefaults.allIds.contains(id)) {
      throw StateError('Default categories cannot be deleted.');
    }

    final userId = await _userContext.resolveUserId();
    final categories = await _store.get<OfflineCategory>(
      query: RecordQuery(ownerId: userId, id: id, limit: 1),
    );
    if (categories.isEmpty) {
      return;
    }
    if (categories.first.toDomain().isDefault) {
      throw StateError('Default categories cannot be deleted.');
    }
    if (batch != null) {
      batch.delete(categories.first);
    } else {
      await _store.delete(categories.first);
    }
  }
}
