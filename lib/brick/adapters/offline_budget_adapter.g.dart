// GENERATED CODE DO NOT EDIT
part of '../brick.g.dart';

Future<OfflineBudget> _$OfflineBudgetFromSupabase(
  Map<String, dynamic> data, {
  required SupabaseProvider provider,
  OfflineFirstWithSupabaseRepository? repository,
}) async {
  return OfflineBudget(
    id: data['id'] as String,
    userId: data['user_id'] as String,
    name: data['name'] as String,
    categoryId: data['category_id'] as String,
    amount: data['amount'].toString(),
    currency: data['currency'] as String,
    periodStart: DateTime.parse(data['period_start'] as String),
    periodEnd: DateTime.parse(data['period_end'] as String),
    period: data['period'] as String,
    alertThresholds: data['alert_thresholds'].toList().cast<int>(),
    status: data['status'] as String,
  );
}

Future<Map<String, dynamic>> _$OfflineBudgetToSupabase(
  OfflineBudget instance, {
  required SupabaseProvider provider,
  OfflineFirstWithSupabaseRepository? repository,
}) async {
  return {
    'id': instance.id,
    'user_id': instance.userId,
    'name': instance.name,
    'category_id': instance.categoryId,
    'amount': instance.amount,
    'currency': instance.currency,
    'period_start': instance.periodStart.toIso8601String().substring(0, 10),
    'period_end': instance.periodEnd.toIso8601String().substring(0, 10),
    'period': instance.period,
    'alert_thresholds': instance.alertThresholds,
    'status': instance.status,
  };
}

Future<OfflineBudget> _$OfflineBudgetFromSqlite(
  Map<String, dynamic> data, {
  required SqliteProvider provider,
  OfflineFirstWithSupabaseRepository? repository,
}) async {
  return OfflineBudget(
    id: data['id'] as String,
    userId: data['user_id'] as String,
    name: data['name'] as String,
    categoryId: data['category_id'] as String,
    amount: data['amount'] as String,
    currency: data['currency'] as String,
    periodStart: DateTime.parse(data['period_start'] as String),
    periodEnd: DateTime.parse(data['period_end'] as String),
    period: data['period'] as String,
    alertThresholds: jsonDecode(data['alert_thresholds']).toList().cast<int>(),
    status: data['status'] as String,
  )..primaryKey = data['_brick_id'] as int;
}

Future<Map<String, dynamic>> _$OfflineBudgetToSqlite(
  OfflineBudget instance, {
  required SqliteProvider provider,
  OfflineFirstWithSupabaseRepository? repository,
}) async {
  return {
    'id': instance.id,
    'user_id': instance.userId,
    'name': instance.name,
    'category_id': instance.categoryId,
    'amount': instance.amount,
    'currency': instance.currency,
    'period_start': instance.periodStart.toIso8601String(),
    'period_end': instance.periodEnd.toIso8601String(),
    'period': instance.period,
    'alert_thresholds': jsonEncode(instance.alertThresholds),
    'status': instance.status,
  };
}

/// Construct a [OfflineBudget]
class OfflineBudgetAdapter
    extends OfflineFirstWithSupabaseAdapter<OfflineBudget> {
  OfflineBudgetAdapter();

  @override
  final supabaseTableName = 'budgets';
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
    'categoryId': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'category_id',
    ),
    'amount': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'amount',
    ),
    'currency': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'currency',
    ),
    'periodStart': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'period_start',
    ),
    'periodEnd': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'period_end',
    ),
    'period': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'period',
    ),
    'alertThresholds': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'alert_thresholds',
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
    'categoryId': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'category_id',
      iterable: false,
      type: String,
    ),
    'amount': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'amount',
      iterable: false,
      type: String,
    ),
    'currency': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'currency',
      iterable: false,
      type: String,
    ),
    'periodStart': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'period_start',
      iterable: false,
      type: DateTime,
    ),
    'periodEnd': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'period_end',
      iterable: false,
      type: DateTime,
    ),
    'period': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'period',
      iterable: false,
      type: String,
    ),
    'alertThresholds': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'alert_thresholds',
      iterable: true,
      type: int,
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
    OfflineBudget instance,
    DatabaseExecutor executor,
  ) async {
    final results = await executor.rawQuery(
      '''
        SELECT * FROM `OfflineBudget` WHERE id = ? LIMIT 1''',
      [instance.id],
    );

    // SQFlite returns [{}] when no results are found
    if (results.isEmpty || (results.length == 1 && results.first.isEmpty)) {
      return null;
    }

    return results.first['_brick_id'] as int;
  }

  @override
  final String tableName = 'OfflineBudget';

  @override
  Future<OfflineBudget> fromSupabase(
    Map<String, dynamic> input, {
    required provider,
    covariant OfflineFirstWithSupabaseRepository? repository,
  }) async => await _$OfflineBudgetFromSupabase(
    input,
    provider: provider,
    repository: repository,
  );
  @override
  Future<Map<String, dynamic>> toSupabase(
    OfflineBudget input, {
    required provider,
    covariant OfflineFirstWithSupabaseRepository? repository,
  }) async => await _$OfflineBudgetToSupabase(
    input,
    provider: provider,
    repository: repository,
  );
  @override
  Future<OfflineBudget> fromSqlite(
    Map<String, dynamic> input, {
    required provider,
    covariant OfflineFirstWithSupabaseRepository? repository,
  }) async => await _$OfflineBudgetFromSqlite(
    input,
    provider: provider,
    repository: repository,
  );
  @override
  Future<Map<String, dynamic>> toSqlite(
    OfflineBudget input, {
    required provider,
    covariant OfflineFirstWithSupabaseRepository? repository,
  }) async => await _$OfflineBudgetToSqlite(
    input,
    provider: provider,
    repository: repository,
  );
}
