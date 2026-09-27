// SQLite schema compatibility and Firestore document codec. Keep field round-trip tests in sync.
part of '../model_dictionary.dart';

Future<OfflineTransaction> _$OfflineTransactionFromFirestore(
  Map<String, dynamic> data, {
  Object? provider,
  ModelRepository<SqliteModel>? repository,
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
    isRecurring: data['is_recurring'] as bool,
    recurringFrequency: data['recurring_frequency'] == null
        ? null
        : data['recurring_frequency'] as String?,
    recurringEndDate: data['recurring_end_date'] == null
        ? null
        : data['recurring_end_date'] == null
        ? null
        : DateTime.tryParse(data['recurring_end_date'] as String),
    recurringMaxOccurrences: data['recurring_max_occurrences'] == null
        ? null
        : data['recurring_max_occurrences'] as int?,
    recurringDayOfWeek: data['recurring_day_of_week'] == null
        ? null
        : data['recurring_day_of_week'] as int?,
    recurringDayOfMonth: data['recurring_day_of_month'] == null
        ? null
        : data['recurring_day_of_month'] as int?,
    recurringMonthOfYear: data['recurring_month_of_year'] == null
        ? null
        : data['recurring_month_of_year'] as int?,
    reminderAt: data['reminder_at'] == null
        ? null
        : data['reminder_at'] == null
        ? null
        : DateTime.tryParse(data['reminder_at'] as String),
    updatedAt: data['updated_at'] == null
        ? null
        : DateTime.tryParse(data['updated_at'] as String),
    version: data['version'] as int? ?? 1,
  );
}

Future<Map<String, dynamic>> _$OfflineTransactionToFirestore(
  OfflineTransaction instance, {
  Object? provider,
  ModelRepository<SqliteModel>? repository,
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
    'tags': instance.tags,
    'status': instance.status,
    'is_recurring': instance.isRecurring,
    'recurring_frequency': instance.recurringFrequency,
    'recurring_end_date': instance.recurringEndDate?.toIso8601String(),
    'recurring_max_occurrences': instance.recurringMaxOccurrences,
    'recurring_day_of_week': instance.recurringDayOfWeek,
    'recurring_day_of_month': instance.recurringDayOfMonth,
    'recurring_month_of_year': instance.recurringMonthOfYear,
    'reminder_at': instance.reminderAt?.toIso8601String(),
    'updated_at': instance.updatedAt.toIso8601String(),
    'version': instance.version,
  };
}

Future<OfflineTransaction> _$OfflineTransactionFromSqlite(
  Map<String, dynamic> data, {
  required SqliteProvider provider,
  ModelRepository<SqliteModel>? repository,
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
    isRecurring: data['is_recurring'] == 1,
    recurringFrequency: data['recurring_frequency'] == null
        ? null
        : data['recurring_frequency'] as String?,
    recurringEndDate: data['recurring_end_date'] == null
        ? null
        : data['recurring_end_date'] == null
        ? null
        : DateTime.tryParse(data['recurring_end_date'] as String),
    recurringMaxOccurrences: data['recurring_max_occurrences'] == null
        ? null
        : data['recurring_max_occurrences'] as int?,
    recurringDayOfWeek: data['recurring_day_of_week'] == null
        ? null
        : data['recurring_day_of_week'] as int?,
    recurringDayOfMonth: data['recurring_day_of_month'] == null
        ? null
        : data['recurring_day_of_month'] as int?,
    recurringMonthOfYear: data['recurring_month_of_year'] == null
        ? null
        : data['recurring_month_of_year'] as int?,
    reminderAt: data['reminder_at'] == null
        ? null
        : data['reminder_at'] == null
        ? null
        : DateTime.tryParse(data['reminder_at'] as String),
    updatedAt: DateTime.parse(data['updated_at'] as String),
    version: data['version'] as int,
  )..primaryKey = data['_brick_id'] as int;
}

Future<Map<String, dynamic>> _$OfflineTransactionToSqlite(
  OfflineTransaction instance, {
  required SqliteProvider provider,
  ModelRepository<SqliteModel>? repository,
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
    'is_recurring': instance.isRecurring ? 1 : 0,
    'recurring_frequency': instance.recurringFrequency,
    'recurring_end_date': instance.recurringEndDate?.toIso8601String(),
    'recurring_max_occurrences': instance.recurringMaxOccurrences,
    'recurring_day_of_week': instance.recurringDayOfWeek,
    'recurring_day_of_month': instance.recurringDayOfMonth,
    'recurring_month_of_year': instance.recurringMonthOfYear,
    'reminder_at': instance.reminderAt?.toIso8601String(),
    'updated_at': instance.updatedAt.toIso8601String(),
    'version': instance.version,
  };
}

/// Construct a [OfflineTransaction]
class OfflineTransactionAdapter extends FirestoreAdapter<OfflineTransaction> {
  OfflineTransactionAdapter();

  @override
  final collectionName = 'transactions';
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
    'isRecurring': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'is_recurring',
      iterable: false,
      type: bool,
    ),
    'recurringFrequency': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'recurring_frequency',
      iterable: false,
      type: String,
    ),
    'recurringEndDate': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'recurring_end_date',
      iterable: false,
      type: DateTime,
    ),
    'recurringMaxOccurrences': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'recurring_max_occurrences',
      iterable: false,
      type: int,
    ),
    'recurringDayOfWeek': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'recurring_day_of_week',
      iterable: false,
      type: int,
    ),
    'recurringDayOfMonth': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'recurring_day_of_month',
      iterable: false,
      type: int,
    ),
    'recurringMonthOfYear': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'recurring_month_of_year',
      iterable: false,
      type: int,
    ),
    'reminderAt': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'reminder_at',
      iterable: false,
      type: DateTime,
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
  Future<OfflineTransaction> fromFirestore(
    Map<String, dynamic> input, {
    provider,
    covariant ModelRepository<SqliteModel>? repository,
  }) async => await _$OfflineTransactionFromFirestore(
    input,
    provider: provider,
    repository: repository,
  );
  @override
  Future<Map<String, dynamic>> toFirestore(
    OfflineTransaction input, {
    provider,
    covariant ModelRepository<SqliteModel>? repository,
  }) async => await _$OfflineTransactionToFirestore(
    input,
    provider: provider,
    repository: repository,
  );
  @override
  Future<OfflineTransaction> fromSqlite(
    Map<String, dynamic> input, {
    required provider,
    covariant ModelRepository<SqliteModel>? repository,
  }) async => await _$OfflineTransactionFromSqlite(
    input,
    provider: provider,
    repository: repository,
  );
  @override
  Future<Map<String, dynamic>> toSqlite(
    OfflineTransaction input, {
    required provider,
    covariant ModelRepository<SqliteModel>? repository,
  }) async => await _$OfflineTransactionToSqlite(
    input,
    provider: provider,
    repository: repository,
  );
}
