import '../../../core/money/money.dart';
import '../domain/goal.dart';

class GoalRepository {
  GoalRepository({List<Goal>? goals})
    : _goals =
          goals ??
          [
            Goal(
              id: 'emergency',
              userId: 'demo-user',
              name: 'Emergency fund',
              purpose: GoalPurpose.emergencyFund,
              targetAmount: Money.parse('5000', 'USD'),
              currentAmount: Money.parse('3100', 'USD'),
              targetDate: DateTime(2026, 12, 31),
            ),
          ];

  final List<Goal> _goals;

  Future<List<Goal>> list() async => List.unmodifiable(_goals);

  Future<Goal> save(Goal goal) async {
    if (goal.targetAmount.amount <=
        Money.zero(goal.targetAmount.currency).amount) {
      throw ArgumentError('Target amount must be greater than zero.');
    }
    final index = _goals.indexWhere((item) => item.id == goal.id);
    if (index == -1) {
      _goals.add(goal);
    } else {
      _goals[index] = goal;
    }
    return goal;
  }
}
