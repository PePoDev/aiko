import 'dart:async';

import 'package:aiko/core/offline/offline_data_migrator.dart';
import 'package:aiko/core/offline/offline_store.dart';
import 'package:aiko/core/offline/records/records.dart';
import 'package:aiko/core/storage/local_record_store.dart';
import 'package:aiko/features/categories/domain/category_defaults.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import '../storage/offline_firestore.dart';
import 'record_store_harness.dart';

const _localUserId = 'local:test-user';
const _realUserId = '11111111-1111-4111-8111-111111111111';

OfflineTransaction _tx(String id, {String? categoryId}) => OfflineTransaction(
  id: id,
  userId: _localUserId,
  accountId: 'account',
  type: 'expense',
  amount: '10',
  currency: 'THB',
  date: DateTime(2026, 7, 26),
  categoryId: categoryId,
);

void main() {
  late LocalRecordStore local;

  setUp(() async => local = await openMemoryRecordStore());
  tearDown(() => local.close());

  test(
    'claims defaults in dependency order and removes old local ids',
    () async {
      final store = _ClaimStore(local);
      await store.commit(
        RecordBatch()
          ..upsert(
            OfflineCategoryGroup(
              id: CategoryGroupDefaults.foodAndDrinkId,
              userId: _localUserId,
              name: 'Food & Drink',
              budgetAmount: '5000',
              budgetCurrency: 'THB',
            ),
          )
          ..upsert(
            OfflineCategory(
              id: CategoryDefaults.coffeeId,
              userId: _localUserId,
              name: 'Coffee',
              type: 'expense',
              categoryGroup: 'wants',
              groupId: CategoryGroupDefaults.foodAndDrinkId,
              budgetAmount: '3000',
              budgetCurrency: 'THB',
            ),
          )
          ..upsert(_tx('transaction', categoryId: CategoryDefaults.coffeeId)),
      );
      store.claimCommits.clear();
      final migrator = OfflineDataMigrator(store: store);

      final migrated = await migrator.claimAnonymousData(_realUserId);

      expect(migrated, 3);
      expect(store.claimCommits, [
        'category_groups',
        'categories',
        'transactions',
      ]);

      final group = (await store.get<OfflineCategoryGroup>()).single;
      expect(group.userId, _realUserId);
      expect(group.templateId, CategoryGroupDefaults.foodAndDrinkId);
      // Default clones keep the stored createdAt (none here): security rules
      // only let a clone's budget fields change.
      expect(group.createdAt, isNull);
      expect(
        group.id,
        CategoryGroupDefaults.cloneIdForUser(
          userId: _realUserId,
          templateId: CategoryGroupDefaults.foodAndDrinkId,
        ),
      );

      final category = (await store.get<OfflineCategory>()).single;
      expect(category.templateId, CategoryDefaults.coffeeId);
      expect(category.createdAt, isNull);
      expect(category.budgetAmount, '3000');
      expect(
        category.groupId,
        CategoryGroupDefaults.cloneIdForUser(
          userId: _realUserId,
          templateId: CategoryGroupDefaults.foodAndDrinkId,
        ),
      );

      final transaction = (await store.get<OfflineTransaction>()).single;
      expect(transaction.userId, _realUserId);
      expect(
        transaction.categoryId,
        CategoryDefaults.cloneIdForUser(
          userId: _realUserId,
          templateId: CategoryDefaults.coffeeId,
        ),
      );
      expect(await migrator.claimAnonymousData(_realUserId), 0);
    },
  );

  group('signed in', () {
    late FakeFirebaseFirestore firestore;

    setUp(() => firestore = FakeFirebaseFirestore());

    Future<List<Map<String, dynamic>>> cloudTransactions() async {
      final snapshot = await firestore
          .collection('users')
          .doc(_realUserId)
          .collection('transactions')
          .get();
      return [for (final doc in snapshot.docs) doc.data()];
    }

    test('rows go to Firestore in batches of at most 500 and leave the '
        'device', () async {
      final store = _ClaimStore(local, firestore: firestore);
      await store.commit(
        RecordBatch()..addAll([for (var i = 0; i < 1201; i++) _tx('t-$i')]),
        localOnly: true,
      );

      final migrated = await OfflineDataMigrator(
        store: store,
      ).claimAnonymousData(_realUserId);
      await pumpEventQueue();

      expect(migrated, 1201);
      expect(store.remoteBatchSizes, [500, 500, 201]);
      expect(await local.rows('transactions'), isEmpty);
      final claimed = await cloudTransactions();
      expect(claimed, hasLength(1201));
      expect(claimed.every((row) => row['user_id'] == _realUserId), isTrue);
    });

    CollectionReference<Map<String, dynamic>> cloud(
      String collection, {
      String userId = _realUserId,
    }) => firestore.collection('users').doc(userId).collection(collection);

    String groceriesCloneId({String userId = _realUserId}) =>
        CategoryDefaults.cloneIdForUser(
          userId: userId,
          templateId: CategoryDefaults.groceriesId,
        );

    /// The account's clone of Groceries, stamped by an older app version.
    Future<void> accountGroceries({
      String? budget,
      String userId = _realUserId,
    }) => cloud('categories', userId: userId)
        .doc(groceriesCloneId(userId: userId))
        .set(
          RecordCodecs.categories.toRow(
            CategoryDefaults.cloneForUser(
              userId: userId,
              template: CategoryDefaults.byId[CategoryDefaults.groceriesId]!,
            ).toOffline(userId: userId).withBudget(budget),
          ),
        );

    OfflineCategory guestCategory(
      String id,
      String name, {
      String? groupId,
      String? budget,
    }) => OfflineCategory(
      id: id,
      userId: _localUserId,
      name: name,
      type: 'expense',
      categoryGroup: 'custom',
      groupId: groupId,
      budgetAmount: budget,
      budgetCurrency: budget == null ? null : 'THB',
    );

    test('a guest budget on a default goes on the account\'s clone, budget '
        'fields only, apart from the guest\'s own categories', () async {
      await accountGroceries();
      final store = _ClaimStore(local, firestore: firestore);
      await store.commit(
        RecordBatch()..addAll([
          guestCategory(
            CategoryDefaults.groceriesId,
            'Groceries',
            budget: '3000',
          ),
          guestCategory('pets', 'Pets'),
        ]),
        localOnly: true,
      );

      await OfflineDataMigrator(
        store: store,
        firestore: firestore,
      ).claimAnonymousData(_realUserId);
      await pumpEventQueue();

      // Separate batches: a refused budget can't hold up "Pets".
      expect(store.remoteBatchSizes, [1, 1]);
      final clone = (await cloud(
        'categories',
      ).doc(groceriesCloneId()).get()).data()!;
      expect(clone['budget_amount'], '3000');
      expect(clone['created_at'], '2026-01-05T00:00:00.000Z');
      expect(clone['template_id'], CategoryDefaults.groceriesId);
      expect((await cloud('categories').doc('pets').get()).exists, isTrue);
      expect(await local.rows('categories'), isEmpty);
    });

    test('a budget the account set on a default stays', () async {
      await accountGroceries(budget: '5000');
      final store = _ClaimStore(local, firestore: firestore);
      await store.commit(
        RecordBatch()..upsert(
          guestCategory(
            CategoryDefaults.groceriesId,
            'Groceries',
            budget: '3000',
          ),
        ),
        localOnly: true,
      );

      await OfflineDataMigrator(
        store: store,
        firestore: firestore,
      ).claimAnonymousData(_realUserId);
      await pumpEventQueue();

      final clone = (await cloud(
        'categories',
      ).doc(groceriesCloneId()).get()).data()!;
      expect(clone['budget_amount'], '5000');
      expect(store.remoteBatchSizes, isEmpty);
      expect(await local.rows('categories'), isEmpty);
    });

    test('while the account\'s clone can\'t be read, the guest budget waits '
        'for a later claim', () async {
      final store = _ClaimStore(local, firestore: firestore);
      await store.commit(
        RecordBatch()..addAll([
          guestCategory(
            CategoryDefaults.groceriesId,
            'Groceries',
            budget: '3000',
          ),
          guestCategory('pets', 'Pets'),
        ]),
        localOnly: true,
      );

      await OfflineDataMigrator(
        store: store,
        // Reads of single documents never answer.
        firestore: OfflineFirestore(),
        serverTimeout: const Duration(milliseconds: 20),
      ).claimAnonymousData(_realUserId);
      await pumpEventQueue();

      expect(
        (await cloud('categories').doc(groceriesCloneId()).get()).exists,
        isFalse,
      );
      expect((await cloud('categories').doc('pets').get()).exists, isTrue);
      final left = await store.get<OfflineCategory>(localOnly: true);
      expect(left.single.id, CategoryDefaults.groceriesId);
      expect(left.single.userId, OfflineDataMigrator.waitingOwner(_realUserId));
    });

    test('a budget left waiting goes only into the account it was meant '
        'for', () async {
      const otherUserId = '22222222-2222-4222-8222-222222222222';
      await _ClaimStore(local, firestore: firestore).commit(
        RecordBatch()..upsert(
          guestCategory(
            CategoryDefaults.groceriesId,
            'Groceries',
            budget: '3000',
          ),
        ),
        localOnly: true,
      );
      await OfflineDataMigrator(
        store: _ClaimStore(local, firestore: firestore),
        firestore: OfflineFirestore(),
        serverTimeout: const Duration(milliseconds: 20),
      ).claimAnonymousData(_realUserId);

      // Another account signs in on this device before it is claimed.
      await accountGroceries(userId: otherUserId);
      final other = _ClaimStore(
        local,
        firestore: firestore,
        userId: otherUserId,
      );
      expect(
        await OfflineDataMigrator(
          store: other,
          firestore: firestore,
        ).claimAnonymousData(otherUserId),
        0,
      );
      await pumpEventQueue();
      expect(other.remoteBatchSizes, isEmpty);
      expect(
        (await cloud(
              'categories',
              userId: otherUserId,
            ).doc(groceriesCloneId(userId: otherUserId)).get())
            .data()!['budget_amount'],
        isNull,
      );
      expect(await local.rows('categories'), hasLength(1));

      // Back in the account it was meant for, now readable.
      await accountGroceries();
      await OfflineDataMigrator(
        store: _ClaimStore(local, firestore: firestore),
        firestore: firestore,
      ).claimAnonymousData(_realUserId);
      await pumpEventQueue();
      expect(
        (await cloud(
          'categories',
        ).doc(groceriesCloneId()).get()).data()!['budget_amount'],
        '3000',
      );
      expect(await local.rows('categories'), isEmpty);
    });

    test('a custom category or group named like the account\'s brings its '
        'budget when that one has none, budget fields only', () async {
      await cloud('category_groups')
          .doc('account-kids')
          .set(
            RecordCodecs.categoryGroups.toRow(
              OfflineCategoryGroup(
                id: 'account-kids',
                userId: _realUserId,
                name: 'Kids',
                icon: 'child',
                color: '#000000',
                sortOrder: 1,
              ),
            ),
          );
      for (final (id, name, budget) in [
        ('account-pets', 'Pets', null),
        ('account-toys', 'Toys', '500'),
      ]) {
        await cloud('categories')
            .doc(id)
            .set(
              RecordCodecs.categories.toRow(
                guestCategory(id, name, budget: budget).withOwner(_realUserId),
              ),
            );
      }
      final store = _ClaimStore(local, firestore: firestore);
      await store.commit(
        RecordBatch()..addAll([
          OfflineCategoryGroup(
            id: 'guest-kids',
            userId: _localUserId,
            name: 'kids',
            icon: 'star',
            color: '#FFFFFF',
            sortOrder: 9,
            budgetAmount: '2000',
            budgetCurrency: 'THB',
          ),
          guestCategory('guest-pets', 'pets', budget: '300'),
          guestCategory('guest-toys', 'toys', budget: '100'),
        ]),
        localOnly: true,
      );

      await OfflineDataMigrator(
        store: store,
        firestore: firestore,
      ).claimAnonymousData(_realUserId);
      await pumpEventQueue();

      final kids = (await cloud(
        'category_groups',
      ).doc('account-kids').get()).data()!;
      expect(kids['budget_amount'], '2000');
      expect(kids['budget_currency'], 'THB');
      expect(
        [kids['name'], kids['icon'], kids['sort_order']],
        ['Kids', 'child', 1],
      );
      final pets = (await cloud(
        'categories',
      ).doc('account-pets').get()).data()!;
      expect(pets['budget_amount'], '300');
      expect(pets['name'], 'Pets');
      expect(
        (await cloud(
          'categories',
        ).doc('account-toys').get()).data()!['budget_amount'],
        '500',
      );
      expect(await local.rows('categories'), isEmpty);
      expect(await local.rows('category_groups'), isEmpty);
    });

    test('a merged budget waits while the account\'s category can\'t be '
        'read', () async {
      await cloud('categories')
          .doc('account-pets')
          .set(
            RecordCodecs.categories.toRow(
              guestCategory('account-pets', 'Pets').withOwner(_realUserId),
            ),
          );
      final store = _ClaimStore(local, firestore: firestore);
      await store.commit(
        RecordBatch()..addAll([
          guestCategory('guest-pets', 'pets', budget: '300'),
          _tx('t', categoryId: 'guest-pets'),
        ]),
        localOnly: true,
      );

      await OfflineDataMigrator(
        store: store,
        firestore: OfflineFirestore(),
        serverTimeout: const Duration(milliseconds: 20),
      ).claimAnonymousData(_realUserId);
      await pumpEventQueue();

      expect((await cloudTransactions()).single['category_id'], 'account-pets');
      final left = (await store.get<OfflineCategory>(localOnly: true)).single;
      expect(left.id, 'guest-pets');
      expect(left.userId, OfflineDataMigrator.waitingOwner(_realUserId));

      await OfflineDataMigrator(
        store: store,
        firestore: firestore,
      ).claimAnonymousData(_realUserId);
      await pumpEventQueue();
      expect(
        (await cloud(
          'categories',
        ).doc('account-pets').get()).data()!['budget_amount'],
        '300',
      );
      expect(await local.rows('categories'), isEmpty);
    });

    test('a custom category or group named like the account\'s becomes that '
        'one', () async {
      await cloud('category_groups')
          .doc('account-kids')
          .set(
            RecordCodecs.categoryGroups.toRow(
              OfflineCategoryGroup(
                id: 'account-kids',
                userId: _realUserId,
                name: 'Kids',
                icon: 'child',
                color: '#000000',
                sortOrder: 1,
              ),
            ),
          );
      await cloud('categories')
          .doc('account-pets')
          .set(
            RecordCodecs.categories.toRow(
              guestCategory('account-pets', 'Pets').withOwner(_realUserId),
            ),
          );
      final store = _ClaimStore(local, firestore: firestore);
      await store.commit(
        RecordBatch()..addAll([
          OfflineCategoryGroup(
            id: 'guest-kids',
            userId: _localUserId,
            name: 'kids',
            icon: 'child',
            color: '#000000',
            sortOrder: 1,
          ),
          guestCategory('guest-pets', 'pets', groupId: 'guest-kids'),
          guestCategory('guest-toys', 'Toys', groupId: 'guest-kids'),
          _tx('t', categoryId: 'guest-pets'),
        ]),
        localOnly: true,
      );
      final migrator = OfflineDataMigrator(store: store, firestore: firestore);

      await migrator.claimAnonymousData(_realUserId);
      await pumpEventQueue();

      expect(
        migrator.claimedCategoryId(_realUserId, 'guest-pets'),
        'account-pets',
      );
      expect(
        (await cloud('categories').doc('guest-pets').get()).exists,
        isFalse,
      );
      expect(
        (await cloud('category_groups').doc('guest-kids').get()).exists,
        isFalse,
      );
      final toys = (await cloud('categories').doc('guest-toys').get()).data()!;
      expect(toys['group_id'], 'account-kids');
      expect((await cloudTransactions()).single['category_id'], 'account-pets');
      expect(await local.rows('categories'), isEmpty);
      expect(await local.rows('category_groups'), isEmpty);
    });

    test('rows the server rejects are put back for the next claim', () async {
      final store = _ClaimStore(local, firestore: firestore)
        ..rejectRemote = true;
      await store.commit(
        RecordBatch()..addAll([_tx('a'), _tx('b')]),
        localOnly: true,
      );

      expect(
        await OfflineDataMigrator(store: store).claimAnonymousData(_realUserId),
        2,
      );
      await pumpEventQueue();

      final restored = await store.get<OfflineTransaction>(localOnly: true);
      expect(restored.map((t) => t.id).toSet(), {'a', 'b'});
      expect(restored.every((t) => t.userId == _localUserId), isTrue);
      expect(await cloudTransactions(), isEmpty);

      store.rejectRemote = false;
      expect(
        await OfflineDataMigrator(store: store).claimAnonymousData(_realUserId),
        2,
      );
      await pumpEventQueue();
      expect(await cloudTransactions(), hasLength(2));
      expect(await local.rows('transactions'), isEmpty);
    });
  });
}

extension on RecordBatch {
  void addAll(Iterable<OfflineRecord> records) => records.forEach(upsert);
}

extension on OfflineCategory {
  OfflineCategory withOwner(String userId) => RecordCodecs.categories.fromRow({
    ...RecordCodecs.categories.toRow(this),
    'user_id': userId,
  });

  /// As stored by an older app version: stamped, with [budget] if given.
  OfflineCategory withBudget(String? budget) =>
      RecordCodecs.categories.fromRow({
        ...RecordCodecs.categories.toRow(this),
        'created_at': '2026-01-05T00:00:00.000Z',
        'budget_amount': budget,
        'budget_currency': budget == null ? null : 'THB',
      });
}

/// The real store over [local] (and [firestore] when signed in) that notes
/// which collections are claimed, the sizes of Firestore batches, and can
/// have the server reject them.
class _ClaimStore extends OfflineStore {
  _ClaimStore(
    LocalRecordStore local, {
    FakeFirebaseFirestore? firestore,
    String userId = _realUserId,
  }) : super(
         local: local,
         firestore: firestore,
         signedInUserId: () => firestore == null ? null : userId,
       );

  final List<String> claimCommits = [];
  final List<int> remoteBatchSizes = [];
  bool rejectRemote = false;

  @override
  Future<void> commit(
    RecordBatch batch, {
    bool localOnly = false,
    bool allowChunks = false,
    void Function(Object error)? onRejected,
  }) async {
    if (batch.isEmpty) return;
    if (!localOnly) {
      claimCommits.add(batch.writes.first.collection);
      if (canSyncRemote) remoteBatchSizes.add(batch.length);
      if (canSyncRemote && rejectRemote) {
        // Handed off, then refused by the server later on.
        scheduleMicrotask(
          () => onRejected?.call(StateError('permission-denied')),
        );
        return;
      }
    }
    await super.commit(
      batch,
      localOnly: localOnly,
      allowChunks: allowChunks,
      onRejected: onRejected,
    );
  }
}
