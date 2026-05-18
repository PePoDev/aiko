import '../../../core/money/money.dart';
import '../domain/budget.dart';

class BudgetRepository {
  BudgetRepository({List<Budget>? budgets})
    : _budgets =
          budgets ??
          [
            Budget(
              id: 'dining-budget',
              userId: 'demo-user',
              name: 'Dining',
              categoryId: 'food',
              amount: Money.parse('400', 'USD'),
              periodStart: DateTime(2026, 5),
              periodEnd: DateTime(2026, 5, 31),
            ),
          ];

  final List<Budget> _budgets;

  Future<List<Budget>> list() async => List.unmodifiable(_budgets);

  Future<Budget> save(Budget budget) async {
    final index = _budgets.indexWhere((item) => item.id == budget.id);
    if (index == -1) {
      _budgets.add(budget);
    } else {
      _budgets[index] = budget;
    }
    return budget;
  }
}
