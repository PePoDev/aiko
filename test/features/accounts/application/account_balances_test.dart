import 'package:aiko/core/money/money.dart';
import 'package:aiko/features/accounts/application/account_balances.dart';
import 'package:aiko/features/accounts/domain/account.dart';
import 'package:aiko/features/transactions/domain/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

Account _account(
  String id,
  String balance, {
  AccountType type = AccountType.bank,
  String currency = 'THB',
  bool isActive = true,
  bool includeInNetWorth = true,
}) => Account(
  id: id,
  userId: 'user',
  name: id,
  type: type,
  currentBalance: Money.parse(balance, currency),
  isActive: isActive,
  includeInNetWorth: includeInNetWorth,
);

FinanceTransaction _tx(
  String id,
  String accountId,
  TransactionType type,
  String amount,
) => FinanceTransaction(
  id: id,
  userId: 'user',
  accountId: accountId,
  type: type,
  amount: Money.parse(amount, 'THB'),
  date: DateTime(2026, 10, 1),
);

void main() {
  group('currentAccountBalances', () {
    test('sums each ledger once and keeps the stored balance without one', () {
      final accounts = [_account('bank', '999'), _account('cash', '250')];
      final balances = currentAccountBalances(accounts, [
        _tx('salary', 'bank', TransactionType.income, '1000'),
        _tx('rent', 'bank', TransactionType.expense, '400'),
        _tx('ghost', 'deleted-account', TransactionType.income, '50'),
      ]);

      expect(balances['bank']!.amount.toString(), '600');
      expect(balances['cash']!.amount.toString(), '250');
      expect(balances.containsKey('deleted-account'), isFalse);
    });
  });

  group('summarizeAccounts', () {
    test('net worth matches the Overview: active, non-goal, included', () {
      final accounts = [
        _account('bank', '1000'),
        _account('card', '-300', type: AccountType.creditCard),
        _account('goal', '5000', type: AccountType.goal),
        _account('closed', '700', isActive: false),
        _account('hidden', '200', includeInNetWorth: false),
        _account('usd', '50', currency: 'USD'),
      ];
      final summary = summarizeAccounts(
        accounts: accounts,
        balances: currentAccountBalances(accounts, const []),
        baseCurrency: 'THB',
      );

      expect(summary.netWorth!.amount.toString(), '700');
      expect(summary.assets!.amount.toString(), '1000');
      expect(summary.liabilities!.amount.toString(), '300');
      expect(
        summary.assets! - summary.liabilities!,
        summary.netWorth,
        reason: 'assets − liabilities reconciles with net worth',
      );
      // The headline total still lists every base-currency account.
      expect(summary.total!.amount.toString(), '6600');
    });

    test('figures are null when no account contributes', () {
      final accounts = [
        _account('goal', '10', type: AccountType.goal),
        _account('usd', '50', currency: 'USD'),
      ];
      final summary = summarizeAccounts(
        accounts: accounts,
        balances: currentAccountBalances(accounts, const []),
        baseCurrency: 'THB',
      );

      expect(summary.netWorth, isNull);
      expect(summary.assets, isNull);
      expect(summary.liabilities, isNull);
    });

    test('countsTowardNetWorth leaves out goals and inactive accounts', () {
      expect(countsTowardNetWorth(_account('bank', '1')), isTrue);
      expect(
        countsTowardNetWorth(_account('goal', '1', type: AccountType.goal)),
        isFalse,
      );
      expect(
        countsTowardNetWorth(_account('closed', '1', isActive: false)),
        isFalse,
      );
      expect(
        countsTowardNetWorth(_account('hidden', '1', includeInNetWorth: false)),
        isFalse,
      );
    });
  });

  test('sumBalancesInCurrency skips other currencies', () {
    final accounts = [
      _account('a', '10'),
      _account('b', '5'),
      _account('usd', '7', currency: 'USD'),
    ];
    final total = sumBalancesInCurrency(
      accounts: accounts,
      balances: currentAccountBalances(accounts, [
        _tx('spend', 'a', TransactionType.expense, '4'),
      ]),
      baseCurrency: 'thb',
    );

    expect(total!.amount.toString(), '1');
  });
}
