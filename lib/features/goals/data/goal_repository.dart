import '../../../core/money/money.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../domain/goal.dart';

class GoalRepository {
  const GoalRepository();

  Future<List<Goal>> list() async {
    final session = AikoSupabase.requireSession();
    final response = await session.client
        .from('goals')
        .select()
        .eq('user_id', session.userId)
        .order('target_date');

    return response
        .map((row) => _fromRow(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  Future<Goal> save(Goal goal) async {
    if (goal.targetAmount.amount <=
        Money.zero(goal.targetAmount.currency).amount) {
      throw ArgumentError('Target amount must be greater than zero.');
    }

    final session = AikoSupabase.requireSession();
    final goalWithUser = Goal(
      id: goal.id,
      userId: session.userId,
      name: goal.name,
      purpose: goal.purpose,
      targetAmount: goal.targetAmount,
      currentAmount: goal.currentAmount,
      targetDate: goal.targetDate,
      linkedAccountId: goal.linkedAccountId,
      priority: goal.priority,
      successProbability: goal.successProbability,
      status: goal.status,
    );

    await session.client.from('goals').upsert(_toRow(goalWithUser));
    return goalWithUser;
  }

  static Goal _fromRow(Map<String, dynamic> row) {
    final purpose = GoalPurpose.values.firstWhere(
      (item) => item.name == (row['purpose'] as String? ?? 'custom'),
      orElse: () => GoalPurpose.custom,
    );
    final status = GoalStatus.values.firstWhere(
      (item) => item.name == (row['status'] as String? ?? 'active'),
      orElse: () => GoalStatus.active,
    );
    final currency = row['currency'] as String? ?? 'USD';

    return Goal(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      name: row['name'] as String,
      purpose: purpose,
      targetAmount: Money.parse('${row['target_amount'] ?? 0}', currency),
      currentAmount: Money.parse('${row['current_amount'] ?? 0}', currency),
      targetDate: DateTime.parse(row['target_date'] as String),
      linkedAccountId: row['linked_account_id'] as String?,
      priority: row['priority'] as int? ?? 1,
      successProbability: (row['success_probability'] as num?)?.toDouble(),
      status: status,
    );
  }

  static Map<String, dynamic> _toRow(Goal goal) {
    return {
      'id': goal.id,
      'user_id': goal.userId,
      'name': goal.name,
      'purpose': goal.purpose.name,
      'target_amount': goal.targetAmount.amount.toString(),
      'current_amount': goal.currentAmount.amount.toString(),
      'currency': goal.targetAmount.currency,
      'target_date': goal.targetDate.toIso8601String().substring(0, 10),
      'linked_account_id': goal.linkedAccountId,
      'priority': goal.priority,
      'success_probability': goal.successProbability,
      'status': goal.status.name,
    };
  }
}
