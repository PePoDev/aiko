// SQLite schema compatibility and Firestore document codec. Keep field round-trip tests in sync.
part of '../model_dictionary.dart';

Future<OfflineInvestmentHolding> _$OfflineInvestmentHoldingFromFirestore(
  Map<String, dynamic> data, {
  Object? provider,
  ModelRepository<SqliteModel>? repository,
}) async {
  return OfflineInvestmentHolding(
    id: data['id'] as String,
    userId: data['user_id'] as String,
    symbol: data['symbol'] as String,
    assetClass: data['asset_class'] as String,
    quantity: data['quantity'].toString(),
    averageCost: data['average_cost'].toString(),
    currentPrice: data['current_price'].toString(),
    currency: data['currency'] as String,
    marketValue: data['market_value'].toString(),
    targetAllocationPercent: data['target_allocation_percent'] == null
        ? null
        : (data['target_allocation_percent'] as num?)?.toDouble(),
    createdAt: data['created_at'] == null
        ? null
        : data['created_at'] == null
        ? null
        : DateTime.tryParse(data['created_at'] as String),
    updatedAt: data['updated_at'] == null
        ? null
        : DateTime.tryParse(data['updated_at'] as String),
    version: data['version'] as int? ?? 1,
  );
}

Future<Map<String, dynamic>> _$OfflineInvestmentHoldingToFirestore(
  OfflineInvestmentHolding instance, {
  Object? provider,
  ModelRepository<SqliteModel>? repository,
}) async {
  return {
    'id': instance.id,
    'user_id': instance.userId,
    'symbol': instance.symbol,
    'asset_class': instance.assetClass,
    'quantity': instance.quantity,
    'average_cost': instance.averageCost,
    'current_price': instance.currentPrice,
    'currency': instance.currency,
    'market_value': instance.marketValue,
    'target_allocation_percent': instance.targetAllocationPercent,
    'created_at': instance.createdAt?.toIso8601String(),
    'updated_at': instance.updatedAt.toIso8601String(),
    'version': instance.version,
  };
}

Future<OfflineInvestmentHolding> _$OfflineInvestmentHoldingFromSqlite(
  Map<String, dynamic> data, {
  required SqliteProvider provider,
  ModelRepository<SqliteModel>? repository,
}) async {
  return OfflineInvestmentHolding(
    id: data['id'] as String,
    userId: data['user_id'] as String,
    symbol: data['symbol'] as String,
    assetClass: data['asset_class'] as String,
    quantity: data['quantity'] as String,
    averageCost: data['average_cost'] as String,
    currentPrice: data['current_price'] as String,
    currency: data['currency'] as String,
    marketValue: data['market_value'] as String,
    targetAllocationPercent: data['target_allocation_percent'] == null
        ? null
        : data['target_allocation_percent'] as double?,
    createdAt: data['created_at'] == null
        ? null
        : data['created_at'] == null
        ? null
        : DateTime.tryParse(data['created_at'] as String),
    updatedAt: DateTime.parse(data['updated_at'] as String),
    version: data['version'] as int,
  )..primaryKey = data['_brick_id'] as int;
}

Future<Map<String, dynamic>> _$OfflineInvestmentHoldingToSqlite(
  OfflineInvestmentHolding instance, {
  required SqliteProvider provider,
  ModelRepository<SqliteModel>? repository,
}) async {
  return {
    'id': instance.id,
    'user_id': instance.userId,
    'symbol': instance.symbol,
    'asset_class': instance.assetClass,
    'quantity': instance.quantity,
    'average_cost': instance.averageCost,
    'current_price': instance.currentPrice,
    'currency': instance.currency,
    'market_value': instance.marketValue,
    'target_allocation_percent': instance.targetAllocationPercent,
    'created_at': instance.createdAt?.toIso8601String(),
    'updated_at': instance.updatedAt.toIso8601String(),
    'version': instance.version,
  };
}

/// Construct a [OfflineInvestmentHolding]
class OfflineInvestmentHoldingAdapter
    extends FirestoreAdapter<OfflineInvestmentHolding> {
  OfflineInvestmentHoldingAdapter();

  @override
  final collectionName = 'investment_holdings';
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
    'symbol': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'symbol',
      iterable: false,
      type: String,
    ),
    'assetClass': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'asset_class',
      iterable: false,
      type: String,
    ),
    'quantity': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'quantity',
      iterable: false,
      type: String,
    ),
    'averageCost': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'average_cost',
      iterable: false,
      type: String,
    ),
    'currentPrice': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'current_price',
      iterable: false,
      type: String,
    ),
    'currency': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'currency',
      iterable: false,
      type: String,
    ),
    'marketValue': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'market_value',
      iterable: false,
      type: String,
    ),
    'targetAllocationPercent': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'target_allocation_percent',
      iterable: false,
      type: double,
    ),
    'createdAt': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'created_at',
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
    OfflineInvestmentHolding instance,
    DatabaseExecutor executor,
  ) async {
    final results = await executor.rawQuery(
      '''
        SELECT * FROM `OfflineInvestmentHolding` WHERE id = ? LIMIT 1''',
      [instance.id],
    );

    // SQFlite returns [{}] when no results are found
    if (results.isEmpty || (results.length == 1 && results.first.isEmpty)) {
      return null;
    }

    return results.first['_brick_id'] as int;
  }

  @override
  final String tableName = 'OfflineInvestmentHolding';

  @override
  Future<OfflineInvestmentHolding> fromFirestore(
    Map<String, dynamic> input, {
    provider,
    covariant ModelRepository<SqliteModel>? repository,
  }) async => await _$OfflineInvestmentHoldingFromFirestore(
    input,
    provider: provider,
    repository: repository,
  );
  @override
  Future<Map<String, dynamic>> toFirestore(
    OfflineInvestmentHolding input, {
    provider,
    covariant ModelRepository<SqliteModel>? repository,
  }) async => await _$OfflineInvestmentHoldingToFirestore(
    input,
    provider: provider,
    repository: repository,
  );
  @override
  Future<OfflineInvestmentHolding> fromSqlite(
    Map<String, dynamic> input, {
    required provider,
    covariant ModelRepository<SqliteModel>? repository,
  }) async => await _$OfflineInvestmentHoldingFromSqlite(
    input,
    provider: provider,
    repository: repository,
  );
  @override
  Future<Map<String, dynamic>> toSqlite(
    OfflineInvestmentHolding input, {
    required provider,
    covariant ModelRepository<SqliteModel>? repository,
  }) async => await _$OfflineInvestmentHoldingToSqlite(
    input,
    provider: provider,
    repository: repository,
  );
}
