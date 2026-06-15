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
    this.groupId,
    this.parentId,
    this.icon = 'category',
    this.color = '#3B82F6',
    this.budgetEnabled = true,
    this.isActive = true,
    this.createdAt,
    this.budgetAmount,
    this.budgetCurrency,
    this.budgetPeriod = 'monthly',
    this.budgetRollover = false,
    this.alertThresholds = const [50, 75, 90, 100],
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

  @Sqlite(name: 'group_id')
  @Supabase(name: 'group_id')
  final String? groupId;

  final String? parentId;
  final String icon;
  final String color;
  final bool budgetEnabled;
  final bool isActive;

  @Sqlite(name: 'created_at')
  @Supabase(name: 'created_at')
  final DateTime? createdAt;

  // --- Budget fields (merged from the old `budgets` table) -----------------
  // `budgetAmount` and `budgetCurrency` form a Money pair: a null amount (or
  // a null currency) means the category has no budget. `budgetPeriod` is a
  // string discriminator (one of: daily, weekly, monthly, yearly).
  @Sqlite(name: 'budget_amount')
  @Supabase(name: 'budget_amount', fromGenerator: 'data[\'budget_amount\'] == null ? null : data[\'budget_amount\'].toString()')
  final String? budgetAmount;

  @Sqlite(name: 'budget_currency')
  @Supabase(name: 'budget_currency')
  final String? budgetCurrency;

  @Sqlite(name: 'budget_period')
  @Supabase(name: 'budget_period')
  final String budgetPeriod;

  @Sqlite(name: 'budget_rollover')
  @Supabase(name: 'budget_rollover')
  final bool budgetRollover;

  @Sqlite(name: 'alert_thresholds')
  @Supabase(name: 'alert_thresholds')
  final List<int> alertThresholds;
}
