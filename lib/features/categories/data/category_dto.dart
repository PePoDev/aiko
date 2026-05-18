import '../domain/category.dart';

class CategoryDto {
  const CategoryDto(this.json);

  final Map<String, dynamic> json;

  Category toDomain() {
    return Category(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      type: CategoryType.values.byName(json['type'] as String? ?? 'expense'),
      group: CategoryGroup.values.byName(json['group'] as String? ?? 'custom'),
      parentId: json['parent_id'] as String?,
      icon: json['icon'] as String? ?? 'category',
      color: json['color'] as String? ?? '#3B82F6',
      budgetEnabled: json['budget_enabled'] as bool? ?? true,
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}
