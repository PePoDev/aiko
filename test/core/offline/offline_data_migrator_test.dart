import 'dart:async';

import 'package:aiko/core/offline/offline_data_migrator.dart';
import 'package:aiko/core/offline/offline_store.dart';
import 'package:aiko/core/offline/records/records.dart';
import 'package:aiko/core/storage/local_record_store.dart';
import 'package:aiko/features/categories/domain/category_defaults.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

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

/// The real store over [local] (and [firestore] when signed in) that notes
/// which collections are claimed, the sizes of Firestore batches, and can
/// have the server reject them.
class _ClaimStore extends OfflineStore {
  _ClaimStore(LocalRecordStore local, {FakeFirebaseFirestore? firestore})
    : super(
        local: local,
        firestore: firestore,
        signedInUserId: () => firestore == null ? null : _realUserId,
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
