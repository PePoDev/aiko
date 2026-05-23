// GENERATED CODE DO NOT EDIT
part of '../brick.g.dart';

Future<OfflineTransaction> _$OfflineTransactionFromSupabase(
  Map<String, dynamic> data, {
  required SupabaseProvider provider,
  OfflineFirstWithSupabaseRepository? repository,
}) async {
  return OfflineTransaction(
    id: data['id'] as String,
    userId: data['user_id'] as String,
    accountId: data['account_id'] as String,
    type: data['type'] as String,
    amount: data['amount'].toString(),
    currency: data['currency'] as String,
    date: DateTime.parse(data['date'] as String),
    categoryId: data['category_id'] == null
        ? null
        : data['category_id'] as String?,
    merchant: data['merchant'] == null ? null : data['merchant'] as String?,
    note: data['note'] == null ? null : data['note'] as String?,
    tags: data['tags'].toList().cast<String>(),
    status: data['status'] as String,
  );
}

Future<Map<String, dynamic>> _$OfflineTransactionToSupabase(
  OfflineTransaction instance, {
  required SupabaseProvider provider,
  OfflineFirstWithSupabaseRepository? repository,
}) async {
  return {
    'id': instance.id,
    'user_id': instance.userId,
    'account_id': instance.accountId,
    'type': instance.type,
    'amount': instance.amount,
    'currency': instance.currency,
    'date': instance.date.toIso8601String().substring(0, 10),
    'category_id': instance.categoryId,
    'merchant': instance.merchant,
    'note': instance.note,
    'tags': instance.tags,
    'status': instance.status,
  };
}

Future<OfflineTransaction> _$OfflineTransactionFromSqlite(
  Map<String, dynamic> data, {
  required SqliteProvider provider,
  OfflineFirstWithSupabaseRepository? repository,
}) async {
  return OfflineTransaction(
    id: data['id'] as String,
    userId: data['user_id'] as String,
    accountId: data['account_id'] as String,
    type: data['type'] as String,
    amount: data['amount'] as String,
    currency: data['currency'] as String,
    date: DateTime.parse(data['date'] as String),
    categoryId: data['category_id'] == null
        ? null
        : data['category_id'] as String?,
    merchant: data['merchant'] == null ? null : data['merchant'] as String?,
    note: data['note'] == null ? null : data['note'] as String?,
    tags: jsonDecode(data['tags']).toList().cast<String>(),
    status: data['status'] as String,
  )..primaryKey = data['_brick_id'] as int;
}

Future<Map<String, dynamic>> _$OfflineTransactionToSqlite(
  OfflineTransaction instance, {
  required SqliteProvider provider,
  OfflineFirstWithSupabaseRepository? repository,
}) async {
  return {
    'id': instance.id,
    'user_id': instance.userId,
    'account_id': instance.accountId,
    'type': instance.type,
    'amount': instance.amount,
    'currency': instance.currency,
    'date': instance.date.toIso8601String(),
    'category_id': instance.categoryId,
    'merchant': instance.merchant,
    'note': instance.note,
    'tags': jsonEncode(instance.tags),
    'status': instance.status,
  };
}

/// Construct a [OfflineTransaction]
class OfflineTransactionAdapter
    extends OfflineFirstWithSupabaseAdapter<OfflineTransaction> {
  OfflineTransactionAdapter();

  @override
  final supabaseTableName = 'transactions';
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
    'accountId': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'account_id',
    ),
    'type': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'type',
    ),
    'amount': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'amount',
    ),
    'currency': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'currency',
    ),
    'date': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'date',
    ),
    'categoryId': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'category_id',
    ),
    'merchant': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'merchant',
    ),
    'note': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'note',
    ),
    'tags': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'tags',
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
    'accountId': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'account_id',
      iterable: false,
      type: String,
    ),
    'type': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'type',
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
    'date': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'date',
      iterable: false,
      type: DateTime,
    ),
    'categoryId': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'category_id',
      iterable: false,
      type: String,
    ),
    'merchant': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'merchant',
      iterable: false,
      type: String,
    ),
    'note': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'note',
      iterable: false,
      type: String,
    ),
    'tags': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'tags',
      iterable: true,
      type: String,
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
    OfflineTransaction instance,
    DatabaseExecutor executor,
  ) async {
    final results = await executor.rawQuery(
      '''
        SELECT * FROM `OfflineTransaction` WHERE id = ? LIMIT 1''',
      [instance.id],
    );

    // SQFlite returns [{}] when no results are found
    if (results.isEmpty || (results.length == 1 && results.first.isEmpty)) {
      return null;
    }

    return results.first['_brick_id'] as int;
  }

  @override
  final String tableName = 'OfflineTransaction';

  @override
  Future<OfflineTransaction> fromSupabase(
    Map<String, dynamic> input, {
    required provider,
    covariant OfflineFirstWithSupabaseRepository? repository,
  }) async => await _$OfflineTransactionFromSupabase(
    input,
    provider: provider,
    repository: repository,
  );
  @override
  Future<Map<String, dynamic>> toSupabase(
    OfflineTransaction input, {
    required provider,
    covariant OfflineFirstWithSupabaseRepository? repository,
  }) async => await _$OfflineTransactionToSupabase(
    input,
    provider: provider,
    repository: repository,
  );
  @override
  Future<OfflineTransaction> fromSqlite(
    Map<String, dynamic> input, {
    required provider,
    covariant OfflineFirstWithSupabaseRepository? repository,
  }) async => await _$OfflineTransactionFromSqlite(
    input,
    provider: provider,
    repository: repository,
  );
  @override
  Future<Map<String, dynamic>> toSqlite(
    OfflineTransaction input, {
    required provider,
    covariant OfflineFirstWithSupabaseRepository? repository,
  }) async => await _$OfflineTransactionToSqlite(
    input,
    provider: provider,
    repository: repository,
  );
}
