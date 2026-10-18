import 'package:aiko/core/money/money.dart';
import 'package:aiko/core/offline/offline_store.dart';
import 'package:aiko/core/offline/records/records.dart';
import 'package:aiko/core/storage/local_record_store.dart';
import 'package:aiko/features/categories/data/category_group_repository.dart';
import 'package:aiko/features/categories/data/category_repository.dart';
import 'package:aiko/features/categories/domain/category.dart';
import 'package:aiko/features/categories/domain/category_defaults.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../core/offline/record_store_harness.dart';

void main() {
  const userId = '11111111-1111-4111-8111-111111111111';
  late LocalRecordStore local;
  late OfflineStore store;
  late CategoryRepository repository;

  setUp(() async {
    local = await openMemoryRecordStore();
    store = OfflineStore(local: local, signedInUserId: () => null);
    repository = CategoryRepository(
      store: store,
      userContext: const FixedUserContext(userId),
    );
  });
  tearDown(() => local.close());

  Category coffeeClone() => CategoryDefaults.cloneForUser(
    userId: userId,
    template: CategoryDefaults.all.singleWhere(
      (category) => category.id == CategoryDefaults.coffeeId,
    ),
  );

  test('custom category can share a name with a built-in clone', () async {
    await store.upsert(coffeeClone().toOffline(userId: userId));

    final saved = await repository.save(
      const Category(
        id: 'dddddddd-0000-4000-8000-000000000001',
        userId: userId,
        name: 'Coffee',
        type: CategoryType.expense,
        group: CategoryBudgetGroup.custom,
      ),
    );

    expect(saved.id, 'dddddddd-0000-4000-8000-000000000001');
    expect(await repository.list(), hasLength(2));
  });

  test(
    'a budget save keeps a seeded clone\'s null createdAt; custom rows get one',
    () async {
      final budgeted = await repository.save(
        coffeeClone().copyWith(monthlyLimit: Money.parse('300', 'THB')),
      );
      final custom = await repository.save(
        const Category(
          id: 'dddddddd-0000-4000-8000-000000000002',
          userId: userId,
          name: 'Plants',
          type: CategoryType.expense,
          group: CategoryBudgetGroup.custom,
        ),
      );

      expect(budgeted.createdAt, isNull);
      expect(budgeted.monthlyLimit, Money.parse('300', 'THB'));
      expect(custom.createdAt, isNotNull);
    },
  );

  test('default categories cannot be deleted; custom ones can', () async {
    final clone = coffeeClone();
    await repository.save(clone);
    await repository.save(
      const Category(
        id: 'dddddddd-0000-4000-8000-000000000003',
        userId: userId,
        name: 'Plants',
        type: CategoryType.expense,
        group: CategoryBudgetGroup.custom,
      ),
    );

    await expectLater(repository.delete(clone.id), throwsStateError);
    final batch = RecordBatch();
    await repository.delete(
      'dddddddd-0000-4000-8000-000000000003',
      batch: batch,
    );
    expect(await repository.list(), hasLength(2));
    await store.commit(batch);
    expect((await repository.list()).single.id, clone.id);
  });

  test('a category that already shares its name can still be edited; a '
      'rename into a taken name cannot', () async {
    const pets = Category(
      id: 'dddddddd-0000-4000-8000-000000000010',
      userId: userId,
      name: 'Pets',
      type: CategoryType.expense,
      group: CategoryBudgetGroup.custom,
    );
    // Two "Pets", as made on two devices offline (saved past the check).
    await store.upsert(pets.toOffline(userId: userId));
    await store.upsert(
      pets
          .copyWith(id: 'dddddddd-0000-4000-8000-000000000011')
          .toOffline(userId: userId),
    );

    final budgeted = await repository.save(
      pets.copyWith(monthlyLimit: Money.parse('900', 'THB')),
    );
    expect(budgeted.monthlyLimit, Money.parse('900', 'THB'));

    await repository.save(
      const Category(
        id: 'dddddddd-0000-4000-8000-000000000012',
        userId: userId,
        name: 'Plants',
        type: CategoryType.expense,
        group: CategoryBudgetGroup.custom,
      ),
    );
    await expectLater(
      repository.save(
        pets.copyWith(id: 'dddddddd-0000-4000-8000-000000000012'),
      ),
      throwsArgumentError,
    );
    await expectLater(
      repository.save(
        pets.copyWith(id: 'dddddddd-0000-4000-8000-000000000013'),
      ),
      throwsArgumentError,
    );
  });

  test('a custom group cannot take a default group\'s name, even before the '
      'default is stored; one that has it can still be edited', () async {
    final groups = CategoryGroupRepository(
      store: store,
      userContext: const FixedUserContext(userId),
    );
    final defaultName = CategoryGroupDefaults.all.first.name;

    await expectLater(
      groups.save(CategoryGroup(id: 'mine', userId: userId, name: defaultName)),
      throwsArgumentError,
    );

    // Brought in from a guest under the default's name.
    await store.upsert(
      CategoryGroup(
        id: 'claimed',
        userId: userId,
        name: defaultName,
      ).toOffline(userId: userId),
    );
    final saved = await groups.save(
      CategoryGroup(
        id: 'claimed',
        userId: userId,
        name: defaultName,
        budgetLimit: Money.parse('100', 'THB'),
      ),
    );
    expect(saved.budgetLimit, Money.parse('100', 'THB'));
  });

  test('a custom group is deleted; default ones are kept', () async {
    final groups = CategoryGroupRepository(
      store: store,
      userContext: const FixedUserContext(userId),
    );
    await groups.save(
      const CategoryGroup(id: 'treats', userId: userId, name: 'Treats'),
    );
    final defaultClone = CategoryGroupDefaults.cloneForUser(
      userId: userId,
      template: CategoryGroupDefaults.all.first,
    );
    await groups.save(defaultClone);

    await expectLater(groups.delete(defaultClone.id), throwsStateError);
    await groups.delete('treats');

    expect((await groups.list()).single.id, defaultClone.id);
    expect(await store.get<OfflineCategoryGroup>(), hasLength(1));
  });
}
