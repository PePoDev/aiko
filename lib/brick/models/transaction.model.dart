import 'package:brick_offline_first_with_supabase/brick_offline_first_with_supabase.dart';
import 'package:brick_sqlite/brick_sqlite.dart';
import 'package:brick_supabase/brick_supabase.dart';

@ConnectOfflineFirstWithSupabase(
  supabaseConfig: SupabaseSerializable(tableName: 'transactions'),
)
class OfflineTransaction extends OfflineFirstWithSupabaseModel {
  OfflineTransaction({
    required this.id,
    required this.userId,
    required this.accountId,
    required this.type,
    required this.amount,
    required this.currency,
    required this.date,
    this.categoryId,
    this.merchant,
    this.note,
    this.tags = const [],
    this.status = 'posted',
  });

  @Sqlite(unique: true)
  @Supabase(unique: true)
  final String id;

  @Sqlite(index: true)
  final String userId;

  @Sqlite(index: true)
  final String accountId;

  final String type;

  @Supabase(fromGenerator: 'data[\'amount\'].toString()')
  final String amount;

  final String currency;

  final DateTime date;

  final String? categoryId;
  final String? merchant;
  final String? note;
  final List<String> tags;
  final String status;
}
