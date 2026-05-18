enum CategoryType {
  income,
  expense,
  transfer,
  finance,
  tax,
  investment,
  adjustment,
}

enum CategoryGroup {
  needs,
  wants,
  savings,
  debt,
  investment,
  tax,
  business,
  custom,
}

class Category {
  const Category({
    required this.id,
    required this.userId,
    required this.name,
    required this.type,
    required this.group,
    this.parentId,
    this.icon = 'category',
    this.color = '#3B82F6',
    this.budgetEnabled = true,
    this.isActive = true,
  });

  final String id;
  final String userId;
  final String name;
  final CategoryType type;
  final CategoryGroup group;
  final String? parentId;
  final String icon;
  final String color;
  final bool budgetEnabled;
  final bool isActive;

  Category copyWith({String? name, bool? isActive}) {
    return Category(
      id: id,
      userId: userId,
      name: name ?? this.name,
      type: type,
      group: group,
      parentId: parentId,
      icon: icon,
      color: color,
      budgetEnabled: budgetEnabled,
      isActive: isActive ?? this.isActive,
    );
  }
}
