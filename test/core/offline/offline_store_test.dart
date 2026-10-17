import 'dart:async';

import 'package:aiko/core/offline/offline_store.dart';
import 'package:aiko/core/offline/records/records.dart';
import 'package:aiko/core/storage/local_record_store.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'record_store_harness.dart';

const _uid = '11111111-1111-4111-8111-111111111111';

OfflineTransaction _tx(
  String id, {
  String userId = _uid,
  String accountId = 'cash',
  DateTime? date,
  String amount = '10',
}) => OfflineTransaction(
  id: id,
  userId: userId,
  accountId: accountId,
  type: 'expense',
  amount: amount,
  currency: 'THB',
  date: date ?? DateTime(2026, 10, 1),
);

OfflineAccount _account(String id, {String userId = _uid, String? name}) =>
    OfflineAccount(
      id: id,
      userId: userId,
      name: name ?? id,
      type: 'cash',
      currency: 'THB',
      currentBalance: '0',
    );

void main() {
  group('signed out: the local record store', () {
    late LocalRecordStore local;
    late OfflineStore store;

    setUp(() async {
      local = await openMemoryRecordStore();
      store = OfflineStore(local: local, signedInUserId: () => null);
    });
    tearDown(() => local.close());

    test('upsert, query by owner, id, order and limit, delete', () async {
      expect(store.canSyncRemote, isFalse);
      await store.upsert(_tx('old', date: DateTime(2026, 1, 1)));
      await store.upsert(_tx('new', date: DateTime(2026, 9, 1)));
      await store.upsert(_tx('mid', date: DateTime(2026, 5, 1)));
      await store.upsert(_tx('theirs', userId: 'local:other'));

      final newestFirst = await store.get<OfflineTransaction>(
        query: const RecordQuery(
          ownerId: _uid,
          orderBy: 'date',
          descending: true,
        ),
      );
      expect(newestFirst.map((t) => t.id), ['new', 'mid', 'old']);

      final oldest = await store.get<OfflineTransaction>(
        query: const RecordQuery(ownerId: _uid, orderBy: 'date', limit: 1),
      );
      expect(oldest.single.id, 'old');

      final byId = await store.get<OfflineTransaction>(
        query: const RecordQuery(ownerId: _uid, id: 'mid'),
      );
      expect(byId.single.date, DateTime(2026, 5, 1));
      expect(await store.get<OfflineTransaction>(), hasLength(4));

      await store.delete(byId.single);
      expect(
        await store.get<OfflineTransaction>(
          query: const RecordQuery(ownerId: _uid),
        ),
        hasLength(2),
      );
    });

    test('collections are kept apart', () async {
      await store.upsert(_tx('same-id'));
      await store.upsert(_account('same-id'));

      expect(await store.get<OfflineTransaction>(), hasLength(1));
      expect((await store.get<OfflineAccount>()).single.name, 'same-id');
    });

    test('a batch spanning collections is applied together', () async {
      await store.upsert(_tx('old-leg'));
      final batch = RecordBatch()
        ..upsert(_tx('leg-out'))
        ..upsert(_tx('leg-in', accountId: 'bank'))
        ..upsert(_account('cash', name: 'Cash'))
        ..deleteById<OfflineTransaction>('old-leg', ownerId: _uid);

      await store.commit(batch);

      expect((await store.get<OfflineTransaction>()).map((t) => t.id).toSet(), {
        'leg-out',
        'leg-in',
      });
      expect((await store.get<OfflineAccount>()).single.name, 'Cash');
    });

    test('upsertBatch has no size limit on the device', () async {
      await store.upsertBatch([
        for (var i = 0; i < OfflineStore.maxBatchWrites + 1; i++) _tx('t$i'),
      ]);

      expect(
        await store.get<OfflineTransaction>(),
        hasLength(OfflineStore.maxBatchWrites + 1),
      );
    });
  });

  group('signed in: Firestore', () {
    late FakeFirebaseFirestore firestore;
    late LocalRecordStore local;
    late OfflineStore store;

    setUp(() async {
      firestore = FakeFirebaseFirestore();
      local = await openMemoryRecordStore();
      store = OfflineStore(
        local: local,
        firestore: firestore,
        signedInUserId: () => _uid,
      );
    });
    tearDown(() => local.close());

    CollectionReferenceRows rows(String collection) =>
        CollectionReferenceRows(firestore, collection);

    test(
      'writes go to the user\'s Firestore collection, not the device',
      () async {
        final record = _tx('t1');
        await store.upsert(record);
        await pumpEventQueue();

        expect(await rows('transactions').get(), [
          RecordCodecs.transactions.toRow(record),
        ]);
        expect(await local.rows('transactions'), isEmpty);
        final read = await store.get<OfflineTransaction>(
          query: const RecordQuery(ownerId: _uid, id: 't1'),
        );
        expect(read.single.amount, '10');
      },
    );

    test('reads for another owner return nothing', () async {
      await store.upsert(_tx('t1'));
      await pumpEventQueue();

      expect(
        await store.get<OfflineTransaction>(
          query: const RecordQuery(ownerId: 'local:someone'),
        ),
        isEmpty,
      );
    });

    test('order and limit are applied by the query', () async {
      await store.upsertBatch([
        _tx('a', date: DateTime(2026, 1, 1)),
        _tx('b', date: DateTime(2026, 3, 1)),
        _tx('c', date: DateTime(2026, 2, 1)),
      ]);
      await pumpEventQueue();

      final latest = await store.get<OfflineTransaction>(
        query: const RecordQuery(orderBy: 'date', descending: true, limit: 2),
      );
      expect(latest.map((t) => t.id), ['b', 'c']);
    });

    test(
      'a batch writes every document or, failing the owner check, none',
      () async {
        final good = RecordBatch()
          ..upsert(_tx('leg-out'))
          ..upsert(_tx('leg-in'))
          ..upsert(_account('cash'));
        await store.commit(good);
        await pumpEventQueue();
        expect(await rows('transactions').ids(), {'leg-out', 'leg-in'});
        expect(await rows('accounts').ids(), {'cash'});

        final mixed = RecordBatch()
          ..deleteById<OfflineTransaction>('leg-out', ownerId: _uid)
          ..upsert(_tx('foreign', userId: 'someone-else'));
        await expectLater(store.commit(mixed), throwsStateError);
        await pumpEventQueue();
        expect(await rows('transactions').ids(), {'leg-out', 'leg-in'});
      },
    );

    test('a batch over the Firestore limit is refused unless chunks are '
        'allowed', () async {
      final big = RecordBatch();
      for (var i = 0; i < OfflineStore.maxBatchWrites + 1; i++) {
        big.upsert(_tx('t$i'));
      }

      await expectLater(store.commit(big), throwsArgumentError);
      await store.commit(big, allowChunks: true);
      await pumpEventQueue();
      expect(
        await rows('transactions').ids(),
        hasLength(OfflineStore.maxBatchWrites + 1),
      );
    });

    test('writes never wait for the server', () async {
      final pending = Completer<void>();
      final handedOff = OfflineStore.acceptWrite(pending.future);
      await handedOff.timeout(const Duration(milliseconds: 100));
      expect(pending.isCompleted, isFalse);
      pending.complete();
    });

    test('a later server failure is reported on errors', () async {
      final reported = <Object>[];
      final rejected = <Object>[];
      final subscription = OfflineStore.errors.stream.listen(reported.add);
      addTearDown(subscription.cancel);
      final write = Completer<void>();

      await OfflineStore.acceptWrite(write.future, onError: rejected.add);
      write.completeError(StateError('permission-denied'));
      await pumpEventQueue();

      expect(reported, [isA<StateError>()]);
      expect(rejected, [isA<StateError>()]);
    });

    test('localOnly reads and writes reach the device store', () async {
      await store.upsert(_tx('cloud'));
      await store.commit(
        RecordBatch()..upsert(_tx('guest', userId: 'local:guest')),
        localOnly: true,
      );

      final guest = await store.get<OfflineTransaction>(localOnly: true);
      expect(guest.single.id, 'guest');
      await store.delete(guest.single, localOnly: true);
      expect(await local.rows('transactions'), isEmpty);
    });
  });
}

/// Reads the signed-in user's documents of one collection.
class CollectionReferenceRows {
  CollectionReferenceRows(this.firestore, this.collection);

  final FakeFirebaseFirestore firestore;
  final String collection;

  Future<List<Map<String, dynamic>>> get() async {
    final snapshot = await firestore
        .collection('users')
        .doc(_uid)
        .collection(collection)
        .get();
    return [for (final doc in snapshot.docs) doc.data()];
  }

  Future<Set<String>> ids() async => {
    for (final row in await get()) row['id'] as String,
  };
}
