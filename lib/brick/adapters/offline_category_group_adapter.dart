// SQLite schema compatibility and Firestore document codec. Keep field round-trip tests in sync.
part of '../model_dictionary.dart';

Future<OfflineCategoryGroup> _$OfflineCategoryGroupFromFirestore(
  Map<String, dynamic> data, {
  Object? provider,
  ModelRepository<SqliteModel>? repository,
}) async {
  return OfflineCategoryGroup(
    id: data['id'] as String,
    userId: data['user_id'] == null ? null : data['user_id'] as String?,
    templateId: data['template_id'] == null
        ? null
        : data['template_id'] as String?,
    name: data['name'] as String,
    icon: data['icon'] as String,
    color: data['color'] as String,
    sortOrder: data['sort_order'] as int,
    createdAt: data['created_at'] == null
        ? null
        : data['created_at'] == null
        ? null
        : DateTime.tryParse(data['created_at'] as String),
    budgetAmount: data['budget_amount']?.toString(),
    budgetCurrency: data['budget_currency'] == null
        ? null
        : data['budget_currency'] as String?,
    updatedAt: data['updated_at'] == null
        ? null
        : DateTime.tryParse(data['updated_at'] as String),
    version: data['version'] as int? ?? 1,
  );
}

Future<Map<String, dynamic>> _$OfflineCategoryGroupToFirestore(
  OfflineCategoryGroup instance, {
  Object? provider,
  ModelRepository<SqliteModel>? repository,
}) async {
  return {
    'id': instance.id,
    'user_id': instance.userId,
    'template_id': instance.templateId,
    'name': instance.name,
    'icon': instance.icon,
    'color': instance.color,
    'sort_order': instance.sortOrder,
    'created_at': instance.createdAt?.toIso8601String(),
    'budget_amount': instance.budgetAmount,
    'budget_currency': instance.budgetCurrency,
    'updated_at': instance.updatedAt.toIso8601String(),
    'version': instance.version,
  };
}

Future<OfflineCategoryGroup> _$OfflineCategoryGroupFromSqlite(
  Map<String, dynamic> data, {
  required SqliteProvider provider,
  ModelRepository<SqliteModel>? repository,
}) async {
  return OfflineCategoryGroup(
    id: data['id'] as String,
    userId: data['user_id'] == null ? null : data['user_id'] as String?,
    templateId: data['template_id'] == null
        ? null
        : data['template_id'] as String?,
    name: data['name'] as String,
    icon: data['icon'] as String,
    color: data['color'] as String,
    sortOrder: data['sort_order'] as int,
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
    updatedAt: DateTime.parse(data['updated_at'] as String),
    version: data['version'] as int,
  )..primaryKey = data['_brick_id'] as int;
}

Future<Map<String, dynamic>> _$OfflineCategoryGroupToSqlite(
  OfflineCategoryGroup instance, {
  required SqliteProvider provider,
  ModelRepository<SqliteModel>? repository,
}) async {
  return {
    'id': instance.id,
    'user_id': instance.userId,
    'template_id': instance.templateId,
    'name': instance.name,
    'icon': instance.icon,
    'color': instance.color,
    'sort_order': instance.sortOrder,
    'created_at': instance.createdAt?.toIso8601String(),
    'budget_amount': instance.budgetAmount,
    'budget_currency': instance.budgetCurrency,
    'updated_at': instance.updatedAt.toIso8601String(),
    'version': instance.version,
  };
}

/// Construct a [OfflineCategoryGroup]
class OfflineCategoryGroupAdapter
    extends FirestoreAdapter<OfflineCategoryGroup> {
  OfflineCategoryGroupAdapter();

  @override
  final collectionName = 'category_groups';
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
    'templateId': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'template_id',
      iterable: false,
      type: String,
    ),
    'name': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'name',
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
    'sortOrder': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'sort_order',
      iterable: false,
      type: int,
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
    OfflineCategoryGroup instance,
    DatabaseExecutor executor,
  ) async {
    final results = await executor.rawQuery(
      '''
        SELECT * FROM `OfflineCategoryGroup` WHERE id = ? LIMIT 1''',
      [instance.id],
    );

    // SQFlite returns [{}] when no results are found
    if (results.isEmpty || (results.length == 1 && results.first.isEmpty)) {
      return null;
    }

    return results.first['_brick_id'] as int;
  }

  @override
  final String tableName = 'OfflineCategoryGroup';

  @override
  Future<OfflineCategoryGroup> fromFirestore(
    Map<String, dynamic> input, {
    provider,
    covariant ModelRepository<SqliteModel>? repository,
  }) async => await _$OfflineCategoryGroupFromFirestore(
    input,
    provider: provider,
    repository: repository,
  );
  @override
  Future<Map<String, dynamic>> toFirestore(
    OfflineCategoryGroup input, {
    provider,
    covariant ModelRepository<SqliteModel>? repository,
  }) async => await _$OfflineCategoryGroupToFirestore(
    input,
    provider: provider,
    repository: repository,
  );
  @override
  Future<OfflineCategoryGroup> fromSqlite(
    Map<String, dynamic> input, {
    required provider,
    covariant ModelRepository<SqliteModel>? repository,
  }) async => await _$OfflineCategoryGroupFromSqlite(
    input,
    provider: provider,
    repository: repository,
  );
  @override
  Future<Map<String, dynamic>> toSqlite(
    OfflineCategoryGroup input, {
    required provider,
    covariant ModelRepository<SqliteModel>? repository,
  }) async => await _$OfflineCategoryGroupToSqlite(
    input,
    provider: provider,
    repository: repository,
  );
}
