import 'package:aiko/app/providers.dart';
import 'package:aiko/core/money/money.dart';
import 'package:aiko/core/offline/offline_store.dart';
import 'package:aiko/core/offline/records/records.dart';
import 'package:aiko/core/storage/local_record_store.dart';
import 'package:aiko/features/categories/data/category_group_repository.dart';
import 'package:aiko/features/categories/data/category_repository.dart';
import 'package:aiko/features/categories/domain/category.dart';
import 'package:aiko/features/categories/domain/category_defaults.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../core/offline/record_store_harness.dart';

/// A save shows in the lists at once, even when a read right after it is
/// served from before the write (signed in on Android, the cache query can
/// run before the write is applied).
void main() {
  const owner = '11111111-1111-4111-8111-111111111111';
  const userContext = FixedUserContext(owner);
  late LocalRecordStore local;
  late _LaggingStore store;
  late ProviderContainer container;

  setUp(() async {
    local = await openMemoryRecordStore();
    store = _LaggingStore(local);
    container = ProviderContainer(
      overrides: [
        offlineStoreProvider.overrideWithValue(store),
        categoryRepositoryProvider.overrideWithValue(
          CategoryRepository(store: store, userContext: userContext),
        ),
        categoryGroupRepositoryProvider.overrideWithValue(
          CategoryGroupRepository(store: store, userContext: userContext),
        ),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await local.close();
  });

  test('a saved category and budget show although the store lags', () async {
    container.listen(categoriesProvider, (_, _) {});
    await container.read(categoriesProvider.future);
    store.lagging = true;
    final notifier = container.read(categoriesProvider.notifier);

    await notifier.saveCategory(
      const Category(
        id: 'dddddddd-0000-4000-8000-000000000001',
        userId: owner,
        name: 'Pets',
        type: CategoryType.expense,
        group: CategoryBudgetGroup.custom,
      ),
    );
    final coffee = (await container.read(
      categoriesProvider.future,
    )).singleWhere((c) => c.templateId == CategoryDefaults.coffeeId);
    await notifier.saveCategory(
      coffee.copyWith(monthlyLimit: Money.parse('300', 'THB')),
    );

    final categories = await container.read(categoriesProvider.future);
    expect(categories.map((c) => c.name), contains('Pets'));
    expect(
      categories
          .singleWhere((c) => c.templateId == CategoryDefaults.coffeeId)
          .monthlyLimit,
      Money.parse('300', 'THB'),
    );
    expect(
      categories.where((c) => c.templateId == CategoryDefaults.coffeeId),
      hasLength(1),
    );
  });

  test('a saved group shows although the store lags', () async {
    container.listen(categoryGroupsProvider, (_, _) {});
    await container.read(categoryGroupsProvider.future);
    store.lagging = true;

    await container
        .read(categoryGroupsProvider.notifier)
        .saveGroup(
          const CategoryGroup(id: 'kids', userId: owner, name: 'Kids'),
        );

    final groups = await container.read(categoryGroupsProvider.future);
    expect(groups.first.name, 'Kids');
    expect(groups, hasLength(CategoryGroupDefaults.all.length + 1));
  });
}

/// Once [lagging], reads return what the store held before (writes still
/// land).
class _LaggingStore extends OfflineStore {
  _LaggingStore(LocalRecordStore local)
    : super(local: local, signedInUserId: () => null);

  var lagging = false;
  final _before = <Type, List<OfflineRecord>>{};

  @override
  Future<List<T>> get<T extends OfflineRecord>({
    RecordQuery? query,
    bool localOnly = false,
  }) async {
    final rows = await super.get<T>(query: query, localOnly: localOnly);
    if (!lagging) {
      _before[T] = rows;
      return rows;
    }
    return [...?_before[T]?.whereType<T>()];
  }
}
