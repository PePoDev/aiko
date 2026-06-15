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
    groupId: data['group_id'] == null ? null : data['group_id'] as String?,
    parentId: data['parent_id'] == null ? null : data['parent_id'] as String?,
    icon: data['icon'] as String,
    color: data['color'] as String,
    budgetEnabled: data['budget_enabled'] as bool,
    isActive: data['is_active'] as bool,
    createdAt: data['created_at'] == null
        ? null
        : data['created_at'] == null
        ? null
        : DateTime.tryParse(data['created_at'] as String),
    budgetAmount: data['budget_amount'] == null
        ? null
        : data['budget_amount'] == null
        ? null
        : data['budget_amount'].toString(),
    budgetCurrency: data['budget_currency'] == null
        ? null
        : data['budget_currency'] as String?,
    budgetPeriod: budgetPeriodFromColumn(data['budget_period']),
    budgetRollover: data['budget_rollover'] as bool,
    alertThresholds: alertThresholdsFromColumn(data['alert_thresholds']),
    updatedAt: data['updated_at'] == null
        ? null
        : DateTime.tryParse(data['updated_at'] as String),
    version: data['version'] as int ?? 1,
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
    'group_id': instance.groupId,
    'parent_id': instance.parentId,
    'icon': instance.icon,
    'color': instance.color,
    'budget_enabled': instance.budgetEnabled,
    'is_active': instance.isActive,
    'created_at': instance.createdAt?.toIso8601String(),
    'budget_amount': instance.budgetAmount,
    'budget_currency': instance.budgetCurrency,
    'budget_period': instance.budgetPeriod,
    'budget_rollover': instance.budgetRollover,
    'alert_thresholds': instance.alertThresholds,
    'updated_at': instance.updatedAt.toIso8601String(),
    'version': instance.version,
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
    groupId: data['group_id'] == null ? null : data['group_id'] as String?,
    parentId: data['parent_id'] == null ? null : data['parent_id'] as String?,
    icon: data['icon'] as String,
    color: data['color'] as String,
    budgetEnabled: data['budget_enabled'] == 1,
    isActive: data['is_active'] == 1,
    createdAt: data['created_at'] == null
        ? null
        : data['created_at'] == null
        ? null
        : DateTime.tryParse(data['created_at'] as String),
    budgetAmount: data['budget_amount'] == null
        ? null
        : data['budget_amount'] as String?,
    budgetCurrency: data['budget_currency'] == null
        ? null
        : data['budget_currency'] as String?,
    budgetPeriod: budgetPeriodFromColumn(data['budget_period']),
    budgetRollover: data['budget_rollover'] == 1,
    alertThresholds: alertThresholdsFromColumn(data['alert_thresholds']),
    updatedAt: DateTime.parse(data['updated_at'] as String),
    version: data['version'] as int,
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
    'group_id': instance.groupId,
    'parent_id': instance.parentId,
    'icon': instance.icon,
    'color': instance.color,
    'budget_enabled': instance.budgetEnabled ? 1 : 0,
    'is_active': instance.isActive ? 1 : 0,
    'created_at': instance.createdAt?.toIso8601String(),
    'budget_amount': instance.budgetAmount,
    'budget_currency': instance.budgetCurrency,
    'budget_period': instance.budgetPeriod,
    'budget_rollover': instance.budgetRollover ? 1 : 0,
    'alert_thresholds': jsonEncode(instance.alertThresholds),
    'updated_at': instance.updatedAt.toIso8601String(),
    'version': instance.version,
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
    'groupId': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'group_id',
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
    'createdAt': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'created_at',
    ),
    'budgetAmount': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'budget_amount',
    ),
    'budgetCurrency': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'budget_currency',
    ),
    'budgetPeriod': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'budget_period',
    ),
    'budgetRollover': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'budget_rollover',
    ),
    'alertThresholds': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'alert_thresholds',
    ),
    'updatedAt': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'updated_at',
    ),
    'version': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'version',
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
    'groupId': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'group_id',
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
    'createdAt': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'created_at',
      iterable: false,
      type: DateTime,
    ),
    'budgetAmount': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'budget_amount',
      iterable: false,
      type: String,
    ),
    'budgetCurrency': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'budget_currency',
      iterable: false,
      type: String,
    ),
    'budgetPeriod': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'budget_period',
      iterable: false,
      type: String,
    ),
    'budgetRollover': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'budget_rollover',
      iterable: false,
      type: bool,
    ),
    'alertThresholds': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'alert_thresholds',
      iterable: true,
      type: int,
    ),
    'updatedAt': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'updated_at',
      iterable: false,
      type: DateTime,
    ),
    'version': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'version',
      iterable: false,
      type: int,
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
