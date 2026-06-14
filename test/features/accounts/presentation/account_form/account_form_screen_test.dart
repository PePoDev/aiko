import 'package:aiko/app/providers.dart';
import 'package:aiko/core/money/money.dart';
import 'package:aiko/features/accounts/domain/account.dart';
import 'package:aiko/features/accounts/presentation/account_form/account_form_screen.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _StubAccountsNotifier extends AccountsNotifier {
  _StubAccountsNotifier(this._seed);
  final List<Account> _seed;
  @override
  Future<List<Account>> build() async => _seed;
  @override
  Future<void> saveAccount(Account account) async {}
  @override
  Future<void> addAccount(Account account) async {}
  @override
  Future<void> deleteAccount(String id) async {}
}

void main() {
  testWidgets('credit card subform renders for credit card account', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountsProvider.overrideWith(
            () => _StubAccountsNotifier([
              Account(
                id: 'a',
                userId: 'u',
                name: 'Wallet',
                type: AccountType.cash,
                currentBalance: Money.zero('USD'),
              ),
            ]),
          ),
        ],
        child: MaterialApp(
          home: AccountFormScreen(
            account: Account(
              id: 'b',
              userId: 'u',
              name: 'Visa',
              type: AccountType.creditCard,
              currentBalance: Money(amount: Decimal.zero, currency: 'USD'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Statement day (1-31)'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Statement day (1-31)'), findsOneWidget);
    expect(find.text('Due day (1-31)'), findsOneWidget);
    expect(find.text('Credit limit'), findsOneWidget);
  });

  testWidgets('app bar shows Add/Edit title based on account argument', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountsProvider.overrideWith(
            () => _StubAccountsNotifier(const []),
          ),
        ],
        child: const MaterialApp(home: AccountFormScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Add account'), findsOneWidget);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountsProvider.overrideWith(
            () => _StubAccountsNotifier(const []),
          ),
        ],
        child: MaterialApp(
          home: AccountFormScreen(
            account: Account(
              id: 'a',
              userId: 'u',
              name: 'Wallet',
              type: AccountType.bank,
              currentBalance: Money(amount: Decimal.zero, currency: 'USD'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Edit account'), findsOneWidget);
  });
}
