// GENERATED CODE DO NOT EDIT
part of '../brick.g.dart';

Future<OfflineCategory> _$OfflineCategoryFromSupabase(
  Map<String, dynamic> data, {
  required SupabaseProvider provider,
  OfflineFirstWithSupabaseRepository? repository,
}) async {
  return OfflineCategory(
    id: data['id'] as String,
    userId: data['user_id'] as String,
    name: data['name'] as String,
    type: data['type'] as String,
    categoryGroup: data['group'] as String,
    parentId: data['parent_id'] == null ? null : data['parent_id'] as String?,
    icon: data['icon'] as String,
    color: data['color'] as String,
    budgetEnabled: data['budget_enabled'] as bool,
    isActive: data['is_active'] as bool,
  );
}

Future<Map<String, dynamic>> _$OfflineCategoryToSupabase(
  OfflineCategory instance, {
  required SupabaseProvider provider,
  OfflineFirstWithSupabaseRepository? repository,
}) async {
  return {
    'id': instance.id,
    'user_id': instance.userId,
    'name': instance.name,
    'type': instance.type,
    'group': instance.categoryGroup,
    'parent_id': instance.parentId,
    'icon': instance.icon,
    'color': instance.color,
    'budget_enabled': instance.budgetEnabled,
    'is_active': instance.isActive,
  };
}

Future<OfflineCategory> _$OfflineCategoryFromSqlite(
  Map<String, dynamic> data, {
  required SqliteProvider provider,
  OfflineFirstWithSupabaseRepository? repository,
}) async {
  return OfflineCategory(
    id: data['id'] as String,
    userId: data['user_id'] as String,
    name: data['name'] as String,
    type: data['type'] as String,
    categoryGroup: data['category_group'] as String,
    parentId: data['parent_id'] == null ? null : data['parent_id'] as String?,
    icon: data['icon'] as String,
    color: data['color'] as String,
    budgetEnabled: data['budget_enabled'] == 1,
    isActive: data['is_active'] == 1,
  )..primaryKey = data['_brick_id'] as int;
}

Future<Map<String, dynamic>> _$OfflineCategoryToSqlite(
  OfflineCategory instance, {
  required SqliteProvider provider,
  OfflineFirstWithSupabaseRepository? repository,
}) async {
  return {
    'id': instance.id,
    'user_id': instance.userId,
    'name': instance.name,
    'type': instance.type,
    'category_group': instance.categoryGroup,
    'parent_id': instance.parentId,
    'icon': instance.icon,
    'color': instance.color,
    'budget_enabled': instance.budgetEnabled ? 1 : 0,
    'is_active': instance.isActive ? 1 : 0,
  };
}

/// Construct a [OfflineCategory]
class OfflineCategoryAdapter
    extends OfflineFirstWithSupabaseAdapter<OfflineCategory> {
  OfflineCategoryAdapter();

  @override
  final supabaseTableName = 'categories';
  @override
  final defaultToNull = true;
  @override
  final fieldsToSupabaseColumns = {
    'id': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'id',
    ),
    'userId': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'user_id',
    ),
    'name': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'name',
    ),
    'type': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'type',
    ),
    'categoryGroup': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'group',
    ),
    'parentId': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'parent_id',
    ),
    'icon': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'icon',
    ),
    'color': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'color',
    ),
    'budgetEnabled': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'budget_enabled',
    ),
    'isActive': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'is_active',
    ),
  };
  @override
  final ignoreDuplicates = false;
  @override
  final uniqueFields = {'id'};
  @override
  final Map<String, RuntimeSqliteColumnDefinition> fieldsToSqliteColumns = {
    'primaryKey': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: '_brick_id',
      iterable: false,
      type: int,
    ),
    'id': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'id',
      iterable: false,
      type: String,
    ),
    'userId': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'user_id',
      iterable: false,
      type: String,
    ),
    'name': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'name',
      iterable: false,
      type: String,
    ),
    'type': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'type',
      iterable: false,
      type: String,
    ),
    'categoryGroup': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'category_group',
      iterable: false,
      type: String,
    ),
    'parentId': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'parent_id',
      iterable: false,
      type: String,
    ),
    'icon': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'icon',
      iterable: false,
      type: String,
    ),
    'color': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'color',
      iterable: false,
      type: String,
    ),
    'budgetEnabled': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'budget_enabled',
      iterable: false,
      type: bool,
    ),
    'isActive': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'is_active',
      iterable: false,
      type: bool,
    ),
  };
  @override
  Future<int?> primaryKeyByUniqueColumns(
    OfflineCategory instance,
    DatabaseExecutor executor,
  ) async {
    final results = await executor.rawQuery(
      '''
        SELECT * FROM `OfflineCategory` WHERE id = ? LIMIT 1''',
      [instance.id],
    );

    // SQFlite returns [{}] when no results are found
    if (results.isEmpty || (results.length == 1 && results.first.isEmpty)) {
      return null;
    }

    return results.first['_brick_id'] as int;
  }

  @override
  final String tableName = 'OfflineCategory';

  @override
  Future<OfflineCategory> fromSupabase(
    Map<String, dynamic> input, {
    required provider,
    covariant OfflineFirstWithSupabaseRepository? repository,
  }) async => await _$OfflineCategoryFromSupabase(
    input,
    provider: provider,
    repository: repository,
  );
  @override
  Future<Map<String, dynamic>> toSupabase(
    OfflineCategory input, {
    required provider,
    covariant OfflineFirstWithSupabaseRepository? repository,
  }) async => await _$OfflineCategoryToSupabase(
    input,
    provider: provider,
    repository: repository,
  );
  @override
  Future<OfflineCategory> fromSqlite(
    Map<String, dynamic> input, {
    required provider,
    covariant OfflineFirstWithSupabaseRepository? repository,
  }) async => await _$OfflineCategoryFromSqlite(
    input,
    provider: provider,
    repository: repository,
  );
  @override
  Future<Map<String, dynamic>> toSqlite(
    OfflineCategory input, {
    required provider,
    covariant OfflineFirstWithSupabaseRepository? repository,
  }) async => await _$OfflineCategoryToSqlite(
    input,
    provider: provider,
    repository: repository,
  );
}
