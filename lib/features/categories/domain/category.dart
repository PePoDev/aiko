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

/// Sentinel used so [Category.copyWith] can distinguish "leave unchanged" from
/// "explicitly set to null" for nullable fields such as [Category.groupId].
const Object _unset = Object();

class Category {
  const Category({
    required this.id,
    required this.userId,
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
  });

  final String id;
  final String userId;
  final String name;
  final CategoryType type;
  final CategoryBudgetGroup group;

  /// Id of the [CategoryGroup] this category belongs to, or null when the
  /// category is an unfiled custom category. Built-in/system categories belong
  /// to the global System group ([CategoryGroupDefaults.systemId]).
  final String? groupId;
  final String? parentId;
  final String icon;
  final String color;
  final bool budgetEnabled;
  final bool isActive;
  final DateTime? createdAt;

  bool get isDefault => CategoryDefaults.allIds.contains(id);

  Category copyWith({
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
  }) {
    return Category(
      id: id,
      userId: userId,
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
    );
  }
}

/// A group that bundles related categories together (e.g. "Household", "Car",
/// "Kids"). Groups are purely organisational — they section the Categories
/// screen and do not affect budgeting math. Most groups are user-defined and
/// owned by a single user; the one exception is the global, read-only System
/// group ([CategoryGroupDefaults.system]) that owns the built-in defaults.
class CategoryGroup {
  const CategoryGroup({
    required this.id,
    required this.userId,
    required this.name,
    this.icon = 'category',
    this.color = '#3B82F6',
    this.sortOrder = 0,
    this.createdAt,
  });

  final String id;
  final String userId;
  final String name;
  final String icon;
  final String color;
  final int sortOrder;
  final DateTime? createdAt;

  /// Whether this is the global, read-only System group that owns the built-in
  /// default categories. System groups cannot be edited, deleted, or chosen as
  /// a target when assigning a category to a group.
  bool get isSystem => id == CategoryGroupDefaults.systemId;

  CategoryGroup copyWith({
    String? name,
    String? icon,
    String? color,
    int? sortOrder,
    DateTime? createdAt,
  }) {
    return CategoryGroup(
      id: id,
      userId: userId,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
