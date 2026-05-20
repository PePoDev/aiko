import 'dart:developer' as developer;

import '../../../core/supabase/supabase_client_provider.dart';
import '../domain/category.dart';

class CategoryRepository {
  CategoryRepository({List<Category>? categories})
    : _categories = List.from(
        categories ??
            const [
              Category(
                id: 'food',
                userId: 'demo-user',
                name: 'Food and Dining',
                type: CategoryType.expense,
                group: CategoryGroup.needs,
              ),
              Category(
                id: 'salary',
                userId: 'demo-user',
                name: 'Salary',
                type: CategoryType.income,
                group: CategoryGroup.custom,
              ),
            ],
      );

  final List<Category> _categories;

  Future<List<Category>> list() async {
    final client = AikoSupabase.tryClient();
    final user = client?.auth.currentUser;
    if (client != null && user != null) {
      try {
        final response = await client
            .from('categories')
            .select()
            .eq('user_id', user.id);
        return (response as List).map((row) => _fromRow(row)).toList();
      } catch (e) {
        // Fallback on error
      }
    }
    return List.unmodifiable(_categories);
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

    final client = AikoSupabase.tryClient();
    final user = client?.auth.currentUser;
    if (client != null && user != null) {
      try {
        final catWithUser = Category(
          id: category.id,
          userId: user.id,
          name: category.name,
          type: category.type,
          group: category.group,
          parentId: category.parentId,
          icon: category.icon,
          color: category.color,
          budgetEnabled: category.budgetEnabled,
          isActive: category.isActive,
        );
        await client.from('categories').upsert(_toRow(catWithUser));

        final index = _categories.indexWhere(
          (item) => item.id == catWithUser.id,
        );
        if (index == -1) {
          _categories.add(catWithUser);
        } else {
          _categories[index] = catWithUser;
        }
        return catWithUser;
      } catch (e, stackTrace) {
        developer.log(
          'CategoryRepository.save error',
          error: e,
          stackTrace: stackTrace,
        );
      }
    }

    final index = _categories.indexWhere((item) => item.id == category.id);
    if (index == -1) {
      _categories.add(category);
    } else {
      _categories[index] = category;
    }
    return category;
  }

  static Category _fromRow(Map<String, dynamic> row) {
    final typeStr = row['type'] as String;
    final type = CategoryType.values.firstWhere(
      (e) => e.name == typeStr,
      orElse: () => CategoryType.expense,
    );

    final groupStr = row['group'] as String? ?? 'custom';
    final group = CategoryGroup.values.firstWhere(
      (e) => e.name == groupStr,
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
