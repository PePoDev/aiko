import 'package:aiko/brick/models/account.model.dart';
import 'package:aiko/brick/offline_model_mappers.dart';
import 'package:aiko/features/accounts/domain/account.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('goals -> account migration', () {
    test('OfflineAccount round-trips goal fields when type=goal', () {
      final source = OfflineAccount(
        id: 'acc-1',
        userId: 'user-1',
        name: 'Europe Trip',
        type: 'goal',
        currency: 'USD',
        currentBalance: '1200.00',
        goalTargetAmount: '5000.00',
        goalTargetDate: DateTime.utc(2027, 6, 1),
        goalPriority: 'high',
      );

      final domain = source.toDomain();

      expect(domain.type, AccountType.goal);
      expect(domain.isGoal, isTrue);
      expect(domain.targetAmount, isNotNull);
      expect(domain.targetAmount!.amount.toDouble(), 5000.0);
      expect(domain.targetDate, DateTime.utc(2027, 6, 1));
      expect(domain.priority, GoalPriority.high);
      expect(domain.goalProgress, closeTo(0.24, 0.01));
    });

    test('non-goal account has null goal fields', () {
      final source = OfflineAccount(
        id: 'acc-2',
        userId: 'user-1',
        name: 'Checking',
        type: 'bank',
        currency: 'USD',
        currentBalance: '500.00',
      );

      final domain = source.toDomain();
      final restored = domain.toOffline(userId: 'user-1');

      expect(domain.type, AccountType.bank);
      expect(domain.isGoal, isFalse);
      expect(domain.targetAmount, isNull);
      expect(domain.targetDate, isNull);
      expect(restored.goalTargetAmount, isNull);
      expect(restored.goalTargetDate, isNull);
      expect(restored.goalPriority, 'medium');
    });

    test('goal remaining caps at zero when over target', () {
      final source = OfflineAccount(
        id: 'acc-3',
        userId: 'user-1',
        name: 'Car',
        type: 'goal',
        currency: 'USD',
        currentBalance: '15000',
        goalTargetAmount: '12000',
        goalPriority: 'medium',
      );

      final domain = source.toDomain();
      expect(domain.goalProgress, 1.0);
      expect(domain.goalRemaining.amount.toString(), '0');
    });
  });
}
