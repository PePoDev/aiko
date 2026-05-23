import 'package:brick_offline_first_with_supabase/brick_offline_first_with_supabase.dart';
import 'package:brick_sqlite/brick_sqlite.dart';
import 'package:brick_supabase/brick_supabase.dart';

@ConnectOfflineFirstWithSupabase(
  supabaseConfig: SupabaseSerializable(tableName: 'accounts'),
)
class OfflineAccount extends OfflineFirstWithSupabaseModel {
  OfflineAccount({
    required this.id,
    required this.userId,
    required this.name,
    required this.type,
    required this.currency,
    required this.openingBalance,
    required this.currentBalance,
    this.institution,
    this.includeInNetWorth = true,
    this.isActive = true,
  });

  @Sqlite(unique: true)
  @Supabase(unique: true)
  final String id;

  @Sqlite(index: true)
  final String userId;

  final String name;
  final String type;
  final String currency;

  @Supabase(fromGenerator: 'data[\'opening_balance\'].toString()')
  final String openingBalance;

  @Supabase(fromGenerator: 'data[\'current_balance\'].toString()')
  final String currentBalance;

  final String? institution;
  final bool includeInNetWorth;
  final bool isActive;
}
