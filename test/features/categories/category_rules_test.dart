import 'package:aiko/app/providers.dart';
import 'package:aiko/features/categories/application/category_service.dart';
import 'package:aiko/features/categories/data/category_repository.dart';
import 'package:aiko/features/categories/domain/category.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cannot merge categories with different types', () {
    const service = CategoryService();
    const expense = Category(
      id: 'food',
      userId: 'user',
      name: 'Food',
      type: CategoryType.expense,
      group: CategoryGroup.needs,
    );
    const income = Category(
      id: 'salary',
      userId: 'user',
      name: 'Salary',
      type: CategoryType.income,
      group: CategoryGroup.custom,
    );

    expect(() => service.mergeInto(expense, income), throwsArgumentError);
  });

  test('default categories include useful income and expense options', () {
    const service = CategoryService();

    final defaults = service.defaultCategoriesFor('user');
    final incomeNames = defaults
        .where((category) => category.type == CategoryType.income)
        .map((category) => category.name)
        .toSet();
    final expenseNames = defaults
        .where((category) => category.type == CategoryType.expense)
        .map((category) => category.name)
        .toSet();

    expect(incomeNames, containsAll(['Salary', 'Freelance', 'Dividends']));
    expect(expenseNames, containsAll(['Groceries', 'Rent', 'Subscriptions']));
  });

  test('default categories are app-defined by id', () {
    const service = CategoryService();

    final defaults = service.defaultCategoriesFor('user');
    final custom = const Category(
      id: 'custom-food',
      userId: 'user',
      name: 'Food',
      type: CategoryType.expense,
      group: CategoryGroup.wants,
    );

    expect(
      defaults,
      everyElement(predicate<Category>((category) => category.isDefault)),
    );
    expect(custom.isDefault, isFalse);
  });

  test('deleting a custom category hides matching generated default', () async {
    final repository = _InMemoryCategoryRepository([
      const Category(
        id: 'custom-coffee',
        userId: 'user',
        name: 'Coffee',
        type: CategoryType.expense,
        group: CategoryGroup.wants,
      ),
    ]);
    final container = ProviderContainer(
      overrides: [categoryRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    final initial = await container.read(categoriesProvider.future);
    expect(
      initial.where((category) => category.name == 'Coffee'),
      hasLength(1),
    );

    await container
        .read(categoriesProvider.notifier)
        .deleteCategory('custom-coffee');

    final updated = container.read(categoriesProvider).value!;
    expect(updated.where((category) => category.name == 'Coffee'), isEmpty);
    expect(repository.savedCategory?.isActive, isFalse);
  });

  test(
    'inactive custom category suppresses matching generated default',
    () async {
      final repository = _InMemoryCategoryRepository([
        const Category(
          id: 'custom-coffee',
          userId: 'user',
          name: 'Coffee',
          type: CategoryType.expense,
          group: CategoryGroup.wants,
          isActive: false,
        ),
      ]);
      final container = ProviderContainer(
        overrides: [categoryRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final categories = await container.read(categoriesProvider.future);

      expect(
        categories.where((category) => category.name == 'Coffee'),
        isEmpty,
      );
    },
  );

  test('categories keep default order and sort custom categories by creation', (
  ) async {
    final olderCustom = Category(
      id: 'custom-consulting',
      userId: 'user',
      name: 'Consulting',
      type: CategoryType.income,
      group: CategoryGroup.business,
      createdAt: DateTime(2026, 1, 1),
    );
    final newerCustom = Category(
      id: 'custom-royalties',
      userId: 'user',
      name: 'Royalties',
      type: CategoryType.income,
      group: CategoryGroup.investment,
      createdAt: DateTime(2026, 2, 1),
    );
    final repository = _InMemoryCategoryRepository([
      newerCustom,
      olderCustom,
    ]);
    final container = ProviderContainer(
      overrides: [categoryRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    final categories = await container.read(categoriesProvider.future);
    final income = categories
        .where((category) => category.type == CategoryType.income)
        .toList(growable: false);
    final incomeNames = income.map((category) => category.name).toList();

    expect(incomeNames.take(2), ['Salary', 'Bonus']);
    expect(
      income.indexWhere((category) => category.id == olderCustom.id),
      lessThan(income.indexWhere((category) => category.id == newerCustom.id)),
    );
    expect(
      income.lastIndexWhere((category) => category.isDefault),
      lessThan(income.indexWhere((category) => !category.isDefault)),
    );
  });
}

class _InMemoryCategoryRepository extends CategoryRepository {
  _InMemoryCategoryRepository(List<Category> categories)
    : _categories = [...categories];

  final List<Category> _categories;
  Category? savedCategory;

  @override
  Future<List<Category>> list() async => [..._categories];

  @override
  Future<Category> save(Category category) async {
    savedCategory = category;
    final index = _categories.indexWhere((item) => item.id == category.id);
    if (index == -1) {
      _categories.add(category);
    } else {
      _categories[index] = category;
    }
    return category;
  }

  @override
  Future<void> delete(String id) async {
    _categories.removeWhere((category) => category.id == id);
  }
}
