import 'package:brick_offline_first_with_supabase/brick_offline_first_with_supabase.dart';
import 'package:brick_sqlite/brick_sqlite.dart';
import 'package:brick_supabase/brick_supabase.dart';

@ConnectOfflineFirstWithSupabase(
  supabaseConfig: SupabaseSerializable(tableName: 'investment_holdings'),
)
class OfflineInvestmentHolding extends OfflineFirstWithSupabaseModel {
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
    this.deletedAt,
    this.version = 1,
  }) : updatedAt = updatedAt ?? DateTime.now().toUtc();

  @Sqlite(unique: true)
  @Supabase(unique: true)
  final String id;

  @Sqlite(index: true)
  final String userId;

  final String symbol;
  final String assetClass;

  @Supabase(fromGenerator: "data['quantity'].toString()")
  final String quantity;

  @Supabase(fromGenerator: "data['average_cost'].toString()")
  final String averageCost;

  @Supabase(fromGenerator: "data['current_price'].toString()")
  final String currentPrice;

  final String currency;

  @Supabase(fromGenerator: "data['market_value'].toString()")
  final String marketValue;

  @Supabase(
    fromGenerator: "(data['target_allocation_percent'] as num?)?.toDouble()",
  )
  final double? targetAllocationPercent;

  final DateTime? createdAt;

  // `updatedAt` is set to `now()` whenever a row is upserted; the
  // domain-level `updatedAt` (separate from this column) is the original
  // record timestamp surfaced on the domain model.
  @Sqlite(name: 'updated_at')
  @Supabase(name: 'updated_at')
  final DateTime updatedAt;

  @Sqlite(name: 'deleted_at', index: true)
  @Supabase(name: 'deleted_at')
  final DateTime? deletedAt;

  @Sqlite(name: 'version')
  @Supabase(name: 'version', defaultValue: '1')
  final int version;
}
