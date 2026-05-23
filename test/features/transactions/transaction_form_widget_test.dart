import 'package:aiko/app/providers.dart';
import 'package:aiko/core/money/money.dart';
import 'package:aiko/features/accounts/domain/account.dart';
import 'package:aiko/features/categories/domain/category.dart';
import 'package:aiko/features/transactions/presentation/transaction_form_screen.dart';
import 'package:aiko/l10n/app_localizations.dart';
import 'package:aiko/theme/aiko_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('transaction form has title and amount fields', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          categoriesProvider.overrideWith(() => _EmptyCategoriesNotifier()),
          accountsProvider.overrideWith(() => _EmptyAccountsNotifier()),
        ],
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AikoTheme.light(),
          home: const TransactionFormScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final textFields = find.byType(TextField);
    expect(textFields, findsWidgets);

    // Check for Title field (first field)
    expect(find.widgetWithText(TextField, 'Title'), findsOneWidget);

    // Check for Amount field
    expect(find.widgetWithText(TextField, 'Amount'), findsOneWidget);
  });

  testWidgets('smart entry tools are app bar actions', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          categoriesProvider.overrideWith(() => _EmptyCategoriesNotifier()),
          accountsProvider.overrideWith(() => _EmptyAccountsNotifier()),
        ],
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AikoTheme.light(),
          home: const TransactionFormScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Aiko Smart Entry Tools'), findsNothing);
    expect(find.byTooltip('Smart entry tools'), findsNothing);
    expect(find.byTooltip('Scan receipt'), findsOneWidget);
    expect(find.byTooltip('Voice entry'), findsOneWidget);
  });

  testWidgets('amount currency can convert to selected account currency', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          categoriesProvider.overrideWith(() => _EmptyCategoriesNotifier()),
          accountsProvider.overrideWith(
            () => _AccountsNotifier([
              Account(
                id: 'usd-wallet',
                userId: 'user',
                name: 'USD Wallet',
                type: AccountType.cash,
                openingBalance: Money.zero('USD'),
                currentBalance: Money.zero('USD'),
              ),
            ]),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AikoTheme.light(),
          home: const TransactionFormScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Currency'), findsOneWidget);
    expect(find.text('THB'), findsOneWidget);

    await tester.tap(find.widgetWithText(DropdownMenu<String>, 'Account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('USD Wallet').last);
    await tester.pumpAndSettle();

    expect(find.text('Convert to USD?'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('transaction-amount-field')),
      '100',
    );
    await tester.enterText(
      find.byKey(const Key('transaction-exchange-rate-field')),
      '0.03',
    );
    await tester.drag(find.byType(ListView), const Offset(0, -240));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('convert-currency-button')).first);
    await tester.pumpAndSettle();

    final amountField = tester.widget<TextField>(
      find.byKey(const Key('transaction-amount-field'), skipOffstage: false),
    );
    expect(amountField.controller?.text, '3.00');
    expect(find.text('Convert to USD?'), findsNothing);
  });
}

class _EmptyCategoriesNotifier extends CategoriesNotifier {
  @override
  Future<List<Category>> build() async => const [];
}

class _EmptyAccountsNotifier extends AccountsNotifier {
  @override
  Future<List<Account>> build() async => const [];
}

class _AccountsNotifier extends AccountsNotifier {
  _AccountsNotifier(this.accounts);

  final List<Account> accounts;

  @override
  Future<List<Account>> build() async => accounts;
}
