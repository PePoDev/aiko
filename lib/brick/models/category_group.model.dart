import 'package:brick_offline_first_with_supabase/brick_offline_first_with_supabase.dart';
import 'package:brick_sqlite/brick_sqlite.dart';
import 'package:brick_supabase/brick_supabase.dart';

@ConnectOfflineFirstWithSupabase(
  supabaseConfig: SupabaseSerializable(tableName: 'category_groups'),
)
class OfflineCategoryGroup extends OfflineFirstWithSupabaseModel {
  OfflineCategoryGroup({
    required this.id,
    required this.userId,
    required this.name,
    this.icon = 'category',
    this.color = '#3B82F6',
    this.sortOrder = 0,
    this.createdAt,
  });

  @Sqlite(unique: true)
  @Supabase(unique: true)
  final String id;

  @Sqlite(index: true)
  final String userId;

  final String name;
  final String icon;
  final String color;

  @Sqlite(name: 'sort_order')
  @Supabase(name: 'sort_order')
  final int sortOrder;

  @Sqlite(name: 'created_at')
  @Supabase(name: 'created_at')
  final DateTime? createdAt;
}
