import 'package:aiko/brick/models/category.model.dart';
import 'package:aiko/brick/offline_model_mappers.dart';
import 'package:aiko/features/categories/domain/category.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('budgets -> category migration', () {
    test('OfflineCategory round-trips budget fields', () {
      final source = OfflineCategory(
        id: 'cat-1',
        userId: 'user-1',
        name: 'Groceries',
        type: 'expense',
        categoryGroup: 'needs',
        budgetEnabled: true,
        isActive: true,
        budgetAmount: '450.00',
        budgetCurrency: 'USD',
        budgetPeriod: 'monthly',
        budgetRollover: false,
        alertThresholds: const [50, 75, 90, 100],
      );

      final domain = source.toDomain();
      final restored = domain.toOffline(userId: 'user-1');

      expect(domain.monthlyLimit, isNotNull);
      expect(domain.monthlyLimit!.amount.toDouble(), 450.0);
      expect(domain.budgetPeriod, CategoryBudgetPeriod.monthly);
      expect(domain.rolloverUnused, isFalse);
      expect(domain.alertThresholds, [50, 75, 90, 100]);
      expect(restored.budgetAmount, '450');
      expect(restored.budgetCurrency, 'USD');
      expect(restored.budgetPeriod, 'monthly');
    });

    test('category with no budget serializes null fields', () {
      final source = OfflineCategory(
        id: 'cat-2',
        userId: 'user-1',
        name: 'Dining',
        type: 'expense',
        categoryGroup: 'wants',
      );

      final domain = source.toDomain();
      final restored = domain.toOffline(userId: 'user-1');

      expect(domain.monthlyLimit, isNull);
      expect(domain.budgetPeriod, CategoryBudgetPeriod.monthly);
      expect(restored.budgetAmount, isNull);
      expect(restored.budgetCurrency, isNull);
    });

    test('rollover + weekly period survive the round-trip', () {
      final source = OfflineCategory(
        id: 'cat-3',
        userId: 'user-1',
        name: 'Coffee',
        type: 'expense',
        categoryGroup: 'wants',
        budgetAmount: '40',
        budgetCurrency: 'EUR',
        budgetPeriod: 'weekly',
        budgetRollover: true,
        alertThresholds: const [80, 100],
      );

      final domain = source.toDomain();
      final restored = domain.toOffline(userId: 'user-1');

      expect(domain.budgetPeriod, CategoryBudgetPeriod.weekly);
      expect(domain.rolloverUnused, isTrue);
      expect(domain.alertThresholds, [80, 100]);
      expect(restored.budgetPeriod, 'weekly');
      expect(restored.budgetRollover, isTrue);
    });
  });
}
