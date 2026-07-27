import 'package:aiko/app/providers.dart';
import 'package:aiko/core/money/money.dart';
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
        .addTransaction(
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
  Future<Account> save(Account account) async {
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
  Future<FinanceTransaction> save(FinanceTransaction transaction) async {
    final index = _transactions.indexWhere((item) => item.id == transaction.id);
    if (index == -1) {
      _transactions.add(transaction);
    } else {
      _transactions[index] = transaction;
    }
    return transaction;
  }

  @override
  Future<void> delete(String id) async {
    _transactions.removeWhere((item) => item.id == id);
  }
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
