import 'package:brick_offline_first_with_supabase/brick_offline_first_with_supabase.dart';
import 'package:brick_sqlite/brick_sqlite.dart';
import 'package:brick_supabase/brick_supabase.dart';

@ConnectOfflineFirstWithSupabase(
  supabaseConfig: SupabaseSerializable(tableName: 'categories'),
)
class OfflineCategory extends OfflineFirstWithSupabaseModel {
  OfflineCategory({
    required this.id,
    required this.userId,
    required this.name,
    required this.type,
    required this.categoryGroup,
    this.parentId,
    this.icon = 'category',
    this.color = '#3B82F6',
    this.budgetEnabled = true,
    this.isActive = true,
  });

  @Sqlite(unique: true)
  @Supabase(unique: true)
  final String id;

  @Sqlite(index: true)
  final String userId;

  final String name;
  final String type;

  @Sqlite(name: 'category_group')
  @Supabase(name: 'group')
  final String categoryGroup;

  final String? parentId;
  final String icon;
  final String color;
  final bool budgetEnabled;
  final bool isActive;
}
