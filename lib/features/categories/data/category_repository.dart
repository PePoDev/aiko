import '../domain/category.dart';

class CategoryRepository {
  CategoryRepository({List<Category>? categories})
    : _categories =
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
          ];

  final List<Category> _categories;

  Future<List<Category>> list() async => List.unmodifiable(_categories);

  Future<Category> save(Category category) async {
    final duplicate = _categories.any(
      (item) =>
          item.id != category.id &&
          item.parentId == category.parentId &&
          item.name.toLowerCase() == category.name.toLowerCase(),
    );
    if (duplicate) {
      throw ArgumentError('Category name already exists.');
    }
    final index = _categories.indexWhere((item) => item.id == category.id);
    if (index == -1) {
      _categories.add(category);
    } else {
      _categories[index] = category;
    }
    return category;
  }
}
