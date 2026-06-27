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

  group('CategoryDefaults.legacySlugToUuid', () {
    test('every legacy slug maps to a registered system id', () {
      for (final entry in CategoryDefaults.legacySlugToUuid.entries) {
        expect(
          CategoryDefaults.allIds,
          contains(entry.value),
          reason: 'Legacy slug "${entry.key}" points at an unknown id '
              '${entry.value}',
        );
      }
    });

    test('legacy slugs use the historical default-* naming', () {
      for (final slug in CategoryDefaults.legacySlugToUuid.keys) {
        expect(slug, startsWith('default-'));
      }
    });
  });
}
