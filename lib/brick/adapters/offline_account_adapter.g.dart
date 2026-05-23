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
    openingBalance: data['opening_balance'].toString(),
    currentBalance: data['current_balance'].toString(),
    institution: data['institution'] == null
        ? null
        : data['institution'] as String?,
    includeInNetWorth: data['include_in_net_worth'] as bool,
    isActive: data['is_active'] as bool,
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
    'opening_balance': instance.openingBalance,
    'current_balance': instance.currentBalance,
    'institution': instance.institution,
    'include_in_net_worth': instance.includeInNetWorth,
    'is_active': instance.isActive,
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
    openingBalance: data['opening_balance'] as String,
    currentBalance: data['current_balance'] as String,
    institution: data['institution'] == null
        ? null
        : data['institution'] as String?,
    includeInNetWorth: data['include_in_net_worth'] == 1,
    isActive: data['is_active'] == 1,
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
    'opening_balance': instance.openingBalance,
    'current_balance': instance.currentBalance,
    'institution': instance.institution,
    'include_in_net_worth': instance.includeInNetWorth ? 1 : 0,
    'is_active': instance.isActive ? 1 : 0,
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
    'openingBalance': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'opening_balance',
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
    'openingBalance': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'opening_balance',
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
