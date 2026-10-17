import 'package:aiko/app/providers.dart';
import 'package:aiko/core/money/money.dart';
import 'package:aiko/core/offline/offline_store.dart';
import 'package:aiko/features/accounts/data/account_repository.dart';
import 'package:aiko/features/accounts/domain/account.dart';
import 'package:aiko/features/categories/data/category_group_repository.dart';
import 'package:aiko/features/categories/data/category_repository.dart';
import 'package:aiko/features/categories/domain/category.dart';
import 'package:aiko/features/transactions/data/transaction_repository.dart';
import 'package:aiko/features/transactions/domain/transaction.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'reconciling replays each account\'s own transactions and saves only changed balances',
    () async {
      Account account(String id, String currency, String balance) => Account(
        id: id,
        userId: 'user',
        name: id,
        type: AccountType.bank,
        currentBalance: Money.parse(balance, currency),
      );
      FinanceTransaction tx(
        String id,
        String accountId,
        TransactionType type,
        String amount,
        String currency,
      ) => FinanceTransaction(
        id: id,
        userId: 'user',
        accountId: accountId,
        type: type,
        amount: Money.parse(amount, currency),
        date: DateTime(2026, 5, 1),
      );
      final accounts = _Accounts([
        account('thb', 'THB', '0'),
        account('usd', 'USD', '10'),
        account('untouched', 'THB', '999'),
        account('settled', 'THB', '20'),
      ]);
      final container = ProviderContainer(
        overrides: [
          accountRepositoryProvider.overrideWithValue(accounts),
          transactionRepositoryProvider.overrideWithValue(
            _Transactions([
              tx('a', 'thb', TransactionType.income, '100', 'THB'),
              tx('b', 'usd', TransactionType.income, '50', 'USD'),
              tx('c', 'thb', TransactionType.expense, '30', 'THB'),
              tx('d', 'deleted-account', TransactionType.expense, '7', 'THB'),
              tx('e', 'usd', TransactionType.expense, '5', 'USD'),
              tx('f', 'settled', TransactionType.income, '20', 'THB'),
            ]),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(transactionsProvider.future);

      String balance(String id) => accounts.accounts
          .singleWhere((a) => a.id == id)
          .currentBalance
          .amount
          .toString();
      expect(balance('thb'), '70');
      expect(balance('usd'), '45');
      expect(balance('untouched'), '999');
      expect(balance('settled'), '20');
      expect(accounts.saved, ['thb', 'usd']);
    },
  );

  test('deleting a group ungroups all of its categories', () async {
    const userId = '11111111-1111-4111-8111-111111111111';
    Category category(String id, String? groupId) => Category(
      id: id,
      userId: userId,
      name: id,
      type: CategoryType.expense,
      group: CategoryBudgetGroup.wants,
      groupId: groupId,
    );
    final categories = _Categories(userId, [
      category('coffee', 'treats'),
      category('cake', 'treats'),
      category('rent', 'home'),
    ]);
    final groups = _Groups(userId, const [
      CategoryGroup(id: 'treats', userId: userId, name: 'Treats'),
    ]);
    final container = ProviderContainer(
      overrides: [
        categoryRepositoryProvider.overrideWithValue(categories),
        categoryGroupRepositoryProvider.overrideWithValue(groups),
      ],
    );
    addTearDown(container.dispose);
    container.listen(categoryGroupsProvider, (_, _) {});
    await container.read(categoryGroupsProvider.future);

    await container.read(categoryGroupsProvider.notifier).deleteGroup('treats');

    expect(groups.deleted, ['treats']);
    expect(
      categories.saved.map((c) => c.id),
      unorderedEquals(['coffee', 'cake']),
    );
    expect(categories.saved.every((c) => c.groupId == null), isTrue);
  });
}

class _Accounts extends AccountRepository {
  _Accounts(this.accounts);

  List<Account> accounts;
  final List<String> saved = [];

  @override
  Future<List<Account>> list() async => accounts;

  @override
  Future<Account> save(Account account, {RecordBatch? batch}) async {
    saved.add(account.id);
    accounts = [
      for (final item in accounts) item.id == account.id ? account : item,
    ];
    return account;
  }
}

class _Transactions extends TransactionRepository {
  _Transactions(this.transactions);

  final List<FinanceTransaction> transactions;

  @override
  Future<List<FinanceTransaction>> list() async => transactions;
}

class _Categories extends CategoryRepository {
  _Categories(this.userId, this.categories);

  final String userId;
  final List<Category> categories;
  final List<Category> saved = [];

  @override
  Future<String> currentUserId() async => userId;

  @override
  Future<List<Category>> list({String? userId}) async => categories;

  @override
  Future<Category> save(Category category, {RecordBatch? batch}) async {
    saved.add(category);
    return category;
  }
}

class _Groups extends CategoryGroupRepository {
  _Groups(this.userId, this.groups);

  final String userId;
  final List<CategoryGroup> groups;
  final List<String> deleted = [];

  @override
  Future<String> currentUserId() async => userId;

  @override
  Future<List<CategoryGroup>> list({String? userId}) async => groups
      .where((group) => !deleted.contains(group.id))
      .toList(growable: false);

  @override
  Future<void> delete(String id, {RecordBatch? batch}) async => deleted.add(id);
}
