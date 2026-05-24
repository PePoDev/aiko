import '../domain/category.dart';

class CategoryService {
  const CategoryService();

  Category archive(Category category) => category.copyWith(isActive: false);

  List<Category> defaultCategoriesFor(String userId) {
    return [
      ..._defaultIncomeCategories(userId),
      ..._defaultExpenseCategories(userId),
    ];
  }

  Category mergeInto(Category source, Category target) {
    if (source.type != target.type) {
      throw ArgumentError('Cannot merge categories with different types.');
    }
    return source.copyWith(isActive: false);
  }

  List<Category> _defaultIncomeCategories(String userId) {
    return [
      _defaultCategory(
        userId: userId,
        id: 'default-income-salary',
        name: 'Salary',
        type: CategoryType.income,
        group: CategoryGroup.custom,
        icon: 'salary',
        color: '#22C55E',
      ),
      _defaultCategory(
        userId: userId,
        id: 'default-income-bonus',
        name: 'Bonus',
        type: CategoryType.income,
        group: CategoryGroup.custom,
        icon: 'gift',
        color: '#16A34A',
      ),
      _defaultCategory(
        userId: userId,
        id: 'default-income-freelance',
        name: 'Freelance',
        type: CategoryType.income,
        group: CategoryGroup.business,
        icon: 'work',
        color: '#14B8A6',
      ),
      _defaultCategory(
        userId: userId,
        id: 'default-income-business',
        name: 'Business income',
        type: CategoryType.income,
        group: CategoryGroup.business,
        icon: 'business',
        color: '#0EA5E9',
      ),
      _defaultCategory(
        userId: userId,
        id: 'default-income-interest',
        name: 'Interest',
        type: CategoryType.income,
        group: CategoryGroup.savings,
        icon: 'savings',
        color: '#06B6D4',
      ),
      _defaultCategory(
        userId: userId,
        id: 'default-income-dividends',
        name: 'Dividends',
        type: CategoryType.income,
        group: CategoryGroup.investment,
        icon: 'investment',
        color: '#8B5CF6',
      ),
      _defaultCategory(
        userId: userId,
        id: 'default-income-rental',
        name: 'Rental income',
        type: CategoryType.income,
        group: CategoryGroup.investment,
        icon: 'home',
        color: '#6366F1',
      ),
      _defaultCategory(
        userId: userId,
        id: 'default-income-refunds',
        name: 'Refunds',
        type: CategoryType.income,
        group: CategoryGroup.custom,
        icon: 'refund',
        color: '#10B981',
      ),
      _defaultCategory(
        userId: userId,
        id: 'default-income-gift',
        name: 'Gift',
        type: CategoryType.income,
        group: CategoryGroup.custom,
        icon: 'gift',
        color: '#EC4899',
      ),
      _defaultCategory(
        userId: userId,
        id: 'default-income-other',
        name: 'Other income',
        type: CategoryType.income,
        group: CategoryGroup.custom,
        icon: 'category',
        color: '#64748B',
      ),
    ];
  }

  List<Category> _defaultExpenseCategories(String userId) {
    return [
      _defaultCategory(
        userId: userId,
        id: 'default-expense-groceries',
        name: 'Groceries',
        type: CategoryType.expense,
        group: CategoryGroup.needs,
        icon: 'groceries',
        color: '#F97316',
      ),
      _defaultCategory(
        userId: userId,
        id: 'default-expense-dining',
        name: 'Dining',
        type: CategoryType.expense,
        group: CategoryGroup.wants,
        icon: 'dining',
        color: '#EF4444',
      ),
      _defaultCategory(
        userId: userId,
        id: 'default-expense-coffee',
        name: 'Coffee',
        type: CategoryType.expense,
        group: CategoryGroup.wants,
        icon: 'coffee',
        color: '#8B5A2B',
      ),
      _defaultCategory(
        userId: userId,
        id: 'default-expense-transport',
        name: 'Transport',
        type: CategoryType.expense,
        group: CategoryGroup.needs,
        icon: 'transport',
        color: '#3B82F6',
      ),
      _defaultCategory(
        userId: userId,
        id: 'default-expense-fuel',
        name: 'Fuel',
        type: CategoryType.expense,
        group: CategoryGroup.needs,
        icon: 'fuel',
        color: '#2563EB',
      ),
      _defaultCategory(
        userId: userId,
        id: 'default-expense-rent',
        name: 'Rent',
        type: CategoryType.expense,
        group: CategoryGroup.needs,
        icon: 'home',
        color: '#7C3AED',
      ),
      _defaultCategory(
        userId: userId,
        id: 'default-expense-utilities',
        name: 'Utilities',
        type: CategoryType.expense,
        group: CategoryGroup.needs,
        icon: 'utilities',
        color: '#0EA5E9',
      ),
      _defaultCategory(
        userId: userId,
        id: 'default-expense-phone',
        name: 'Phone',
        type: CategoryType.expense,
        group: CategoryGroup.needs,
        icon: 'phone',
        color: '#06B6D4',
      ),
      _defaultCategory(
        userId: userId,
        id: 'default-expense-internet',
        name: 'Internet',
        type: CategoryType.expense,
        group: CategoryGroup.needs,
        icon: 'internet',
        color: '#0284C7',
      ),
      _defaultCategory(
        userId: userId,
        id: 'default-expense-subscriptions',
        name: 'Subscriptions',
        type: CategoryType.expense,
        group: CategoryGroup.wants,
        icon: 'subscriptions',
        color: '#A855F7',
      ),
      _defaultCategory(
        userId: userId,
        id: 'default-expense-shopping',
        name: 'Shopping',
        type: CategoryType.expense,
        group: CategoryGroup.wants,
        icon: 'shopping',
        color: '#EC4899',
      ),
      _defaultCategory(
        userId: userId,
        id: 'default-expense-health',
        name: 'Health',
        type: CategoryType.expense,
        group: CategoryGroup.needs,
        icon: 'health',
        color: '#10B981',
      ),
      _defaultCategory(
        userId: userId,
        id: 'default-expense-insurance',
        name: 'Insurance',
        type: CategoryType.expense,
        group: CategoryGroup.needs,
        icon: 'insurance',
        color: '#14B8A6',
      ),
      _defaultCategory(
        userId: userId,
        id: 'default-expense-education',
        name: 'Education',
        type: CategoryType.expense,
        group: CategoryGroup.needs,
        icon: 'education',
        color: '#F59E0B',
      ),
      _defaultCategory(
        userId: userId,
        id: 'default-expense-travel',
        name: 'Travel',
        type: CategoryType.expense,
        group: CategoryGroup.wants,
        icon: 'travel',
        color: '#38BDF8',
      ),
      _defaultCategory(
        userId: userId,
        id: 'default-expense-entertainment',
        name: 'Entertainment',
        type: CategoryType.expense,
        group: CategoryGroup.wants,
        icon: 'entertainment',
        color: '#F43F5E',
      ),
      _defaultCategory(
        userId: userId,
        id: 'default-expense-fees',
        name: 'Fees',
        type: CategoryType.expense,
        group: CategoryGroup.custom,
        icon: 'fee',
        color: '#64748B',
      ),
      _defaultCategory(
        userId: userId,
        id: 'default-expense-taxes',
        name: 'Taxes',
        type: CategoryType.expense,
        group: CategoryGroup.tax,
        icon: 'tax',
        color: '#DC2626',
      ),
      _defaultCategory(
        userId: userId,
        id: 'default-expense-other',
        name: 'Other expense',
        type: CategoryType.expense,
        group: CategoryGroup.custom,
        icon: 'category',
        color: '#64748B',
      ),
    ];
  }

  Category _defaultCategory({
    required String userId,
    required String id,
    required String name,
    required CategoryType type,
    required CategoryGroup group,
    required String icon,
    required String color,
  }) {
    return Category(
      id: id,
      userId: userId,
      name: name,
      type: type,
      group: group,
      icon: icon,
      color: color,
      budgetEnabled: type == CategoryType.expense,
    );
  }
}
