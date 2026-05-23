import 'package:aiko/app/providers.dart';
import 'package:aiko/core/money/money.dart';
import 'package:aiko/features/accounts/domain/account.dart';
import 'package:aiko/features/accounts/presentation/accounts_screen.dart';
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
    await tester.pumpWidget(_accountsApp(notifier));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.text('Add account'), findsWidgets);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Account Name'),
      'Travel Cash',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Opening Balance'),
      '120.50',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Create Account'));
    await tester.pumpAndSettle();

    expect(notifier.accounts.single.name, 'Travel Cash');
    expect(notifier.accounts.single.currentBalance.amount.toString(), '120.5');
    expect(find.text('Travel Cash'), findsOneWidget);
  });

  testWidgets('account item opens details, edits, and deletes', (tester) async {
    final notifier = _AccountsNotifier([_cashAccount()]);
    await tester.pumpWidget(_accountsApp(notifier));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cash Wallet'));
    await tester.pumpAndSettle();

    expect(find.text('Account details'), findsOneWidget);
    expect(find.text('Opening balance'), findsOneWidget);

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
}

Widget _accountsApp(_AccountsNotifier notifier) {
  return ProviderScope(
    overrides: [accountsProvider.overrideWith(() => notifier)],
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
