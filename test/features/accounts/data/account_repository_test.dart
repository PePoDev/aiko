import 'package:aiko/core/money/money.dart';
import 'package:aiko/core/offline/offline_store.dart';
import 'package:aiko/core/storage/local_record_store.dart';
import 'package:aiko/features/accounts/data/account_repository.dart';
import 'package:aiko/features/accounts/domain/account.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../core/offline/record_store_harness.dart';

void main() {
  const userId = 'local:guest';
  late LocalRecordStore local;
  late OfflineStore store;
  late AccountRepository repository;

  setUp(() async {
    local = await openMemoryRecordStore();
    store = OfflineStore(local: local, signedInUserId: () => null);
    repository = AccountRepository(
      store: store,
      userContext: const FixedUserContext(userId),
    );
  });
  tearDown(() => local.close());

  Account account(String id, String name, {String balance = '0'}) => Account(
    id: id,
    userId: '',
    name: name,
    type: AccountType.bank,
    currentBalance: Money.parse(balance, 'THB'),
  );

  test('saves for the current owner and lists by name', () async {
    await repository.save(account('b', 'Savings'));
    await repository.save(account('a', 'Checking', balance: '-25.5'));
    await AccountRepository(
      store: store,
      userContext: const FixedUserContext('local:other'),
    ).save(account('c', 'Another'));

    final accounts = await repository.list();

    expect(accounts.map((a) => a.name), ['Checking', 'Savings']);
    expect(accounts.first.userId, userId);
    expect(accounts.first.currentBalance, Money.parse('-25.5', 'THB'));
  });

  test('archive keeps the account but marks it inactive', () async {
    await repository.save(account('a', 'Checking'));

    await repository.archive('a');

    expect((await repository.list()).single.isActive, isFalse);
  });

  test('with a batch, the save and delete land on commit', () async {
    await repository.save(account('old', 'Old'));
    final batch = RecordBatch();

    await repository.save(account('new', 'New'), batch: batch);
    await repository.delete('old', batch: batch);
    expect((await repository.list()).map((a) => a.id), ['old']);

    await store.commit(batch);
    expect((await repository.list()).map((a) => a.id), ['new']);
  });
}
