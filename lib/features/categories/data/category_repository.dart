import '../../../core/supabase/supabase_client_provider.dart';
import '../domain/category.dart';

class CategoryRepository {
  const CategoryRepository();

  Future<List<Category>> list() async {
    final session = AikoSupabase.requireSession();
    final response = await session.client
        .from('categories')
        .select()
        .eq('user_id', session.userId)
        .order('name');

    return response
        .map((row) => _fromRow(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  Future<Category> save(Category category) async {
    final currentList = await list();
    final duplicate = currentList.any(
      (item) =>
          item.id != category.id &&
          item.parentId == category.parentId &&
          item.name.toLowerCase() == category.name.toLowerCase(),
    );
    if (duplicate) {
      throw ArgumentError('Category name already exists.');
    }

    final session = AikoSupabase.requireSession();
    final categoryWithUser = Category(
      id: category.id,
      userId: session.userId,
      name: category.name,
      type: category.type,
      group: category.group,
      parentId: category.parentId,
      icon: category.icon,
      color: category.color,
      budgetEnabled: category.budgetEnabled,
      isActive: category.isActive,
    );

    await session.client.from('categories').upsert(_toRow(categoryWithUser));
    return categoryWithUser;
  }

  static Category _fromRow(Map<String, dynamic> row) {
    final type = CategoryType.values.firstWhere(
      (item) => item.name == row['type'],
      orElse: () => CategoryType.expense,
    );
    final group = CategoryGroup.values.firstWhere(
      (item) => item.name == (row['group'] as String? ?? 'custom'),
      orElse: () => CategoryGroup.custom,
    );

    return Category(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      name: row['name'] as String,
      type: type,
      group: group,
      parentId: row['parent_id'] as String?,
      icon: row['icon'] as String? ?? 'category',
      color: row['color'] as String? ?? '#3B82F6',
      budgetEnabled: row['budget_enabled'] as bool? ?? true,
      isActive: row['is_active'] as bool? ?? true,
    );
  }

  static Map<String, dynamic> _toRow(Category category) {
    return {
      'id': category.id,
      'user_id': category.userId,
      'name': category.name,
      'parent_id': category.parentId,
      'type': category.type.name,
      'group': category.group.name,
      'icon': category.icon,
      'color': category.color,
      'budget_enabled': category.budgetEnabled,
      'is_active': category.isActive,
    };
  }
}
