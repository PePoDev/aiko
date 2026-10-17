import 'record_codec.dart';

class OfflineCategoryGroup implements OfflineRecord {
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

  @override
  final String id;

  // Nullable: system (default) groups have user_id = NULL and are injected
  // in-memory via CategoryDefaults. Per-user groups always have a non-null
  // userId. See AGENTS.md "System (default) categories".
  final String? userId;

  final String? templateId;

  final String name;
  final String icon;
  final String color;

  final int sortOrder;

  final DateTime? createdAt;

  // Optional group-level budget. `budgetAmount`/`budgetCurrency` form a Money
  // pair (null amount or currency == no budget), mirroring OfflineCategory.
  final String? budgetAmount;

  final String? budgetCurrency;

  final DateTime updatedAt;

  final int version;

  @override
  String? get ownerId => userId;
}

class CategoryGroupCodec extends RecordCodec<OfflineCategoryGroup> {
  const CategoryGroupCodec();

  @override
  String get collection => 'category_groups';

  @override
  OfflineCategoryGroup fromRow(Map<String, dynamic> row) =>
      OfflineCategoryGroup(
        id: row['id'] as String,
        userId: row['user_id'] as String?,
        templateId: row['template_id'] as String?,
        name: row['name'] as String,
        icon: row['icon'] as String,
        color: row['color'] as String,
        sortOrder: row['sort_order'] as int,
        createdAt: dateFromRow(row['created_at']),
        budgetAmount: row['budget_amount']?.toString(),
        budgetCurrency: row['budget_currency'] as String?,
        updatedAt: dateFromRow(row['updated_at']),
        version: row['version'] as int? ?? 1,
      );

  @override
  Map<String, dynamic> toRow(OfflineCategoryGroup record) => {
    'id': record.id,
    'user_id': record.userId,
    'template_id': record.templateId,
    'name': record.name,
    'icon': record.icon,
    'color': record.color,
    'sort_order': record.sortOrder,
    'created_at': record.createdAt?.toIso8601String(),
    'budget_amount': record.budgetAmount,
    'budget_currency': record.budgetCurrency,
    'updated_at': record.updatedAt.toIso8601String(),
    'version': record.version,
  };
}
