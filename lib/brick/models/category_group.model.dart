import 'package:brick_sqlite/brick_sqlite.dart';

class OfflineCategoryGroup extends SqliteModel {
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
  final String id;

  // Nullable: system (default) groups live in Firestore with user_id = NULL
  // and are injected in-memory via CategoryDefaults. Per-user groups always
  // have a non-null userId. See AGENTS.md "System (default) categories".
  @Sqlite(index: true)
  final String? userId;

  @Sqlite(name: 'template_id')
  final String? templateId;

  final String name;
  final String icon;
  final String color;

  @Sqlite(name: 'sort_order')
  final int sortOrder;

  @Sqlite(name: 'created_at')
  final DateTime? createdAt;

  // Optional group-level budget. `budgetAmount`/`budgetCurrency` form a Money
  // pair (null amount or currency == no budget), mirroring OfflineCategory.
  // Tolerates legacy NULL rows (columns added after the table existed).
  @Sqlite(name: 'budget_amount')
  final String? budgetAmount;

  @Sqlite(name: 'budget_currency')
  final String? budgetCurrency;

  @Sqlite(name: 'updated_at')
  final DateTime updatedAt;

  @Sqlite(name: 'version')
  final int version;
}
