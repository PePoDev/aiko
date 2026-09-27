import 'package:brick_sqlite/brick_sqlite.dart';

class OfflineInvestmentHolding extends SqliteModel {
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

  @Sqlite(unique: true)
  final String id;

  @Sqlite(index: true)
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

  // `updatedAt` is set to `now()` whenever a row is upserted; the
  // domain-level `updatedAt` (separate from this column) is the original
  // record timestamp surfaced on the domain model.
  @Sqlite(name: 'updated_at')
  final DateTime updatedAt;

  @Sqlite(name: 'version')
  final int version;
}
