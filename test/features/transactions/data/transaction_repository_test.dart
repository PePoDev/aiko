import 'package:aiko/core/money/money.dart';
import 'package:aiko/core/offline/offline_store.dart';
import 'package:aiko/core/offline/records/records.dart';
import 'package:aiko/core/storage/local_record_store.dart';
import 'package:aiko/features/categories/domain/category_defaults.dart';
import 'package:aiko/features/transactions/data/transaction_repository.dart';
import 'package:aiko/features/transactions/domain/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../core/offline/record_store_harness.dart';

void main() {
  const userId = '11111111-1111-4111-8111-111111111111';
  late LocalRecordStore local;
  late OfflineStore store;

  setUp(() async {
    local = await openMemoryRecordStore();
    store = OfflineStore(local: local, signedInUserId: () => null);
  });
  tearDown(() => local.close());

  TransactionRepository repository(String owner) =>
      TransactionRepository(store: store, userContext: FixedUserContext(owner));

  FinanceTransaction coffee({String id = 'transaction', String? owner}) =>
      FinanceTransaction(
        id: id,
        userId: owner ?? userId,
        accountId: 'account',
        type: TransactionType.expense,
        amount: Money.parse('10', 'THB'),
        date: DateTime(2026, 7, 26),
        categoryId: CategoryDefaults.coffeeId,
      );

  test('authenticated reads map fixed category ids to clones', () async {
    await store.upsert(
      OfflineTransaction(
        id: 'transaction',
        userId: userId,
        accountId: 'account',
        type: 'expense',
        amount: '10',
        currency: 'THB',
        date: DateTime(2026, 7, 26),
        categoryId: CategoryDefaults.coffeeId,
      ),
    );

    final transaction = (await repository(userId).list()).single;

    expect(
      transaction.categoryId,
      CategoryDefaults.cloneIdForUser(
        userId: userId,
        templateId: CategoryDefaults.coffeeId,
      ),
    );
  });

  test('authenticated saves persist clone category ids', () async {
    await repository(userId).save(coffee());

    expect(
      (await store.get<OfflineTransaction>()).single.categoryId,
      CategoryDefaults.cloneIdForUser(
        userId: userId,
        templateId: CategoryDefaults.coffeeId,
      ),
    );
  });

  test('anonymous saves retain fixed template ids', () async {
    await repository('local:test-user').save(coffee(owner: 'local:test-user'));

    expect(
      (await store.get<OfflineTransaction>()).single.categoryId,
      CategoryDefaults.coffeeId,
    );
  });

  test('lists only the owner\'s rows, newest first', () async {
    final mine = repository(userId);
    await mine.save(coffee(id: 'older').copyWith(date: DateTime(2026, 1, 1)));
    await mine.save(coffee(id: 'newer'));
    await repository('local:other').save(coffee(id: 'theirs'));

    expect((await mine.list()).map((t) => t.id), ['newer', 'older']);
  });

  test('with a batch, saves and deletes wait for the commit', () async {
    final repo = repository(userId);
    await repo.save(coffee(id: 'old'));
    final batch = RecordBatch();

    final saved = await repo.save(coffee(id: 'new'), batch: batch);
    await repo.delete('old', batch: batch);

    expect(saved.userId, userId);
    expect((await repo.list()).map((t) => t.id), ['old']);
    await store.commit(batch);
    expect((await repo.list()).map((t) => t.id), ['new']);
  });

  test('another owner\'s row is not deleted', () async {
    await repository('local:other').save(coffee(owner: 'local:other'));

    await repository(userId).delete('transaction');

    expect(await store.get<OfflineTransaction>(), hasLength(1));
  });

  test('an invalid amount is rejected before anything is staged', () async {
    final batch = RecordBatch();
    await expectLater(
      repository(
        userId,
      ).save(coffee().copyWith(amount: Money.parse('0', 'THB')), batch: batch),
      throwsArgumentError,
    );
    expect(batch.isEmpty, isTrue);
  });
}
