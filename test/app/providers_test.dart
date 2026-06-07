import 'package:aiko/app/providers.dart';
import 'package:aiko/core/money/money.dart';
import 'package:aiko/features/accounts/data/account_repository.dart';
import 'package:aiko/features/accounts/domain/account.dart';
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
