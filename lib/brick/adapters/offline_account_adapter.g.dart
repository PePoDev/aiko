// GENERATED CODE DO NOT EDIT
part of '../brick.g.dart';

Future<OfflineAccount> _$OfflineAccountFromSupabase(
  Map<String, dynamic> data, {
  required SupabaseProvider provider,
  OfflineFirstWithSupabaseRepository? repository,
}) async {
  return OfflineAccount(
    id: data['id'] as String,
    userId: data['user_id'] as String,
    name: data['name'] as String,
    type: data['type'] as String,
    currency: data['currency'] as String,
    currentBalance: data['current_balance'].toString(),
    institution: data['institution'] == null
        ? null
        : data['institution'] as String?,
    includeInNetWorth: data['include_in_net_worth'] as bool,
    isActive: data['is_active'] as bool,
    detailsJson: accountDetailsFromSupabase(data['details']),
    goalTargetAmount: data['goal_target_amount'] == null
        ? null
        : data['goal_target_amount'] == null
        ? null
        : data['goal_target_amount'].toString(),
    goalTargetDate: data['goal_target_date'] == null
        ? null
        : data['goal_target_date'] == null
        ? null
        : DateTime.tryParse(data['goal_target_date'] as String),
    goalPriority: data['goal_priority'] as String,
    updatedAt: data['updated_at'] == null
        ? null
        : DateTime.tryParse(data['updated_at'] as String),
    deletedAt: data['deleted_at'] == null
        ? null
        : data['deleted_at'] == null
        ? null
        : DateTime.tryParse(data['deleted_at'] as String),
    version: data['version'] as int ?? 1,
  );
}

Future<Map<String, dynamic>> _$OfflineAccountToSupabase(
  OfflineAccount instance, {
  required SupabaseProvider provider,
  OfflineFirstWithSupabaseRepository? repository,
}) async {
  return {
    'id': instance.id,
    'user_id': instance.userId,
    'name': instance.name,
    'type': instance.type,
    'currency': instance.currency,
    'current_balance': instance.currentBalance,
    'institution': instance.institution,
    'include_in_net_worth': instance.includeInNetWorth,
    'is_active': instance.isActive,
    'details': accountDetailsToSupabase(instance.detailsJson),
    'goal_target_amount': instance.goalTargetAmount,
    'goal_target_date': instance.goalTargetDate?.toIso8601String(),
    'goal_priority': instance.goalPriority,
    'updated_at': instance.updatedAt.toIso8601String(),
    'deleted_at': instance.deletedAt?.toIso8601String(),
    'version': instance.version,
  };
}

Future<OfflineAccount> _$OfflineAccountFromSqlite(
  Map<String, dynamic> data, {
  required SqliteProvider provider,
  OfflineFirstWithSupabaseRepository? repository,
}) async {
  return OfflineAccount(
    id: data['id'] as String,
    userId: data['user_id'] as String,
    name: data['name'] as String,
    type: data['type'] as String,
    currency: data['currency'] as String,
    currentBalance: data['current_balance'] as String,
    institution: data['institution'] == null
        ? null
        : data['institution'] as String?,
    includeInNetWorth: data['include_in_net_worth'] == 1,
    isActive: data['is_active'] == 1,
    detailsJson: accountDetailsFromSqlite(data['details_json']),
    goalTargetAmount: data['goal_target_amount'] == null
        ? null
        : data['goal_target_amount'] as String?,
    goalTargetDate: data['goal_target_date'] == null
        ? null
        : data['goal_target_date'] == null
        ? null
        : DateTime.tryParse(data['goal_target_date'] as String),
    goalPriority: data['goal_priority'] as String,
    updatedAt: DateTime.parse(data['updated_at'] as String),
    deletedAt: data['deleted_at'] == null
        ? null
        : data['deleted_at'] == null
        ? null
        : DateTime.tryParse(data['deleted_at'] as String),
    version: data['version'] as int,
  )..primaryKey = data['_brick_id'] as int;
}

Future<Map<String, dynamic>> _$OfflineAccountToSqlite(
  OfflineAccount instance, {
  required SqliteProvider provider,
  OfflineFirstWithSupabaseRepository? repository,
}) async {
  return {
    'id': instance.id,
    'user_id': instance.userId,
    'name': instance.name,
    'type': instance.type,
    'currency': instance.currency,
    'current_balance': instance.currentBalance,
    'institution': instance.institution,
    'include_in_net_worth': instance.includeInNetWorth ? 1 : 0,
    'is_active': instance.isActive ? 1 : 0,
    'details_json': instance.detailsJson,
    'goal_target_amount': instance.goalTargetAmount,
    'goal_target_date': instance.goalTargetDate?.toIso8601String(),
    'goal_priority': instance.goalPriority,
    'updated_at': instance.updatedAt.toIso8601String(),
    'deleted_at': instance.deletedAt?.toIso8601String(),
    'version': instance.version,
  };
}

/// Construct a [OfflineAccount]
class OfflineAccountAdapter
    extends OfflineFirstWithSupabaseAdapter<OfflineAccount> {
  OfflineAccountAdapter();

  @override
  final supabaseTableName = 'accounts';
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
    'currency': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'currency',
    ),
    'currentBalance': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'current_balance',
    ),
    'institution': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'institution',
    ),
    'includeInNetWorth': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'include_in_net_worth',
    ),
    'isActive': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'is_active',
    ),
    'detailsJson': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'details',
    ),
    'goalTargetAmount': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'goal_target_amount',
    ),
    'goalTargetDate': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'goal_target_date',
    ),
    'goalPriority': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'goal_priority',
    ),
    'updatedAt': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'updated_at',
    ),
    'deletedAt': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'deleted_at',
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
    'currency': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'currency',
      iterable: false,
      type: String,
    ),
    'currentBalance': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'current_balance',
      iterable: false,
      type: String,
    ),
    'institution': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'institution',
      iterable: false,
      type: String,
    ),
    'includeInNetWorth': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'include_in_net_worth',
      iterable: false,
      type: bool,
    ),
    'isActive': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'is_active',
      iterable: false,
      type: bool,
    ),
    'detailsJson': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'details_json',
      iterable: false,
      type: String,
    ),
    'goalTargetAmount': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'goal_target_amount',
      iterable: false,
      type: String,
    ),
    'goalTargetDate': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'goal_target_date',
      iterable: false,
      type: DateTime,
    ),
    'goalPriority': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'goal_priority',
      iterable: false,
      type: String,
    ),
    'updatedAt': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'updated_at',
      iterable: false,
      type: DateTime,
    ),
    'deletedAt': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'deleted_at',
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
    OfflineAccount instance,
    DatabaseExecutor executor,
  ) async {
    final results = await executor.rawQuery(
      '''
        SELECT * FROM `OfflineAccount` WHERE id = ? LIMIT 1''',
      [instance.id],
    );

    // SQFlite returns [{}] when no results are found
    if (results.isEmpty || (results.length == 1 && results.first.isEmpty)) {
      return null;
    }

    return results.first['_brick_id'] as int;
  }

  @override
  final String tableName = 'OfflineAccount';

  @override
  Future<OfflineAccount> fromSupabase(
    Map<String, dynamic> input, {
    required provider,
    covariant OfflineFirstWithSupabaseRepository? repository,
  }) async => await _$OfflineAccountFromSupabase(
    input,
    provider: provider,
    repository: repository,
  );
  @override
  Future<Map<String, dynamic>> toSupabase(
    OfflineAccount input, {
    required provider,
    covariant OfflineFirstWithSupabaseRepository? repository,
  }) async => await _$OfflineAccountToSupabase(
    input,
    provider: provider,
    repository: repository,
  );
  @override
  Future<OfflineAccount> fromSqlite(
    Map<String, dynamic> input, {
    required provider,
    covariant OfflineFirstWithSupabaseRepository? repository,
  }) async => await _$OfflineAccountFromSqlite(
    input,
    provider: provider,
    repository: repository,
  );
  @override
  Future<Map<String, dynamic>> toSqlite(
    OfflineAccount input, {
    required provider,
    covariant OfflineFirstWithSupabaseRepository? repository,
  }) async => await _$OfflineAccountToSqlite(
    input,
    provider: provider,
    repository: repository,
  );
}
