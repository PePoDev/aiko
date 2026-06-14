import 'package:aiko/app/providers.dart';
import 'package:aiko/core/money/money.dart';
import 'package:aiko/features/accounts/domain/account.dart';
import 'package:aiko/features/accounts/domain/account_type.dart';
import 'package:aiko/features/accounts/presentation/account_form/account_form_sheet.dart';
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
  testWidgets('selecting credit card reveals credit-card subform', (
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
        child: const MaterialApp(home: Scaffold(body: AccountFormSheet())),
      ),
    );
    await tester.pumpAndSettle();

    // Open the type dropdown and pick Credit Card
    await tester.tap(find.byType(DropdownButtonFormField<AccountType>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Credit Card').last);
    await tester.pumpAndSettle();

    // Confirm the type-change dialog
    if (find.text('Switch account type?').evaluate().isNotEmpty) {
      await tester.tap(find.text('Switch').last);
      await tester.pumpAndSettle();
    }

    expect(find.text('Statement day (1-31)'), findsOneWidget);
    expect(find.text('Due day (1-31)'), findsOneWidget);
    expect(find.text('Credit limit'), findsOneWidget);
  });
}
