// GENERATED CODE DO NOT EDIT
part of '../brick.g.dart';

Future<OfflineGoal> _$OfflineGoalFromSupabase(
  Map<String, dynamic> data, {
  required SupabaseProvider provider,
  OfflineFirstWithSupabaseRepository? repository,
}) async {
  return OfflineGoal(
    id: data['id'] as String,
    userId: data['user_id'] as String,
    name: data['name'] as String,
    purpose: data['purpose'] as String,
    targetAmount: data['target_amount'].toString(),
    currentAmount: data['current_amount'].toString(),
    currency: data['currency'] as String,
    targetDate: DateTime.parse(data['target_date'] as String),
    linkedAccountId: data['linked_account_id'] == null
        ? null
        : data['linked_account_id'] as String?,
    priority: data['priority'] as int,
    successProbability: data['success_probability'] == null
        ? null
        : (data['success_probability'] as num?)?.toDouble(),
    status: data['status'] as String,
  );
}

Future<Map<String, dynamic>> _$OfflineGoalToSupabase(
  OfflineGoal instance, {
  required SupabaseProvider provider,
  OfflineFirstWithSupabaseRepository? repository,
}) async {
  return {
    'id': instance.id,
    'user_id': instance.userId,
    'name': instance.name,
    'purpose': instance.purpose,
    'target_amount': instance.targetAmount,
    'current_amount': instance.currentAmount,
    'currency': instance.currency,
    'target_date': instance.targetDate.toIso8601String().substring(0, 10),
    'linked_account_id': instance.linkedAccountId,
    'priority': instance.priority,
    'success_probability': instance.successProbability,
    'status': instance.status,
  };
}

Future<OfflineGoal> _$OfflineGoalFromSqlite(
  Map<String, dynamic> data, {
  required SqliteProvider provider,
  OfflineFirstWithSupabaseRepository? repository,
}) async {
  return OfflineGoal(
    id: data['id'] as String,
    userId: data['user_id'] as String,
    name: data['name'] as String,
    purpose: data['purpose'] as String,
    targetAmount: data['target_amount'] as String,
    currentAmount: data['current_amount'] as String,
    currency: data['currency'] as String,
    targetDate: DateTime.parse(data['target_date'] as String),
    linkedAccountId: data['linked_account_id'] == null
        ? null
        : data['linked_account_id'] as String?,
    priority: data['priority'] as int,
    successProbability: data['success_probability'] == null
        ? null
        : data['success_probability'] as double?,
    status: data['status'] as String,
  )..primaryKey = data['_brick_id'] as int;
}

Future<Map<String, dynamic>> _$OfflineGoalToSqlite(
  OfflineGoal instance, {
  required SqliteProvider provider,
  OfflineFirstWithSupabaseRepository? repository,
}) async {
  return {
    'id': instance.id,
    'user_id': instance.userId,
    'name': instance.name,
    'purpose': instance.purpose,
    'target_amount': instance.targetAmount,
    'current_amount': instance.currentAmount,
    'currency': instance.currency,
    'target_date': instance.targetDate.toIso8601String(),
    'linked_account_id': instance.linkedAccountId,
    'priority': instance.priority,
    'success_probability': instance.successProbability,
    'status': instance.status,
  };
}

/// Construct a [OfflineGoal]
class OfflineGoalAdapter extends OfflineFirstWithSupabaseAdapter<OfflineGoal> {
  OfflineGoalAdapter();

  @override
  final supabaseTableName = 'goals';
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
    'purpose': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'purpose',
    ),
    'targetAmount': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'target_amount',
    ),
    'currentAmount': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'current_amount',
    ),
    'currency': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'currency',
    ),
    'targetDate': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'target_date',
    ),
    'linkedAccountId': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'linked_account_id',
    ),
    'priority': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'priority',
    ),
    'successProbability': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'success_probability',
    ),
    'status': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'status',
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
    'purpose': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'purpose',
      iterable: false,
      type: String,
    ),
    'targetAmount': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'target_amount',
      iterable: false,
      type: String,
    ),
    'currentAmount': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'current_amount',
      iterable: false,
      type: String,
    ),
    'currency': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'currency',
      iterable: false,
      type: String,
    ),
    'targetDate': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'target_date',
      iterable: false,
      type: DateTime,
    ),
    'linkedAccountId': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'linked_account_id',
      iterable: false,
      type: String,
    ),
    'priority': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'priority',
      iterable: false,
      type: int,
    ),
    'successProbability': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'success_probability',
      iterable: false,
      type: double,
    ),
    'status': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'status',
      iterable: false,
      type: String,
    ),
  };
  @override
  Future<int?> primaryKeyByUniqueColumns(
    OfflineGoal instance,
    DatabaseExecutor executor,
  ) async {
    final results = await executor.rawQuery(
      '''
        SELECT * FROM `OfflineGoal` WHERE id = ? LIMIT 1''',
      [instance.id],
    );

    // SQFlite returns [{}] when no results are found
    if (results.isEmpty || (results.length == 1 && results.first.isEmpty)) {
      return null;
    }

    return results.first['_brick_id'] as int;
  }

  @override
  final String tableName = 'OfflineGoal';

  @override
  Future<OfflineGoal> fromSupabase(
    Map<String, dynamic> input, {
    required provider,
    covariant OfflineFirstWithSupabaseRepository? repository,
  }) async => await _$OfflineGoalFromSupabase(
    input,
    provider: provider,
    repository: repository,
  );
  @override
  Future<Map<String, dynamic>> toSupabase(
    OfflineGoal input, {
    required provider,
    covariant OfflineFirstWithSupabaseRepository? repository,
  }) async => await _$OfflineGoalToSupabase(
    input,
    provider: provider,
    repository: repository,
  );
  @override
  Future<OfflineGoal> fromSqlite(
    Map<String, dynamic> input, {
    required provider,
    covariant OfflineFirstWithSupabaseRepository? repository,
  }) async => await _$OfflineGoalFromSqlite(
    input,
    provider: provider,
    repository: repository,
  );
  @override
  Future<Map<String, dynamic>> toSqlite(
    OfflineGoal input, {
    required provider,
    covariant OfflineFirstWithSupabaseRepository? repository,
  }) async => await _$OfflineGoalToSqlite(
    input,
    provider: provider,
    repository: repository,
  );
}
