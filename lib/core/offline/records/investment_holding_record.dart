import 'record_codec.dart';

class OfflineInvestmentHolding implements OfflineRecord {
  OfflineInvestmentHolding({
    required this.id,
    required this.userId,
    required this.symbol,
    required this.assetClass,
    required this.quantity,
    required this.averageCost,
    required this.currentPrice,
    required this.currency,
    required this.marketValue,
    this.targetAllocationPercent,
    this.createdAt,
    DateTime? updatedAt,
    this.version = 1,
  }) : updatedAt = updatedAt ?? DateTime.now().toUtc();

  @override
  final String id;

  final String userId;

  final String symbol;
  final String assetClass;

  final String quantity;

  final String averageCost;

  final String currentPrice;

  final String currency;

  final String marketValue;

  final double? targetAllocationPercent;

  final DateTime? createdAt;

  // Unlike the other records, the holding's own `updatedAt` round-trips
  // through the domain model (it is shown to the user).
  final DateTime updatedAt;

  final int version;

  @override
  String? get ownerId => userId;
}

class InvestmentHoldingCodec extends RecordCodec<OfflineInvestmentHolding> {
  const InvestmentHoldingCodec();

  @override
  String get collection => 'investment_holdings';

  @override
  OfflineInvestmentHolding fromRow(Map<String, dynamic> row) =>
      OfflineInvestmentHolding(
        id: row['id'] as String,
        userId: row['user_id'] as String,
        symbol: row['symbol'] as String,
        assetClass: row['asset_class'] as String,
        quantity: row['quantity'].toString(),
        averageCost: row['average_cost'].toString(),
        currentPrice: row['current_price'].toString(),
        currency: row['currency'] as String,
        marketValue: row['market_value'].toString(),
        targetAllocationPercent: (row['target_allocation_percent'] as num?)
            ?.toDouble(),
        createdAt: dateFromRow(row['created_at']),
        updatedAt: dateFromRow(row['updated_at']),
        version: row['version'] as int? ?? 1,
      );

  @override
  Map<String, dynamic> toRow(OfflineInvestmentHolding record) => {
    'id': record.id,
    'user_id': record.userId,
    'symbol': record.symbol,
    'asset_class': record.assetClass,
    'quantity': record.quantity,
    'average_cost': record.averageCost,
    'current_price': record.currentPrice,
    'currency': record.currency,
    'market_value': record.marketValue,
    'target_allocation_percent': record.targetAllocationPercent,
    'created_at': record.createdAt?.toIso8601String(),
    'updated_at': record.updatedAt.toIso8601String(),
    'version': record.version,
  };
}
