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
    this.templateId,
    required this.name,
    this.icon = 'category',
    this.color = '#3B82F6',
    this.sortOrder = 0,
    this.createdAt,
    this.budgetAmount,
    this.budgetCurrency,
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

  @Sqlite(name: 'template_id')
  @Supabase(name: 'template_id')
  final String? templateId;

  final String name;
  final String icon;
  final String color;

  @Sqlite(name: 'sort_order')
  @Supabase(name: 'sort_order')
  final int sortOrder;

  @Sqlite(name: 'created_at')
  @Supabase(name: 'created_at')
  final DateTime? createdAt;

  // Optional group-level budget. `budgetAmount`/`budgetCurrency` form a Money
  // pair (null amount or currency == no budget), mirroring OfflineCategory.
  // Tolerates legacy NULL rows (columns added after the table existed).
  @Sqlite(name: 'budget_amount')
  @Supabase(
    name: 'budget_amount',
    fromGenerator:
        'data[\'budget_amount\'] == null ? null : data[\'budget_amount\'].toString()',
  )
  final String? budgetAmount;

  @Sqlite(name: 'budget_currency')
  @Supabase(name: 'budget_currency')
  final String? budgetCurrency;

  @Sqlite(name: 'updated_at')
  @Supabase(name: 'updated_at')
  final DateTime updatedAt;

  @Sqlite(name: 'version')
  @Supabase(name: 'version', defaultValue: '1')
  final int version;
}
