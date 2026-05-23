import '../../../core/money/money.dart';
import '../../../brick/offline_model_mappers.dart';
import '../../../brick/repository.dart';
import '../../../brick/models/goal.model.dart';
import '../../../core/offline/offline_store.dart';
import '../../../core/offline/offline_user_context.dart';
import '../domain/goal.dart';

class GoalRepository {
  const GoalRepository();

  Future<List<Goal>> list() async {
    final userId = await OfflineUserContext().resolveUserId();
    final goals = await OfflineStore().get<OfflineGoal>(
      query: Query(
        where: [Where.exact('userId', userId)],
        orderBy: const [OrderBy.asc('targetDate')],
      ),
    );

    return goals.map((goal) => goal.toDomain()).toList(growable: false);
  }

  Future<Goal> save(Goal goal) async {
    if (goal.targetAmount.amount <=
        Money.zero(goal.targetAmount.currency).amount) {
      throw ArgumentError('Target amount must be greater than zero.');
    }

    final userId = await OfflineUserContext().resolveUserId();
    final saved = await OfflineStore().upsert(goal.toOffline(userId: userId));
    return saved.toDomain();
  }

  Future<void> delete(String id) async {
    final userId = await OfflineUserContext().resolveUserId();
    final goals = await OfflineStore().get<OfflineGoal>(
      query: Query(
        where: [Where.exact('id', id), Where.exact('userId', userId)],
        limit: 1,
      ),
    );
    if (goals.isEmpty) {
      return;
    }
    await OfflineStore().delete(goals.first);
  }
}
