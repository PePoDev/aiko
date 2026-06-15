import 'package:brick_offline_first_with_supabase/brick_offline_first_with_supabase.dart';
import 'package:brick_sqlite/brick_sqlite.dart';
import 'package:brick_supabase/brick_supabase.dart';

@ConnectOfflineFirstWithSupabase(
  supabaseConfig: SupabaseSerializable(tableName: 'category_groups'),
)
class OfflineCategoryGroup extends OfflineFirstWithSupabaseModel {
  OfflineCategoryGroup({
    required this.id,
    this.userId,
    required this.name,
    this.icon = 'category',
    this.color = '#3B82F6',
    this.sortOrder = 0,
    this.createdAt,
    DateTime? updatedAt,
    this.version = 1,
  }) : updatedAt = updatedAt ?? DateTime.now().toUtc();

  @Sqlite(unique: true)
  @Supabase(unique: true)
  final String id;

  // Nullable: system (default) groups live in Supabase with user_id = NULL
  // and are injected in-memory via CategoryDefaults. Per-user groups always
  // have a non-null userId. See AGENTS.md "System (default) categories".
  @Sqlite(index: true)
  final String? userId;

  final String name;
  final String icon;
  final String color;

  @Sqlite(name: 'sort_order')
  @Supabase(name: 'sort_order')
  final int sortOrder;

  @Sqlite(name: 'created_at')
  @Supabase(name: 'created_at')
  final DateTime? createdAt;

  @Sqlite(name: 'updated_at')
  @Supabase(name: 'updated_at')
  final DateTime updatedAt;

  @Sqlite(name: 'version')
  @Supabase(name: 'version', defaultValue: '1')
  final int version;
}
