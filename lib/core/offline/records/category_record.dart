import 'dart:convert';

import 'record_codec.dart';

class OfflineCategory implements OfflineRecord {
  OfflineCategory({
    required this.id,
    required this.userId,
    this.templateId,
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
    DateTime? updatedAt,
    this.version = 1,
  }) : updatedAt = updatedAt ?? DateTime.now().toUtc();

  @override
  final String id;

  final String userId;

  final String? templateId;

  final String name;
  final String type;

  /// Stored as `group` in the row.
  final String categoryGroup;

  final String? groupId;

  final String? parentId;
  final String icon;
  final String color;
  final bool budgetEnabled;
  final bool isActive;

  final DateTime? createdAt;

  // --- Budget fields (merged from the old `budgets` table) -----------------
  // `budgetAmount` and `budgetCurrency` form a Money pair: a null amount (or
  // a null currency) means the category has no budget. `budgetPeriod` is a
  // string discriminator (one of: daily, weekly, monthly, yearly).
  final String? budgetAmount;

  final String? budgetCurrency;

  final String budgetPeriod;

  final bool budgetRollover;

  final List<int> alertThresholds;

  final DateTime updatedAt;

  final int version;

  @override
  String? get ownerId => userId;
}

/// Reads `budget_period`, defaulting missing values to 'monthly'.
String budgetPeriodFromColumn(Object? raw) => raw is String ? raw : 'monthly';

/// Reads `alert_thresholds` from either a JSON string or a list, defaulting
/// missing values to the standard thresholds.
List<int> alertThresholdsFromColumn(Object? raw) {
  if (raw is String && raw.isNotEmpty) {
    return (jsonDecode(raw) as List).cast<int>();
  }
  if (raw is List) return raw.cast<int>();
  return const [50, 75, 90, 100];
}

class CategoryCodec extends RecordCodec<OfflineCategory> {
  const CategoryCodec();

  @override
  String get collection => 'categories';

  @override
  OfflineCategory fromRow(Map<String, dynamic> row) => OfflineCategory(
    id: row['id'] as String,
    userId: row['user_id'] as String,
    templateId: row['template_id'] as String?,
    name: row['name'] as String,
    type: row['type'] as String,
    categoryGroup: row['group'] as String,
    groupId: row['group_id'] as String?,
    parentId: row['parent_id'] as String?,
    icon: row['icon'] as String,
    color: row['color'] as String,
    budgetEnabled: row['budget_enabled'] as bool,
    isActive: row['is_active'] as bool,
    createdAt: dateFromRow(row['created_at']),
    budgetAmount: row['budget_amount']?.toString(),
    budgetCurrency: row['budget_currency'] as String?,
    budgetPeriod: budgetPeriodFromColumn(row['budget_period']),
    budgetRollover: row['budget_rollover'] as bool,
    alertThresholds: alertThresholdsFromColumn(row['alert_thresholds']),
    updatedAt: dateFromRow(row['updated_at']),
    version: row['version'] as int? ?? 1,
  );

  @override
  Map<String, dynamic> toRow(OfflineCategory record) => {
    'id': record.id,
    'user_id': record.userId,
    'template_id': record.templateId,
    'name': record.name,
    'type': record.type,
    'group': record.categoryGroup,
    'group_id': record.groupId,
    'parent_id': record.parentId,
    'icon': record.icon,
    'color': record.color,
    'budget_enabled': record.budgetEnabled,
    'is_active': record.isActive,
    'created_at': record.createdAt?.toIso8601String(),
    'budget_amount': record.budgetAmount,
    'budget_currency': record.budgetCurrency,
    'budget_period': record.budgetPeriod,
    'budget_rollover': record.budgetRollover,
    'alert_thresholds': record.alertThresholds,
    'updated_at': record.updatedAt.toIso8601String(),
    'version': record.version,
  };
}
