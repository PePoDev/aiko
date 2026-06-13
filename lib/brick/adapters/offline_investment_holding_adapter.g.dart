// GENERATED CODE DO NOT EDIT
part of '../brick.g.dart';

Future<OfflineInvestmentHolding> _$OfflineInvestmentHoldingFromSupabase(
  Map<String, dynamic> data, {
  required SupabaseProvider provider,
  OfflineFirstWithSupabaseRepository? repository,
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
        : data['updated_at'] == null
        ? null
        : DateTime.tryParse(data['updated_at'] as String),
  );
}

Future<Map<String, dynamic>> _$OfflineInvestmentHoldingToSupabase(
  OfflineInvestmentHolding instance, {
  required SupabaseProvider provider,
  OfflineFirstWithSupabaseRepository? repository,
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
    'updated_at': instance.updatedAt?.toIso8601String(),
  };
}

Future<OfflineInvestmentHolding> _$OfflineInvestmentHoldingFromSqlite(
  Map<String, dynamic> data, {
  required SqliteProvider provider,
  OfflineFirstWithSupabaseRepository? repository,
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
    updatedAt: data['updated_at'] == null
        ? null
        : data['updated_at'] == null
        ? null
        : DateTime.tryParse(data['updated_at'] as String),
  )..primaryKey = data['_brick_id'] as int;
}

Future<Map<String, dynamic>> _$OfflineInvestmentHoldingToSqlite(
  OfflineInvestmentHolding instance, {
  required SqliteProvider provider,
  OfflineFirstWithSupabaseRepository? repository,
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
    'updated_at': instance.updatedAt?.toIso8601String(),
  };
}

/// Construct a [OfflineInvestmentHolding]
class OfflineInvestmentHoldingAdapter
    extends OfflineFirstWithSupabaseAdapter<OfflineInvestmentHolding> {
  OfflineInvestmentHoldingAdapter();

  @override
  final supabaseTableName = 'investment_holdings';
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
    'symbol': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'symbol',
    ),
    'assetClass': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'asset_class',
    ),
    'quantity': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'quantity',
    ),
    'averageCost': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'average_cost',
    ),
    'currentPrice': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'current_price',
    ),
    'currency': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'currency',
    ),
    'marketValue': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'market_value',
    ),
    'targetAllocationPercent': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'target_allocation_percent',
    ),
    'createdAt': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'created_at',
    ),
    'updatedAt': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'updated_at',
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
  Future<OfflineInvestmentHolding> fromSupabase(
    Map<String, dynamic> input, {
    required provider,
    covariant OfflineFirstWithSupabaseRepository? repository,
  }) async => await _$OfflineInvestmentHoldingFromSupabase(
    input,
    provider: provider,
    repository: repository,
  );
  @override
  Future<Map<String, dynamic>> toSupabase(
    OfflineInvestmentHolding input, {
    required provider,
    covariant OfflineFirstWithSupabaseRepository? repository,
  }) async => await _$OfflineInvestmentHoldingToSupabase(
    input,
    provider: provider,
    repository: repository,
  );
  @override
  Future<OfflineInvestmentHolding> fromSqlite(
    Map<String, dynamic> input, {
    required provider,
    covariant OfflineFirstWithSupabaseRepository? repository,
  }) async => await _$OfflineInvestmentHoldingFromSqlite(
    input,
    provider: provider,
    repository: repository,
  );
  @override
  Future<Map<String, dynamic>> toSqlite(
    OfflineInvestmentHolding input, {
    required provider,
    covariant OfflineFirstWithSupabaseRepository? repository,
  }) async => await _$OfflineInvestmentHoldingToSqlite(
    input,
    provider: provider,
    repository: repository,
  );
}
