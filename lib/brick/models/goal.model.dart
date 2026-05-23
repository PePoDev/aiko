import 'package:brick_offline_first_with_supabase/brick_offline_first_with_supabase.dart';
import 'package:brick_sqlite/brick_sqlite.dart';
import 'package:brick_supabase/brick_supabase.dart';

@ConnectOfflineFirstWithSupabase(
  supabaseConfig: SupabaseSerializable(tableName: 'goals'),
)
class OfflineGoal extends OfflineFirstWithSupabaseModel {
  OfflineGoal({
    required this.id,
    required this.userId,
    required this.name,
    required this.purpose,
    required this.targetAmount,
    required this.currentAmount,
    required this.currency,
    required this.targetDate,
    this.linkedAccountId,
    this.priority = 1,
    this.successProbability,
    this.status = 'active',
  });

  @Sqlite(unique: true)
  @Supabase(unique: true)
  final String id;

  @Sqlite(index: true)
  final String userId;

  final String name;
  final String purpose;

  @Supabase(fromGenerator: 'data[\'target_amount\'].toString()')
  final String targetAmount;

  @Supabase(fromGenerator: 'data[\'current_amount\'].toString()')
  final String currentAmount;

  final String currency;

  @Supabase(
    toGenerator: 'instance.targetDate.toIso8601String().substring(0, 10)',
  )
  final DateTime targetDate;

  final String? linkedAccountId;
  final int priority;

  @Supabase(fromGenerator: "(data['success_probability'] as num?)?.toDouble()")
  final double? successProbability;

  final String status;
}
