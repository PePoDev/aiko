import 'package:decimal/decimal.dart';

import '../../../core/money/money.dart';
import 'category_defaults.dart';

enum CategoryType {
  income,
  expense,
  transfer,
  finance,
  tax,
  investment,
  adjustment,
}

/// Built-in spending classification used by the 50/30/20 budgeting templates.
/// This is a fixed taxonomy and is distinct from user-defined [CategoryGroup]s.
enum CategoryBudgetGroup {
  needs,
  wants,
  savings,
  debt,
  investment,
  tax,
  business,
  custom,
}

/// Recurrence period used for a [Category]'s budget limit. Stored on the
/// [Category] itself (the merge of Budgets → Categories moved these from the
/// former `budgets` table). One budget per category is supported.
enum CategoryBudgetPeriod { daily, weekly, monthly, yearly }

/// Sentinel used so [Category.copyWith] can distinguish "leave unchanged" from
/// "explicitly set to null" for nullable fields such as [Category.groupId].
const Object _unset = Object();

class Category {
  const Category({
    required this.id,
    required this.userId,
    this.templateId,
    required this.name,
    required this.type,
    required this.group,
    this.groupId,
    this.parentId,
    this.icon = 'category',
    this.color = '#3B82F6',
    this.budgetEnabled = true,
    this.isActive = true,
    this.createdAt,
    this.monthlyLimit,
    this.budgetPeriod = CategoryBudgetPeriod.monthly,
    this.rolloverUnused = false,
    this.alertThresholds = defaultAlertThresholds,
  });

  static const defaultAlertThresholds = <int>[50, 75, 90, 100];

  final String id;
  final String userId;
  final String? templateId;
  final String name;
  final CategoryType type;
  final CategoryBudgetGroup group;

  /// Id of the [CategoryGroup] this category belongs to, or null when the
  /// category is an unfiled custom category. Built-in/default categories each
  /// point at one of the 13 global default groups
  /// ([CategoryGroupDefaults.systemIds]).
  final String? groupId;
  final String? parentId;
  final String icon;
  final String color;
  final bool budgetEnabled;
  final bool isActive;
  final DateTime? createdAt;

  /// Base-currency spending limit for the period. Null means the category
  /// has no budget. The amount is interpreted in [monthlyLimit]!.currency and
  /// is converted to the user's base currency when displayed if needed.
  final Money? monthlyLimit;

  /// Period over which [monthlyLimit] applies. Always set, defaults to
  /// monthly. The display name is intentionally `monthlyLimit` for backward
  /// compatibility with the prior Budget field even when the period is
  /// weekly / yearly.
  final CategoryBudgetPeriod budgetPeriod;

  /// When true, unused budget carries forward to the next period only
  /// (one period rollover; the plan user chose). Default false.
  final bool rolloverUnused;

  /// Percent thresholds (0..100) at which to surface a budget alert. Default
  /// 50, 75, 90, 100. Per category.
  final List<int> alertThresholds;

  String? get effectiveTemplateId =>
      templateId ?? (CategoryDefaults.allIds.contains(id) ? id : null);

  bool get isDefault => effectiveTemplateId != null;

  /// True when this category has a usable budget configured (limit > 0 and
  /// [budgetEnabled]).
  bool get hasBudget =>
      budgetEnabled &&
      monthlyLimit != null &&
      monthlyLimit!.amount > Decimal.zero;

  Category copyWith({
    String? id,
    String? userId,
    Object? templateId = _unset,
    String? name,
    CategoryType? type,
    CategoryBudgetGroup? group,
    Object? groupId = _unset,
    String? parentId,
    String? icon,
    String? color,
    bool? budgetEnabled,
    bool? isActive,
    DateTime? createdAt,
    Object? monthlyLimit = _unset,
    CategoryBudgetPeriod? budgetPeriod,
    bool? rolloverUnused,
    List<int>? alertThresholds,
  }) {
    return Category(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      templateId: identical(templateId, _unset)
          ? this.templateId
          : templateId as String?,
      name: name ?? this.name,
      type: type ?? this.type,
      group: group ?? this.group,
      groupId: identical(groupId, _unset) ? this.groupId : groupId as String?,
      parentId: parentId ?? this.parentId,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      budgetEnabled: budgetEnabled ?? this.budgetEnabled,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      monthlyLimit: identical(monthlyLimit, _unset)
          ? this.monthlyLimit
          : monthlyLimit as Money?,
      budgetPeriod: budgetPeriod ?? this.budgetPeriod,
      rolloverUnused: rolloverUnused ?? this.rolloverUnused,
      alertThresholds: alertThresholds ?? this.alertThresholds,
    );
  }
}

/// A group that bundles related categories together (e.g. "Food & Drink",
/// "Household", "Kids"). Groups are purely organisational — they section the
/// Categories screen and do not affect budgeting math. Most groups are
/// user-defined and owned by a single user; the 13 global read-only defaults
/// (Food & Drink, Transport, …, Other) live in [CategoryGroupDefaults.all]
/// and are injected in-memory at the provider layer.
class CategoryGroup {
  const CategoryGroup({
    required this.id,
    required this.userId,
    this.templateId,
    required this.name,
    this.icon = 'category',
    this.color = '#3B82F6',
    this.sortOrder = 0,
    this.createdAt,
    this.budgetLimit,
  });

  final String id;
  final String userId;
  final String? templateId;
  final String name;
  final String icon;
  final String color;
  final int sortOrder;
  final DateTime? createdAt;

  /// Optional monthly spending limit for the whole group (an envelope across
  /// its categories), independent of the categories' own limits. Null means
  /// the group has no budget. For the 13 read-only default groups this rides
  /// on a per-user overlay row (see CategoryGroupsNotifier).
  final Money? budgetLimit;

  /// Whether this is one of the global, read-only default groups (Food &
  /// Drink, Transport, …, Other). System groups cannot be edited, deleted, or
  /// chosen as a target when assigning a category to a group.
  String? get effectiveTemplateId =>
      templateId ?? (CategoryGroupDefaults.systemIds.contains(id) ? id : null);

  bool get isDefault => effectiveTemplateId != null;

  bool get isSystem => isDefault;

  CategoryGroup copyWith({
    String? id,
    String? userId,
    Object? templateId = _unset,
    String? name,
    String? icon,
    String? color,
    int? sortOrder,
    DateTime? createdAt,
    Object? budgetLimit = _unset,
  }) {
    return CategoryGroup(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      templateId: identical(templateId, _unset)
          ? this.templateId
          : templateId as String?,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      budgetLimit: identical(budgetLimit, _unset)
          ? this.budgetLimit
          : budgetLimit as Money?,
    );
  }
}
