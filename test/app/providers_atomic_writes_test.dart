import 'package:aiko/app/providers.dart';
import 'package:aiko/core/money/money.dart';
import 'package:aiko/core/offline/offline_store.dart';
import 'package:aiko/core/offline/records/records.dart';
import 'package:aiko/core/storage/local_record_store.dart';
import 'package:aiko/features/accounts/data/account_repository.dart';
import 'package:aiko/features/accounts/domain/account.dart';
import 'package:aiko/features/accounts/domain/account_details.dart';
import 'package:aiko/features/categories/data/category_group_repository.dart';
import 'package:aiko/features/categories/data/category_repository.dart';
import 'package:aiko/features/categories/domain/category.dart';
import 'package:aiko/features/transactions/data/transaction_repository.dart';
import 'package:aiko/features/transactions/domain/transaction.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../core/offline/record_store_harness.dart';

/// Multi-record changes go to the store as one batch each, so they land
/// together or not at all (one Firestore WriteBatch signed in, one SQLite
/// transaction otherwise).
void main() {
  const owner = 'local:guest';
  const userContext = FixedUserContext(owner);
  late LocalRecordStore local;
  late RecordingStore store;
  late ProviderContainer container;

  setUp(() async {
    local = await openMemoryRecordStore();
    store = RecordingStore(local);
    container = ProviderContainer(
      overrides: [
        offlineStoreProvider.overrideWithValue(store),
        accountRepositoryProvider.overrideWithValue(
          AccountRepository(store: store, userContext: userContext),
        ),
        transactionRepositoryProvider.overrideWithValue(
          TransactionRepository(store: store, userContext: userContext),
        ),
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

  Account account(String id, String balance, {AccountDetails? details}) =>
      Account(
        id: id,
        userId: owner,
        name: id,
        type: details == null ? AccountType.bank : AccountType.creditCard,
        currentBalance: Money.parse(balance, 'THB'),
        details: details,
      );

  FinanceTransaction leg(String id, String accountId, TransactionType type) =>
      FinanceTransaction(
        id: id,
        userId: owner,
        accountId: accountId,
        type: type,
        amount: Money.parse('300', 'THB'),
        date: DateTime(2026, 10, 3),
        transferGroupId: 'pair-1',
      );

  Future<void> seed({
    List<Account> accounts = const [],
    List<FinanceTransaction> transactions = const [],
  }) async {
    final batch = RecordBatch();
    for (final a in accounts) {
      batch.upsert(a.toOffline(userId: owner));
    }
    for (final t in transactions) {
      batch.upsert(t.toOffline(userId: owner));
    }
    await store.commit(batch);
    store.commits.clear();
  }

  Future<Map<String, String>> storedBalances() async => {
    for (final a in await store.get<OfflineAccount>()) a.id: a.currentBalance,
  };

  List<String> describe(RecordBatch batch) => [
    for (final write in batch.writes)
      '${write.isDelete ? 'delete' : 'put'} ${write.collection}/${write.id}',
  ];

  test('a transfer and both balances are one batch', () async {
    await seed(
      accounts: [account('checking', '1000'), account('savings', '0')],
    );
    await container.read(transactionsProvider.future);

    await container.read(transactionsProvider.notifier).saveTransactions([
      leg('out', 'checking', TransactionType.transferOut),
      leg('in', 'savings', TransactionType.transferIn),
    ]);

    expect(store.commits, hasLength(1));
    expect(describe(store.commits.single), [
      'put transactions/out',
      'put transactions/in',
      'put accounts/checking',
      'put accounts/savings',
    ]);
    expect(await storedBalances(), {'checking': '700', 'savings': '300'});
    final shown = container.read(accountsProvider).value!;
    expect(shown.map((a) => a.currentBalance.amount.toString()), [
      '700',
      '300',
    ]);
  });

  test('a failed transfer writes nothing and keeps what is shown', () async {
    await seed(
      accounts: [account('checking', '1000'), account('savings', '0')],
    );
    await container.read(transactionsProvider.future);
    store.failCommits = true;

    await expectLater(
      container.read(transactionsProvider.notifier).saveTransactions([
        leg('out', 'checking', TransactionType.transferOut),
        leg('in', 'savings', TransactionType.transferIn),
      ]),
      throwsStateError,
    );

    expect(await store.get<OfflineTransaction>(), isEmpty);
    expect(await storedBalances(), {'checking': '1000', 'savings': '0'});
    expect(container.read(transactionsProvider).value, isEmpty);
    expect(
      container
          .read(accountsProvider)
          .value!
          .map((a) => a.currentBalance.amount.toString()),
      ['1000', '0'],
    );
  });

  test('deleting a transfer leg removes both legs and restores balances in '
      'one batch', () async {
    await seed(
      // Balances as the ledger gives them, so loading changes nothing.
      accounts: [account('checking', '-300'), account('savings', '300')],
      transactions: [
        leg('out', 'checking', TransactionType.transferOut),
        leg('in', 'savings', TransactionType.transferIn),
      ],
    );
    await container.read(transactionsProvider.future);
    store.commits.clear();

    final deleted = await container
        .read(transactionsProvider.notifier)
        .deleteTransaction('in');

    expect(deleted.toSet(), {'in', 'out'});
    expect(describe(store.commits.single), [
      'delete transactions/in',
      'delete transactions/out',
      'put accounts/checking',
      'put accounts/savings',
    ]);
    expect(await store.get<OfflineTransaction>(), isEmpty);
    expect(await storedBalances(), {'checking': '0', 'savings': '0'});
  });

  test('a new account and its opening balance are one batch', () async {
    await container.read(accountsProvider.future);
    await container.read(transactionsProvider.future);
    final created = account('wallet', '250');

    await container
        .read(accountsProvider.notifier)
        .saveAccount(
          created,
          adjustment: FinanceTransaction(
            id: 'opening',
            userId: owner,
            accountId: 'wallet',
            type: TransactionType.adjustment,
            amount: created.currentBalance,
            date: DateTime(2026, 10, 3),
          ),
        );

    expect(describe(store.commits.single), [
      'put accounts/wallet',
      'put transactions/opening',
    ]);
    // The adjustment backs the balance; it doesn't add to it again.
    expect(await storedBalances(), {'wallet': '250'});
    expect(container.read(transactionsProvider).value!.map((t) => t.id), [
      'opening',
    ]);
    expect(container.read(accountsProvider).value!.single.id, 'wallet');
  });

  test('deleting an account takes its transactions and releases shared '
      'limits in one batch', () async {
    await seed(
      accounts: [
        account(
          'card',
          '-100',
          details: const CreditCardDetails(statementDay: 1, dueDay: 20),
        ),
        account(
          'second-card',
          '0',
          details: const CreditCardDetails(
            statementDay: 1,
            dueDay: 20,
            sharesLimit: true,
            sharedLimitAccountId: 'card',
          ),
        ),
      ],
      transactions: [
        FinanceTransaction(
          id: 'coffee',
          userId: owner,
          accountId: 'card',
          type: TransactionType.expense,
          amount: Money.parse('100', 'THB'),
          date: DateTime(2026, 10, 1),
        ),
      ],
    );
    await container.read(accountsProvider.future);
    store.commits.clear();

    final deleted = await container
        .read(accountsProvider.notifier)
        .deleteAccount('card');

    expect(deleted.map((t) => t.id), ['coffee']);
    expect(describe(store.commits.single), [
      'delete transactions/coffee',
      'put accounts/second-card',
      'delete accounts/card',
    ]);
    final remaining = container.read(accountsProvider).value!.single;
    expect(remaining.id, 'second-card');
    expect(
      (remaining.resolvedDetails as CreditCardDetails).sharesLimit,
      isFalse,
    );
    expect(await store.get<OfflineTransaction>(), isEmpty);
  });

  test('deleting a group ungroups its categories in the same batch', () async {
    final categories = CategoryRepository(
      store: store,
      userContext: userContext,
    );
    final groups = CategoryGroupRepository(
      store: store,
      userContext: userContext,
    );
    await groups.save(
      const CategoryGroup(id: 'treats', userId: owner, name: 'Treats'),
    );
    for (final id in ['cake', 'candy']) {
      await categories.save(
        Category(
          id: id,
          userId: owner,
          name: id,
          type: CategoryType.expense,
          group: CategoryBudgetGroup.custom,
          groupId: 'treats',
        ),
      );
    }
    container.listen(categoryGroupsProvider, (_, _) {});
    await container.read(categoryGroupsProvider.future);
    store.commits.clear();

    await container.read(categoryGroupsProvider.notifier).deleteGroup('treats');

    expect(describe(store.commits.single).toSet(), {
      'put categories/cake',
      'put categories/candy',
      'delete category_groups/treats',
    });
    expect(
      (await store.get<OfflineCategory>()).every((c) => c.groupId == null),
      isTrue,
    );
    expect(await store.get<OfflineCategoryGroup>(), isEmpty);
  });

  test('legacy opening balances are rewritten in one batch', () async {
    FinanceTransaction opening(String id, String accountId) =>
        FinanceTransaction(
          id: id,
          userId: owner,
          accountId: accountId,
          type: TransactionType.income,
          amount: Money.parse('500', 'THB'),
          date: DateTime(2026, 1, 1),
          merchant: 'Initial balance',
          note: 'Created from account starting balance',
        );
    await seed(
      accounts: [account('a', '500'), account('b', '500')],
      transactions: [opening('open-a', 'a'), opening('open-b', 'b')],
    );

    final loaded = await container.read(transactionsProvider.future);

    expect(loaded.every((t) => t.type == TransactionType.adjustment), isTrue);
    expect(describe(store.commits.single), [
      'put transactions/open-a',
      'put transactions/open-b',
    ]);
    expect((await store.get<OfflineTransaction>()).map((t) => t.type).toSet(), {
      'adjustment',
    });
  });
}
