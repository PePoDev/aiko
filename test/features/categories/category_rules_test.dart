import 'package:aiko/features/categories/application/category_service.dart';
import 'package:aiko/features/categories/domain/category.dart';
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
}
