import 'package:brick_offline_first_with_supabase/brick_offline_first_with_supabase.dart';
import 'package:brick_sqlite/brick_sqlite.dart';
import 'package:brick_supabase/brick_supabase.dart';

@ConnectOfflineFirstWithSupabase(
  supabaseConfig: SupabaseSerializable(tableName: 'budgets'),
)
class OfflineBudget extends OfflineFirstWithSupabaseModel {
  OfflineBudget({
    required this.id,
    required this.userId,
    required this.name,
    required this.categoryId,
    required this.amount,
    required this.currency,
    required this.periodStart,
    required this.periodEnd,
    this.period = 'monthly',
    this.alertThresholds = const [50, 75, 90, 100],
    this.status = 'active',
    this.includedCategoryIds = const [],
    this.isAppDefined = false,
  });

  @Sqlite(unique: true)
  @Supabase(unique: true)
  final String id;

  @Sqlite(index: true)
  final String userId;

  final String name;
  final String categoryId;

  @Supabase(fromGenerator: 'data[\'amount\'].toString()')
  final String amount;

  final String currency;

  @Supabase(
    toGenerator: 'instance.periodStart.toIso8601String().substring(0, 10)',
  )
  final DateTime periodStart;

  @Supabase(
    toGenerator: 'instance.periodEnd.toIso8601String().substring(0, 10)',
  )
  final DateTime periodEnd;

  final String period;
  final List<int> alertThresholds;
  final String status;
  final List<String> includedCategoryIds;
  final bool isAppDefined;
}
