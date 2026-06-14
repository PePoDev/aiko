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

  testWidgets('accounts screen groups accounts by account type', (
    tester,
  ) async {
    await tester.pumpWidget(
      _accountsApp(
        _AccountsNotifier([
          _account(
            id: 'checking',
            name: 'Everyday Checking',
            type: AccountType.bank,
          ),
          _account(id: 'cash', name: 'Pocket Cash', type: AccountType.cash),
          _account(
            id: 'visa',
            name: 'Visa Rewards',
            type: AccountType.creditCard,
          ),
          _account(id: 'loan', name: 'Student Loan', type: AccountType.loan),
          _account(
            id: 'savings',
            name: 'High Yield Savings',
            type: AccountType.bank,
          ),
        ]),
      ),
    );
    await tester.pumpAndSettle();

    // Account type headers include a count suffix (e.g. "Cash (1)"), so match
    // the full label rather than the bare type name.
    expect(find.text('Cash (1)'), findsOneWidget);
    expect(find.text('Bank (2)'), findsOneWidget);
    expect(find.text('Credit Card (1)'), findsOneWidget);
    expect(find.text('Loan (1)'), findsOneWidget);

    expect(
      tester.getTopLeft(find.text('Cash (1)')).dy,
      lessThan(tester.getTopLeft(find.text('Pocket Cash')).dy),
    );
    expect(
      tester.getTopLeft(find.text('Bank (2)')).dy,
      lessThan(tester.getTopLeft(find.text('Everyday Checking')).dy),
    );
    expect(
      tester.getTopLeft(find.text('Bank (2)')).dy,
      lessThan(tester.getTopLeft(find.text('High Yield Savings')).dy),
    );
    expect(
      tester.getTopLeft(find.text('Credit Card (1)')).dy,
      lessThan(tester.getTopLeft(find.text('Visa Rewards')).dy),
    );
  });

  testWidgets('app bar add action opens account creation popup', (
    tester,
  ) async {
    final notifier = _AccountsNotifier([]);
    final transactionsNotifier = _TransactionsNotifier();
    await tester.pumpWidget(_accountsApp(notifier, transactionsNotifier));
    await tester.pumpAndSettle();

    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.widgetWithText(TextButton, 'Add'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Add'));
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
    expect(find.widgetWithText(ListTile, 'Travel Cash'), findsOneWidget);
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

    await tester.tap(find.widgetWithText(TextButton, 'Add'));
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

  testWidgets('cash account form does not ask for institution name', (
    tester,
  ) async {
    final notifier = _AccountsNotifier([_cashAccount()]);
    await tester.pumpWidget(_accountsApp(notifier));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cash Wallet'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Edit account'));
    await tester.pumpAndSettle();

    expect(
      find.widgetWithText(TextFormField, 'Institution Name'),
      findsNothing,
    );

    await tester.tap(
      find.widgetWithText(DropdownButtonFormField<AccountType>, 'Cash'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bank').last);
    await tester.pumpAndSettle();

    if (find.text('Switch account type?').evaluate().isNotEmpty) {
      await tester.tap(find.text('Switch').last);
      await tester.pumpAndSettle();
    }

    expect(
      find.widgetWithText(TextFormField, 'Institution Name'),
      findsOneWidget,
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

  testWidgets('accounts reconcile current balance from transactions', (
    tester,
  ) async {
    final accountsNotifier = _AccountsNotifier([
      Account(
        id: 'saving',
        userId: 'user',
        name: 'eSaving',
        type: AccountType.bank,
        currentBalance: Money.parse('5000', 'THB'),
      ),
    ]);
    final transactionsNotifier = _TransactionsNotifier([
      FinanceTransaction(
        id: 'initial',
        userId: 'user',
        accountId: 'saving',
        type: TransactionType.income,
        amount: Money.parse('5000', 'THB'),
        date: DateTime(2026, 5, 1),
        merchant: 'Initial balance',
      ),
      FinanceTransaction(
        id: 'dining',
        userId: 'user',
        accountId: 'saving',
        type: TransactionType.expense,
        amount: Money.parse('45', 'THB'),
        date: DateTime(2026, 5, 2),
        merchant: 'Dining',
      ),
      FinanceTransaction(
        id: 'bubble-tea',
        userId: 'user',
        accountId: 'saving',
        type: TransactionType.expense,
        amount: Money.parse('75', 'THB'),
        date: DateTime(2026, 5, 3),
        merchant: 'Bubble Tea',
      ),
    ]);

    await tester.pumpWidget(
      _accountsApp(accountsNotifier, transactionsNotifier),
    );
    await tester.pumpAndSettle();

    expect(find.text('฿4,880.00'), findsOneWidget);
    expect(find.text('฿5,000.00'), findsNothing);

    await tester.tap(find.text('eSaving'));
    await tester.pumpAndSettle();

    expect(find.text('฿4,880.00'), findsOneWidget);
    expect(find.text('฿5,000.00'), findsNothing);
  });

  testWidgets('account details shows related transactions for that account', (
    tester,
  ) async {
    final accountsNotifier = _AccountsNotifier([
      Account(
        id: 'cash',
        userId: 'user',
        name: 'Cash Wallet',
        type: AccountType.cash,
        currentBalance: Money.zero('USD'),
      ),
      Account(
        id: 'bank',
        userId: 'user',
        name: 'Bank Account',
        type: AccountType.bank,
        currentBalance: Money.zero('USD'),
      ),
    ]);
    final transactionsNotifier = _TransactionsNotifier([
      FinanceTransaction(
        id: 'cash-coffee',
        userId: 'user',
        accountId: 'cash',
        type: TransactionType.expense,
        amount: Money.parse('4.50', 'USD'),
        date: DateTime(2026, 5, 3),
        merchant: 'Cafe',
      ),
      FinanceTransaction(
        id: 'cash-paycheck',
        userId: 'user',
        accountId: 'cash',
        type: TransactionType.income,
        amount: Money.parse('500', 'USD'),
        date: DateTime(2026, 5, 4),
        merchant: 'Paycheck',
      ),
      FinanceTransaction(
        id: 'bank-rent',
        userId: 'user',
        accountId: 'bank',
        type: TransactionType.expense,
        amount: Money.parse('900', 'USD'),
        date: DateTime(2026, 5, 5),
        merchant: 'Rent',
      ),
    ]);

    await tester.pumpWidget(
      _accountsApp(accountsNotifier, transactionsNotifier),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cash Wallet'));
    await tester.pumpAndSettle();

    expect(find.text('Related transactions'), findsOneWidget);
    expect(find.text('Cafe'), findsOneWidget);
    expect(find.text('Paycheck'), findsOneWidget);
    expect(find.text('Rent'), findsNothing);
    expect(find.text('-\$4.50'), findsOneWidget);
    expect(find.text('+\$500.00'), findsOneWidget);
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
    expect(find.widgetWithText(TextFormField, 'Currency'), findsNothing);
    expect(
      find.widgetWithText(DropdownMenu<String>, 'Currency'),
      findsOneWidget,
    );
    expect(find.text(r'$ '), findsNothing);
    expect(find.textContaining('USD'), findsWidgets);
    expect(find.text(r'$'), findsOneWidget);

    await tester.tap(find.widgetWithText(DropdownMenu<String>, 'Currency'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Currency'), 'eur');
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('EUR').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('EUR'), findsWidgets);
    expect(find.text('€'), findsOneWidget);
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
      transactionsProvider.overrideWith(
        () => transactionsNotifier ?? _TransactionsNotifier(),
      ),
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
    currentBalance: Money.parse('25', 'USD'),
  );
}

Account _account({
  required String id,
  required String name,
  required AccountType type,
}) {
  return Account(
    id: id,
    userId: 'user',
    name: name,
    type: type,
    currentBalance: Money.parse('10', 'USD'),
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
  Future<void> addTransaction(
    FinanceTransaction transaction, {
    bool updateAccountBalance = true,
  }) async {
    transactions.add(transaction);
    state = AsyncData(transactions);
  }
}
