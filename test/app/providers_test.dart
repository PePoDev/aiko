import 'package:aiko/app/locale_controller.dart';
import 'package:aiko/app/providers.dart';
import 'package:aiko/core/money/money.dart';
import 'package:aiko/core/storage/secure_storage_service.dart';
import 'package:aiko/core/offline/offline_store.dart';
import 'package:aiko/features/accounts/data/account_repository.dart';
import 'package:aiko/features/accounts/domain/account.dart';
import 'package:aiko/features/categories/data/category_group_repository.dart';
import 'package:aiko/features/categories/data/category_repository.dart';
import 'package:aiko/features/categories/domain/category.dart';
import 'package:aiko/features/categories/domain/category_defaults.dart';
import 'package:aiko/features/transactions/data/transaction_repository.dart';
import 'package:aiko/features/transactions/domain/transaction.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'transactions notifier reconciles existing account current balance',
    () async {
      final accountRepository = _FakeAccountRepository([
        Account(
          id: 'saving',
          userId: 'user',
          name: 'eSaving',
          type: AccountType.bank,
          currentBalance: Money.parse('5000', 'THB'),
        ),
      ]);
      final transactionRepository = _FakeTransactionRepository([
        FinanceTransaction(
          id: 'initial',
          userId: 'user',
          accountId: 'saving',
          type: TransactionType.income,
          amount: Money.parse('5000', 'THB'),
          date: DateTime(2026, 5, 1),
        ),
        FinanceTransaction(
          id: 'dining',
          userId: 'user',
          accountId: 'saving',
          type: TransactionType.expense,
          amount: Money.parse('45', 'THB'),
          date: DateTime(2026, 5, 2),
        ),
        FinanceTransaction(
          id: 'bubble-tea',
          userId: 'user',
          accountId: 'saving',
          type: TransactionType.expense,
          amount: Money.parse('75', 'THB'),
          date: DateTime(2026, 5, 3),
        ),
      ]);
      final container = ProviderContainer(
        overrides: [
          accountRepositoryProvider.overrideWithValue(accountRepository),
          transactionRepositoryProvider.overrideWithValue(
            transactionRepository,
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(transactionsProvider.future);

      expect(
        accountRepository.accounts.single.currentBalance.amount.toString(),
        '4880',
      );
    },
  );

  test('transactions notifier syncs account current balance', () async {
    final accountRepository = _FakeAccountRepository([
      Account(
        id: 'cash',
        userId: 'user',
        name: 'Cash',
        type: AccountType.cash,
        currentBalance: Money.parse('100', 'USD'),
      ),
    ]);
    final transactionRepository = _FakeTransactionRepository();
    final container = ProviderContainer(
      overrides: [
        accountRepositoryProvider.overrideWithValue(accountRepository),
        transactionRepositoryProvider.overrideWithValue(transactionRepository),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(transactionsProvider.notifier)
        .saveTransaction(
          FinanceTransaction(
            id: 'coffee',
            userId: 'user',
            accountId: 'cash',
            type: TransactionType.expense,
            amount: Money.parse('25', 'USD'),
            date: DateTime(2026, 6, 7),
          ),
        );

    expect(
      accountRepository.accounts.single.currentBalance.amount.toString(),
      '75',
    );

    await container
        .read(transactionsProvider.notifier)
        .deleteTransaction('coffee');

    expect(
      accountRepository.accounts.single.currentBalance.amount.toString(),
      '100',
    );
  });

  test('deleting an account deletes its transactions too', () async {
    final accountRepository = _FakeAccountRepository([
      Account(
        id: 'old',
        userId: 'user',
        name: 'Old wallet',
        type: AccountType.cash,
        currentBalance: Money.parse('70', 'THB'),
      ),
      Account(
        id: 'bank',
        userId: 'user',
        name: 'Bank',
        type: AccountType.bank,
        currentBalance: Money.parse('500', 'THB'),
      ),
    ]);
    FinanceTransaction tx(String id, String accountId, String amount) =>
        FinanceTransaction(
          id: id,
          userId: 'user',
          accountId: accountId,
          type: TransactionType.income,
          amount: Money.parse(amount, 'THB'),
          date: DateTime(2026, 10, 1),
        );
    final transactionRepository = _FakeTransactionRepository([
      tx('old-1', 'old', '50'),
      tx('old-2', 'old', '20'),
      tx('bank-1', 'bank', '500'),
    ]);
    final container = ProviderContainer(
      overrides: [
        accountRepositoryProvider.overrideWithValue(accountRepository),
        transactionRepositoryProvider.overrideWithValue(transactionRepository),
      ],
    );
    addTearDown(container.dispose);
    await container.read(accountsProvider.future);

    final deleted = await container
        .read(accountsProvider.notifier)
        .deleteAccount('old');

    expect(deleted.map((transaction) => transaction.id), ['old-1', 'old-2']);
    expect(
      (await transactionRepository.list()).map((transaction) => transaction.id),
      ['bank-1'],
    );
    expect(accountRepository.accounts.map((account) => account.id), ['bank']);
    expect(
      (await container.read(
        accountsProvider.future,
      )).map((account) => account.id),
      ['bank'],
    );
  });

  group('category lookups', () {
    const userId = '11111111-1111-4111-8111-111111111111';
    const archived = Category(
      id: 'dddddddd-0000-4000-8000-000000000001',
      userId: userId,
      name: 'Old hobby',
      type: CategoryType.expense,
      group: CategoryBudgetGroup.custom,
      isActive: false,
    );
    const custom = Category(
      id: 'dddddddd-0000-4000-8000-000000000002',
      userId: userId,
      name: 'Plants',
      type: CategoryType.expense,
      group: CategoryBudgetGroup.custom,
    );

    test('deleted custom categories stay available for lookups', () async {
      final container = ProviderContainer(
        overrides: [
          categoryRepositoryProvider.overrideWithValue(
            _FakeCategoryRepository(userId, [archived, custom]),
          ),
          categoryGroupRepositoryProvider.overrideWithValue(
            _FakeCategoryGroupRepository(userId),
          ),
        ],
      );
      addTearDown(container.dispose);

      final active = await container.read(categoriesProvider.future);
      final all = await container.read(allCategoriesProvider.future);

      expect(
        active.map((category) => category.id),
        isNot(contains(archived.id)),
      );
      expect(active.map((category) => category.id), contains(custom.id));
      expect(all, hasLength(active.length + 1));
      expect(all.last.id, archived.id);
    });

    test('withArchivedCategories adds only archived custom rows', () {
      final archivedDefault = CategoryDefaults.cloneForUser(
        userId: userId,
        template: CategoryDefaults.all.first,
      ).copyWith(isActive: false);

      final all = withArchivedCategories(
        [custom],
        [custom, archived, archivedDefault],
      );

      expect(all.map((category) => category.id), [custom.id, archived.id]);
    });
  });

  group('transfer pairs', () {
    FinanceTransaction leg(
      String id,
      String accountId,
      TransactionType type, {
      String? groupId = 'pair-1',
    }) => FinanceTransaction(
      id: id,
      userId: 'user',
      accountId: accountId,
      type: type,
      amount: Money.parse('300', 'THB'),
      date: DateTime(2026, 10, 3),
      transferGroupId: groupId,
    );

    ProviderContainer containerFor(
      _FakeAccountRepository accounts,
      _FakeTransactionRepository transactions,
    ) {
      final container = ProviderContainer(
        overrides: [
          accountRepositoryProvider.overrideWithValue(accounts),
          transactionRepositoryProvider.overrideWithValue(transactions),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    List<Account> twoAccounts() => [
      Account(
        id: 'checking',
        userId: 'user',
        name: 'Checking',
        type: AccountType.bank,
        currentBalance: Money.parse('1000', 'THB'),
      ),
      Account(
        id: 'savings',
        userId: 'user',
        name: 'Savings',
        type: AccountType.bank,
        currentBalance: Money.parse('0', 'THB'),
      ),
    ];

    String balanceOf(_FakeAccountRepository repo, String id) => repo.accounts
        .singleWhere((account) => account.id == id)
        .currentBalance
        .amount
        .toString();

    test('deleting one linked leg deletes its partner and restores both '
        'balances', () async {
      final accounts = _FakeAccountRepository(twoAccounts());
      final container = containerFor(accounts, _FakeTransactionRepository());
      await container.read(transactionsProvider.future);
      final notifier = container.read(transactionsProvider.notifier);

      await notifier.saveTransactions([
        leg('out', 'checking', TransactionType.transferOut),
        leg('in', 'savings', TransactionType.transferIn),
      ]);
      expect(balanceOf(accounts, 'checking'), '700');
      expect(balanceOf(accounts, 'savings'), '300');

      final deleted = await notifier.deleteTransaction('in');

      expect(deleted.toSet(), {'in', 'out'});
      expect(container.read(transactionsProvider).value, isEmpty);
      expect(balanceOf(accounts, 'checking'), '1000');
      expect(balanceOf(accounts, 'savings'), '0');
    });

    test('an unlinked legacy leg is deleted on its own', () async {
      final accounts = _FakeAccountRepository(twoAccounts());
      final container = containerFor(
        accounts,
        _FakeTransactionRepository([
          leg('out', 'checking', TransactionType.transferOut, groupId: null),
          leg('in', 'savings', TransactionType.transferIn, groupId: null),
        ]),
      );
      await container.read(transactionsProvider.future);

      final deleted = await container
          .read(transactionsProvider.notifier)
          .deleteTransaction('out');

      expect(deleted, ['out']);
      expect(container.read(transactionsProvider).value!.map((t) => t.id), [
        'in',
      ]);
    });

    test('editing a pair updates both legs in place', () async {
      final accounts = _FakeAccountRepository(twoAccounts());
      final container = containerFor(accounts, _FakeTransactionRepository());
      await container.read(transactionsProvider.future);
      final notifier = container.read(transactionsProvider.notifier);
      final out = leg('out', 'checking', TransactionType.transferOut);
      final inLeg = leg('in', 'savings', TransactionType.transferIn);
      await notifier.saveTransactions([out, inLeg]);

      final bigger = Money.parse('450', 'THB');
      await notifier.saveTransactions([
        out.copyWith(amount: bigger),
        inLeg.copyWith(amount: bigger),
      ]);

      final rows = container.read(transactionsProvider).value!;
      expect(rows, hasLength(2));
      expect(rows.every((row) => row.amount == bigger), isTrue);
      expect(balanceOf(accounts, 'checking'), '550');
      expect(balanceOf(accounts, 'savings'), '450');
    });
  });

  test('saving never drops the list to a loading state', () async {
    final container = ProviderContainer(
      overrides: [
        accountRepositoryProvider.overrideWithValue(
          _FakeAccountRepository(const []),
        ),
        transactionRepositoryProvider.overrideWithValue(
          _FakeTransactionRepository([
            FinanceTransaction(
              id: 'old',
              userId: 'user',
              accountId: 'cash',
              type: TransactionType.expense,
              amount: Money.parse('10', 'THB'),
              date: DateTime(2026, 10, 1),
            ),
          ]),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(transactionsProvider.future);
    final states = <AsyncValue<List<FinanceTransaction>>>[];
    container.listen(
      transactionsProvider,
      (_, next) => states.add(next),
      fireImmediately: false,
    );

    await container
        .read(transactionsProvider.notifier)
        .saveTransaction(
          FinanceTransaction(
            id: 'new',
            userId: 'user',
            accountId: 'cash',
            type: TransactionType.expense,
            amount: Money.parse('20', 'THB'),
            date: DateTime(2026, 10, 5),
          ),
        );

    expect(states.any((state) => state.isLoading), isFalse);
    expect(container.read(transactionsProvider).value!.map((t) => t.id), [
      'new',
      'old',
    ]);
  });

  test('a failed save keeps the previous list and rethrows', () async {
    final existing = FinanceTransaction(
      id: 'old',
      userId: 'user',
      accountId: 'cash',
      type: TransactionType.expense,
      amount: Money.parse('10', 'THB'),
      date: DateTime(2026, 10, 1),
    );
    final container = ProviderContainer(
      overrides: [
        accountRepositoryProvider.overrideWithValue(
          _FakeAccountRepository(const []),
        ),
        transactionRepositoryProvider.overrideWithValue(
          _FailingTransactionRepository([existing]),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(transactionsProvider.future);

    await expectLater(
      container
          .read(transactionsProvider.notifier)
          .saveTransaction(existing.copyWith(amount: Money.parse('5', 'THB'))),
      throwsStateError,
    );
    await expectLater(
      container.read(transactionsProvider.notifier).deleteTransaction('old'),
      throwsStateError,
    );

    final state = container.read(transactionsProvider);
    expect(state.hasError, isFalse);
    expect(state.value, [existing]);
  });

  test('monthly report covers the requested month', () async {
    const userId = 'local:report-user';
    final container = ProviderContainer(
      overrides: [
        appLocaleControllerProvider.overrideWith(
          () => AppLocaleController(storage: MemorySecureStorageService()),
        ),
        accountRepositoryProvider.overrideWithValue(
          _FakeAccountRepository(const []),
        ),
        categoryRepositoryProvider.overrideWithValue(
          _FakeCategoryRepository(userId),
        ),
        categoryGroupRepositoryProvider.overrideWithValue(
          _FakeCategoryGroupRepository(userId),
        ),
        transactionRepositoryProvider.overrideWithValue(
          _FakeTransactionRepository([
            FinanceTransaction(
              id: 'may-pay',
              userId: userId,
              accountId: 'cash',
              type: TransactionType.income,
              amount: Money.parse('500', 'THB'),
              date: DateTime(2026, 5, 10),
            ),
            FinanceTransaction(
              id: 'june-pay',
              userId: userId,
              accountId: 'cash',
              type: TransactionType.income,
              amount: Money.parse('900', 'THB'),
              date: DateTime(2026, 6, 10),
            ),
            FinanceTransaction(
              id: 'opening',
              userId: userId,
              accountId: 'cash',
              type: TransactionType.adjustment,
              amount: Money.parse('10000', 'THB'),
              date: DateTime(2026, 5, 1),
            ),
          ]),
        ),
      ],
    );
    addTearDown(container.dispose);

    final may = await container.read(
      monthlyReportProvider(DateTime(2026, 5)).future,
    );
    final june = await container.read(
      monthlyReportProvider(DateTime(2026, 6)).future,
    );

    // The opening-balance adjustment is not income.
    expect(may.income, Money.parse('500', 'THB'));
    expect(june.income, Money.parse('900', 'THB'));
  });

  group('default category clones', () {
    const userId = '11111111-1111-4111-8111-111111111111';

    test(
      'derives complete authenticated clones when storage is empty',
      () async {
        final container = ProviderContainer(
          overrides: [
            categoryRepositoryProvider.overrideWithValue(
              _FakeCategoryRepository(userId),
            ),
            categoryGroupRepositoryProvider.overrideWithValue(
              _FakeCategoryGroupRepository(userId),
            ),
          ],
        );
        addTearDown(container.dispose);

        final categories = await container.read(categoriesProvider.future);
        final groups = await container.read(categoryGroupsProvider.future);

        expect(
          categories.where((category) => category.isDefault),
          hasLength(81),
        );
        expect(groups.where((group) => group.isDefault), hasLength(13));
        expect(
          categories.every(
            (category) => !category.isDefault || category.userId == userId,
          ),
          isTrue,
        );
      },
    );

    test('stored clone wins over a legacy fixed-id budget row', () async {
      final template = CategoryDefaults.all.singleWhere(
        (category) => category.id == CategoryDefaults.coffeeId,
      );
      final clone = CategoryDefaults.cloneForUser(
        userId: userId,
        template: template,
      ).copyWith(monthlyLimit: Money.parse('200', 'THB'));
      final legacy = template.copyWith(
        userId: userId,
        monthlyLimit: Money.parse('100', 'THB'),
      );
      final container = ProviderContainer(
        overrides: [
          categoryRepositoryProvider.overrideWithValue(
            _FakeCategoryRepository(userId, [legacy, clone]),
          ),
          categoryGroupRepositoryProvider.overrideWithValue(
            _FakeCategoryGroupRepository(userId),
          ),
        ],
      );
      addTearDown(container.dispose);

      final categories = await container.read(categoriesProvider.future);
      final coffee = categories.singleWhere(
        (category) => category.templateId == CategoryDefaults.coffeeId,
      );

      expect(coffee.monthlyLimit!.amount.toString(), '200');
      expect(
        categories.where(
          (category) =>
              category.effectiveTemplateId == CategoryDefaults.coffeeId,
        ),
        hasLength(1),
      );
    });

    test('keeps anonymous defaults on fixed template ids', () async {
      const localUserId = 'local:test-user';
      final container = ProviderContainer(
        overrides: [
          categoryRepositoryProvider.overrideWithValue(
            _FakeCategoryRepository(localUserId),
          ),
          categoryGroupRepositoryProvider.overrideWithValue(
            _FakeCategoryGroupRepository(localUserId),
          ),
        ],
      );
      addTearDown(container.dispose);

      final categories = await container.read(categoriesProvider.future);
      final groups = await container.read(categoryGroupsProvider.future);

      expect(
        categories.singleWhere((category) => category.name == 'Coffee').id,
        CategoryDefaults.coffeeId,
      );
      expect(groups.first.templateId, isNull);
    });
  });
}

class _FakeAccountRepository extends AccountRepository {
  _FakeAccountRepository(this.accounts);

  List<Account> accounts;

  @override
  Future<List<Account>> list() async => accounts;

  @override
  Future<void> delete(String id, {RecordBatch? batch}) async {
    accounts = [
      for (final account in accounts)
        if (account.id != id) account,
    ];
  }

  @override
  Future<Account> save(Account account, {RecordBatch? batch}) async {
    final index = accounts.indexWhere((item) => item.id == account.id);
    if (index == -1) {
      accounts = [...accounts, account];
    } else {
      accounts = [
        for (var i = 0; i < accounts.length; i++)
          if (i == index) account else accounts[i],
      ];
    }
    return account;
  }
}

class _FakeTransactionRepository extends TransactionRepository {
  _FakeTransactionRepository([List<FinanceTransaction>? transactions])
    : _transactions = transactions ?? [];

  final List<FinanceTransaction> _transactions;

  @override
  Future<List<FinanceTransaction>> list() async => _transactions;

  @override
  Future<FinanceTransaction> save(
    FinanceTransaction transaction, {
    RecordBatch? batch,
  }) async {
    final index = _transactions.indexWhere((item) => item.id == transaction.id);
    if (index == -1) {
      _transactions.add(transaction);
    } else {
      _transactions[index] = transaction;
    }
    return transaction;
  }

  @override
  Future<void> delete(String id, {RecordBatch? batch}) async {
    _transactions.removeWhere((item) => item.id == id);
  }
}

/// Lists fine but every write fails, like a broken offline store.
class _FailingTransactionRepository extends TransactionRepository {
  _FailingTransactionRepository(this._transactions);

  final List<FinanceTransaction> _transactions;

  @override
  Future<List<FinanceTransaction>> list() async => List.of(_transactions);

  @override
  Future<FinanceTransaction> save(
    FinanceTransaction transaction, {
    RecordBatch? batch,
  }) async => throw StateError('write failed');

  @override
  Future<void> delete(String id, {RecordBatch? batch}) async =>
      throw StateError('write failed');
}

class _FakeCategoryRepository extends CategoryRepository {
  _FakeCategoryRepository(this.userId, [this.categories = const []]);

  final String userId;
  final List<Category> categories;

  @override
  Future<String> currentUserId() async => userId;

  @override
  Future<List<Category>> list({String? userId}) async => categories;
}

class _FakeCategoryGroupRepository extends CategoryGroupRepository {
  _FakeCategoryGroupRepository(this.userId);

  final String userId;

  @override
  Future<String> currentUserId() async => userId;

  @override
  Future<List<CategoryGroup>> list({String? userId}) async => const [];
}
