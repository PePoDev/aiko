import 'package:aiko/features/categories/domain/category.dart';
import 'package:aiko/features/categories/domain/category_defaults.dart';
import 'package:flutter_test/flutter_test.dart';

/// Loose RFC-4122-ish shape check: 8-4-4-4-12 lowercase hex groups. The system
/// ids are hand-written constants, so this guards against a fat-fingered
/// constant (wrong length, stray character) slipping into a migration.
final _uuidPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
);

void main() {
  group('CategoryDefaults.all', () {
    test('exposes at least one category', () {
      expect(CategoryDefaults.all, isNotEmpty);
    });

    test('every category id is unique (no duplicated UUIDs)', () {
      final ids = CategoryDefaults.all.map((c) => c.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
    });

    test('the set of category ids matches the published allIds set', () {
      // Guards the most likely drift: adding a category but forgetting to
      // register its id in `allIds` (or vice-versa). The two must stay in sync
      // because foreign-key checks and seeding both rely on `allIds`.
      final ids = CategoryDefaults.all.map((c) => c.id).toSet();
      expect(ids, equals(CategoryDefaults.allIds));
    });

    test('allIds has no duplicates and matches the category count', () {
      expect(CategoryDefaults.allIds, hasLength(CategoryDefaults.all.length));
    });

    test('every id is a well-formed UUID', () {
      for (final category in CategoryDefaults.all) {
        expect(
          _uuidPattern.hasMatch(category.id),
          isTrue,
          reason: 'Malformed id for "${category.name}": ${category.id}',
        );
      }
    });

    test('system categories belong to no user', () {
      for (final category in CategoryDefaults.all) {
        expect(category.userId, isEmpty, reason: category.name);
      }
    });

    test('every category has a non-empty name and hex colour', () {
      for (final category in CategoryDefaults.all) {
        expect(category.name.trim(), isNotEmpty);
        expect(category.color, startsWith('#'));
      }
    });

    test('only income and expense types are seeded', () {
      final types = CategoryDefaults.all.map((c) => c.type).toSet();
      expect(types, isNot(contains(CategoryType.transfer)));
      expect(
        types.every(
          (t) => t == CategoryType.income || t == CategoryType.expense,
        ),
        isTrue,
        reason: 'Unexpected seeded types: $types',
      );
    });
  });

  group('per-user default clones', () {
    const userA = '11111111-1111-4111-8111-111111111111';
    const userB = '22222222-2222-4222-8222-222222222222';

    test('matches the PostgreSQL UUIDv5 vectors', () {
      expect(
        CategoryGroupDefaults.cloneIdForUser(
          userId: userA,
          templateId: CategoryGroupDefaults.foodAndDrinkId,
        ),
        '35c0421d-5cf3-506c-a571-673b06e355e4',
      );
      expect(
        CategoryDefaults.cloneIdForUser(
          userId: userA,
          templateId: CategoryDefaults.coffeeId,
        ),
        '72a3b441-4610-5bf3-9df7-ffe1c177faef',
      );
    });

    test('creates the complete taxonomy for each user', () {
      expect(CategoryGroupDefaults.forUser(userA), hasLength(13));
      expect(CategoryDefaults.forUser(userA), hasLength(81));
    });

    test('uses different clone ids for different users', () {
      final userAIds = CategoryDefaults.forUser(
        userA,
      ).map((category) => category.id).toSet();
      final userBIds = CategoryDefaults.forUser(
        userB,
      ).map((category) => category.id).toSet();
      expect(userAIds.intersection(userBIds), isEmpty);
    });

    test('category clones point to the same user group clone', () {
      final coffee = CategoryDefaults.forUser(userA).singleWhere(
        (category) => category.templateId == CategoryDefaults.coffeeId,
      );

      expect(coffee.isDefault, isTrue);
      expect(coffee.userId, userA);
      expect(
        coffee.groupId,
        CategoryGroupDefaults.cloneIdForUser(
          userId: userA,
          templateId: CategoryGroupDefaults.foodAndDrinkId,
        ),
      );
    });

    test('recognizes templates and clones without marking custom rows', () {
      expect(CategoryDefaults.all.first.isDefault, isTrue);
      expect(CategoryDefaults.forUser(userA).first.isDefault, isTrue);
      expect(
        const Category(
          id: 'custom',
          userId: userA,
          name: 'Custom',
          type: CategoryType.expense,
          group: CategoryBudgetGroup.custom,
        ).isDefault,
        isFalse,
      );
    });

    // Security rules only let a default clone's budget fields change, so a
    // clone seeded without createdAt must not gain one when normalized.
    test('normalizing a clone keeps its stored createdAt, even null', () {
      final coffee = CategoryDefaults.forUser(userA).singleWhere(
        (category) => category.templateId == CategoryDefaults.coffeeId,
      );
      expect(coffee.createdAt, isNull);
      expect(
        CategoryDefaults.normalizeForUser(coffee, userId: userA).createdAt,
        isNull,
      );

      final stamped = DateTime.utc(2026, 1, 2);
      expect(
        CategoryDefaults.normalizeForUser(
          coffee.copyWith(createdAt: stamped),
          userId: userA,
        ).createdAt,
        stamped,
      );

      final group = CategoryGroupDefaults.forUser(userA).first;
      expect(group.createdAt, isNull);
      expect(
        CategoryGroupDefaults.normalizeForUser(group, userId: userA).createdAt,
        isNull,
      );
    });
  });
}
