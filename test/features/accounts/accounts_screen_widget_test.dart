import 'package:aiko/app/providers.dart';
import 'package:aiko/core/money/money.dart';
import 'package:aiko/features/accounts/domain/account.dart';
import 'package:aiko/features/accounts/presentation/accounts_screen.dart';
import 'package:aiko/features/transactions/domain/transaction.dart';
import 'package:aiko/theme/aiko_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('accounts screen shows direct account list', (tester) async {
    await tester.pumpWidget(_accountsApp(_AccountsNotifier([_cashAccount()])));
    await tester.pumpAndSettle();

    expect(find.text('Accounts'), findsOneWidget);
    expect(find.text('Accounts & Bank Feeds'), findsNothing);
    expect(find.text('Live Bank Connection'), findsNothing);
    expect(find.text('Active Accounts Workspace'), findsNothing);
    expect(find.text('Add Account Manually'), findsNothing);
    expect(find.text('Cash Wallet'), findsOneWidget);
    expect(find.text('Cash wallet'), findsOneWidget);
    expect(find.text('\$25.00'), findsOneWidget);
  });

  testWidgets('floating action opens account creation popup', (tester) async {
    final notifier = _AccountsNotifier([]);
    final transactionsNotifier = _TransactionsNotifier();
    await tester.pumpWidget(_accountsApp(notifier, transactionsNotifier));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.text('Add account'), findsWidgets);
    expect(find.widgetWithText(TextFormField, 'Opening Balance'), findsNothing);
    expect(
      find.widgetWithText(TextFormField, 'Current Balance'),
      findsOneWidget,
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Account Name'),
      'Travel Cash',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Current Balance'),
      '120.50',
    );
    await tester.ensureVisible(
      find.widgetWithText(FilledButton, 'Create Account'),
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Create Account'));
    await tester.pumpAndSettle();

    expect(notifier.accounts.single.name, 'Travel Cash');
    expect(notifier.accounts.single.openingBalance.amount.toString(), '120.5');
    expect(notifier.accounts.single.currentBalance.amount.toString(), '120.5');
    expect(
      transactionsNotifier.transactions.single.accountId,
      notifier.accounts.single.id,
    );
    expect(
      transactionsNotifier.transactions.single.type,
      TransactionType.income,
    );
    expect(
      transactionsNotifier.transactions.single.amount.amount.toString(),
      '120.5',
    );
    expect(find.text('Travel Cash'), findsOneWidget);
    final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
    final margin = snackBar.margin as EdgeInsets?;
    expect(margin?.bottom, greaterThanOrEqualTo(88));
  });

  testWidgets('negative new account balance creates an expense transaction', (
    tester,
  ) async {
    final accountsNotifier = _AccountsNotifier([]);
    final transactionsNotifier = _TransactionsNotifier();
    await tester.pumpWidget(
      _accountsApp(accountsNotifier, transactionsNotifier),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Account Name'),
      'Card Balance',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Current Balance'),
      '-45.25',
    );
    await tester.ensureVisible(
      find.widgetWithText(FilledButton, 'Create Account'),
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Create Account'));
    await tester.pumpAndSettle();

    expect(
      accountsNotifier.accounts.single.currentBalance.amount.toString(),
      '-45.25',
    );
    expect(
      transactionsNotifier.transactions.single.type,
      TransactionType.expense,
    );
    expect(
      transactionsNotifier.transactions.single.amount.amount.toString(),
      '45.25',
    );
  });

  testWidgets('account item opens details, edits, and deletes', (tester) async {
    final notifier = _AccountsNotifier([_cashAccount()]);
    await tester.pumpWidget(_accountsApp(notifier));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cash Wallet'));
    await tester.pumpAndSettle();

    expect(find.text('Account details'), findsOneWidget);
    expect(find.text('Opening balance'), findsNothing);

    await tester.tap(find.byTooltip('Edit account'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Account Name'),
      'Pocket Cash',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Current Balance'),
      '40',
    );
    await tester.ensureVisible(
      find.widgetWithText(FilledButton, 'Save Changes'),
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save Changes'));
    await tester.pumpAndSettle();

    expect(notifier.accounts.single.name, 'Pocket Cash');
    expect(find.text('Pocket Cash'), findsOneWidget);
    expect(find.text('\$40.00'), findsOneWidget);

    await tester.tap(find.byTooltip('Delete account'));
    await tester.pumpAndSettle();
    expect(find.text('Delete account?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(notifier.accounts, isEmpty);
    expect(find.text('No accounts yet'), findsOneWidget);
  });

  testWidgets('account details balance is calculated from transactions', (
    tester,
  ) async {
    final accountsNotifier = _AccountsNotifier([
      Account(
        id: 'cash',
        userId: 'user',
        name: 'Cash Wallet',
        type: AccountType.cash,
        openingBalance: Money.zero('USD'),
        currentBalance: Money.zero('USD'),
      ),
    ]);
    final transactionsNotifier = _TransactionsNotifier([
      FinanceTransaction(
        id: 'income-50000',
        userId: 'user',
        accountId: 'cash',
        type: TransactionType.income,
        amount: Money.parse('50000', 'USD'),
        date: DateTime(2026, 5, 1),
      ),
      FinanceTransaction(
        id: 'expense-500-a',
        userId: 'user',
        accountId: 'cash',
        type: TransactionType.expense,
        amount: Money.parse('500', 'USD'),
        date: DateTime(2026, 5, 2),
      ),
      FinanceTransaction(
        id: 'expense-500-b',
        userId: 'user',
        accountId: 'cash',
        type: TransactionType.expense,
        amount: Money.parse('500', 'USD'),
        date: DateTime(2026, 5, 3),
      ),
      FinanceTransaction(
        id: 'income-200',
        userId: 'user',
        accountId: 'cash',
        type: TransactionType.income,
        amount: Money.parse('200', 'USD'),
        date: DateTime(2026, 5, 4),
      ),
    ]);

    await tester.pumpWidget(
      _accountsApp(accountsNotifier, transactionsNotifier),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cash Wallet'));
    await tester.pumpAndSettle();

    expect(find.text('\$0.00'), findsNothing);
    expect(find.text('\$49,200.00'), findsOneWidget);
  });

  testWidgets('account edit popup can edit every account model field', (
    tester,
  ) async {
    final notifier = _AccountsNotifier([
      Account(
        id: 'bank',
        userId: 'user',
        name: 'Old Checking',
        type: AccountType.bank,
        openingBalance: Money.parse('100', 'USD'),
        currentBalance: Money.parse('150', 'USD'),
        institution: 'Old Bank',
        includeInNetWorth: true,
        isActive: true,
      ),
    ]);

    await tester.pumpWidget(_accountsApp(notifier));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Old Checking'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Edit account'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Account Name'),
      'Updated Brokerage',
    );
    await tester.tap(
      find.widgetWithText(DropdownButtonFormField<AccountType>, 'Bank'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Investment').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Institution Name'),
      'Updated Broker',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Currency'),
      'EUR',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Current Balance'),
      '275.25',
    );
    await tester.ensureVisible(
      find.widgetWithText(SwitchListTile, 'Include in net worth'),
    );
    await tester.tap(
      find.widgetWithText(SwitchListTile, 'Include in net worth'),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.widgetWithText(SwitchListTile, 'Active account'),
    );
    await tester.tap(find.widgetWithText(SwitchListTile, 'Active account'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.widgetWithText(FilledButton, 'Save Changes'),
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save Changes'));
    await tester.pumpAndSettle();

    final account = notifier.accounts.single;
    expect(account.id, 'bank');
    expect(account.userId, 'user');
    expect(account.name, 'Updated Brokerage');
    expect(account.type, AccountType.investment);
    expect(account.openingBalance.amount.toString(), '275.25');
    expect(account.openingBalance.currency, 'EUR');
    expect(account.currentBalance.amount.toString(), '275.25');
    expect(account.currentBalance.currency, 'EUR');
    expect(account.institution, 'Updated Broker');
    expect(account.includeInNetWorth, isFalse);
    expect(account.isActive, isFalse);
    expect(find.text('Hidden'), findsOneWidget);
    expect(find.text('Inactive'), findsOneWidget);
  });
}

Widget _accountsApp(
  _AccountsNotifier notifier, [
  _TransactionsNotifier? transactionsNotifier,
]) {
  return ProviderScope(
    overrides: [
      accountsProvider.overrideWith(() => notifier),
      if (transactionsNotifier != null)
        transactionsProvider.overrideWith(() => transactionsNotifier),
    ],
    child: MaterialApp(theme: AikoTheme.light(), home: const AccountsScreen()),
  );
}

Account _cashAccount() {
  return Account(
    id: 'cash',
    userId: 'user',
    name: 'Cash Wallet',
    type: AccountType.cash,
    openingBalance: Money.zero('USD'),
    currentBalance: Money.parse('25', 'USD'),
  );
}

class _AccountsNotifier extends AccountsNotifier {
  _AccountsNotifier(this.accounts);

  List<Account> accounts;

  @override
  Future<List<Account>> build() async => accounts;

  @override
  Future<void> saveAccount(Account account) async {
    final index = accounts.indexWhere((item) => item.id == account.id);
    if (index == -1) {
      accounts = [...accounts, account];
    } else {
      accounts = [
        for (var i = 0; i < accounts.length; i++)
          if (i == index) account else accounts[i],
      ];
    }
    state = AsyncData(accounts);
  }

  @override
  Future<void> addAccount(Account account) => saveAccount(account);

  @override
  Future<void> deleteAccount(String id) async {
    accounts = [
      for (final account in accounts)
        if (account.id != id) account,
    ];
    state = AsyncData(accounts);
  }
}

class _TransactionsNotifier extends TransactionsNotifier {
  _TransactionsNotifier([List<FinanceTransaction>? initialTransactions])
    : transactions = initialTransactions ?? [];

  final List<FinanceTransaction> transactions;

  @override
  Future<List<FinanceTransaction>> build() async => transactions;

  @override
  Future<void> addTransaction(FinanceTransaction transaction) async {
    transactions.add(transaction);
    state = AsyncData(transactions);
  }
}
