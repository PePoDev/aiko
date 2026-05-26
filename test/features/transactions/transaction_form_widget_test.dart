import 'package:aiko/app/providers.dart';
import 'package:aiko/core/money/money.dart';
import 'package:aiko/features/accounts/domain/account.dart';
import 'package:aiko/features/categories/domain/category.dart';
import 'package:aiko/features/transactions/data/transaction_repository.dart';
import 'package:aiko/features/transactions/domain/transaction.dart';
import 'package:aiko/features/transactions/presentation/transaction_form_screen.dart';
import 'package:aiko/l10n/app_localizations.dart';
import 'package:aiko/theme/aiko_colors.dart';
import 'package:aiko/theme/aiko_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('transaction form starts with segmented type selector', (
    tester,
  ) async {
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

    expect(find.byKey(const Key('transaction-type-selector')), findsOneWidget);
    expect(find.byType(SegmentedButton<String>), findsOneWidget);
    expect(find.text('Expense'), findsOneWidget);
    expect(find.text('Income'), findsOneWidget);
    expect(find.text('Transfer'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Item name'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Title'), findsNothing);
    expect(find.widgetWithText(TextField, 'Amount'), findsOneWidget);

    final typeSelectorTop = tester
        .getTopLeft(find.byKey(const Key('transaction-type-selector')))
        .dy;
    final titleTop = tester
        .getTopLeft(find.widgetWithText(TextField, 'Item name'))
        .dy;
    expect(typeSelectorTop, lessThan(titleTop));
  });

  testWidgets('transaction type selector switches to transfer controls', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          categoriesProvider.overrideWith(() => _EmptyCategoriesNotifier()),
          accountsProvider.overrideWith(
            () => _AccountsNotifier([
              Account(
                id: 'cash',
                userId: 'user',
                name: 'Cash',
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
    await tester.tap(find.text('Transfer'));
    await tester.pumpAndSettle();

    expect(find.text('From Account'), findsOneWidget);
    expect(find.text('To Account'), findsOneWidget);
    expect(
      find.byKey(const Key('transaction-from-account-picker')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('transaction-to-account-picker')),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(DropdownMenu<String>, 'From Account'),
      findsNothing,
    );
    expect(
      find.widgetWithText(DropdownMenu<String>, 'To Account'),
      findsNothing,
    );
  });

  testWidgets('transaction type selector uses semantic selected colors', (
    tester,
  ) async {
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

    expect(_selectedSelectorColor(tester), AikoColors.dangerRed);

    await tester.tap(find.text('Income'));
    await tester.pumpAndSettle();
    expect(_selectedSelectorColor(tester), AikoColors.successGreen);

    await tester.tap(find.text('Transfer'));
    await tester.pumpAndSettle();
    expect(_selectedSelectorColor(tester), AikoColors.primaryBlue);
  });

  testWidgets('transaction type selector keeps segment icons when selected', (
    tester,
  ) async {
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

    final selector = tester.widget<SegmentedButton<String>>(
      find.byKey(const Key('transaction-type-selector')),
    );
    expect(selector.showSelectedIcon, isFalse);
  });

  testWidgets('category options follow selected transaction type', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          categoriesProvider.overrideWith(
            () => _CategoriesNotifier([
              _category('groceries', 'Groceries', CategoryType.expense),
              _category('salary', 'Salary', CategoryType.income),
              _category('move', 'Move Money', CategoryType.transfer),
            ]),
          ),
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

    expect(
      find.byKey(const Key('transaction-category-picker')),
      findsOneWidget,
    );
    expect(find.widgetWithText(DropdownMenu<String>, 'Category'), findsNothing);

    await _openCategoryPicker(tester);
    expect(find.text('Groceries'), findsOneWidget);
    expect(find.text('Salary'), findsNothing);
    await _closeCategoryPicker(tester);

    await tester.tap(find.text('Income'));
    await tester.pumpAndSettle();
    await _openCategoryPicker(tester);
    expect(find.text('Salary'), findsOneWidget);
    expect(find.text('Groceries'), findsNothing);
    await _closeCategoryPicker(tester);

    await tester.tap(find.text('Transfer'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(DropdownMenu<String>, 'Category'), findsNothing);
    expect(find.byKey(const Key('transaction-category-picker')), findsNothing);
  });

  testWidgets('category picker shows selected category as a designed tile', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          categoriesProvider.overrideWith(
            () => _CategoriesNotifier([
              _category(
                'groceries',
                'Groceries',
                CategoryType.expense,
                group: CategoryGroup.needs,
                icon: 'food',
                color: '#F97316',
              ),
            ]),
          ),
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

    expect(
      find.byKey(const Key('transaction-category-picker')),
      findsOneWidget,
    );
    expect(find.text('Select category'), findsOneWidget);
    expect(find.byIcon(Icons.restaurant_outlined), findsNothing);

    await _selectCategory(tester, 'groceries');

    expect(find.text('Groceries'), findsOneWidget);
    expect(find.text('Needs'), findsOneWidget);
    expect(find.byIcon(Icons.restaurant_outlined), findsOneWidget);
  });

  testWidgets('account picker shows selected account as a designed tile', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          categoriesProvider.overrideWith(() => _EmptyCategoriesNotifier()),
          accountsProvider.overrideWith(
            () => _AccountsNotifier([
              Account(
                id: 'cash',
                userId: 'user',
                name: 'Cash',
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

    expect(find.byKey(const Key('transaction-account-picker')), findsOneWidget);
    expect(find.text('Select account'), findsOneWidget);
    expect(find.widgetWithText(DropdownMenu<String>, 'Account'), findsNothing);
    expect(find.byIcon(Icons.wallet_outlined), findsOneWidget);

    await _selectAccount(tester, 'cash');

    expect(find.text('Cash'), findsOneWidget);
    expect(find.text('Cash wallet'), findsOneWidget);
    expect(find.text(r'$0.00'), findsOneWidget);
  });

  testWidgets('transfer type hides category field and empty category message', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          categoriesProvider.overrideWith(() => _CategoriesNotifier([])),
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
    await tester.tap(find.text('Transfer'));
    await tester.pumpAndSettle();

    expect(find.text('No categories available'), findsNothing);
    expect(find.widgetWithText(DropdownMenu<String>, 'Category'), findsNothing);
    expect(find.byKey(const Key('transaction-category-picker')), findsNothing);
  });

  testWidgets(
    'changing transaction type clears the visible category selection',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            categoriesProvider.overrideWith(
              () => _CategoriesNotifier([
                _category('groceries', 'Groceries', CategoryType.expense),
                _category('salary', 'Salary', CategoryType.income),
              ]),
            ),
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
      await _selectCategory(tester, 'groceries');

      expect(find.text('Groceries'), findsOneWidget);

      await tester.tap(find.text('Income'));
      await tester.pumpAndSettle();

      expect(find.text('Groceries'), findsNothing);
    },
  );

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

  testWidgets('amount field calculator applies keypad expression', (
    tester,
  ) async {
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
    await tester.tap(find.byKey(const Key('amount-calculator-button')));
    await tester.pumpAndSettle();

    expect(find.text('Amount calculator'), findsOneWidget);
    await tester.tap(find.byKey(const Key('calculator-key-4')));
    await tester.tap(find.byKey(const Key('calculator-key-multiply')));
    await tester.tap(find.byKey(const Key('calculator-key-3')));
    await tester.tap(find.byKey(const Key('calculator-key-decimal')));
    await tester.tap(find.byKey(const Key('calculator-key-5')));
    await tester.tap(find.byKey(const Key('calculator-key-equals')));
    await tester.pumpAndSettle();

    expect(find.text('14.00 THB'), findsOneWidget);
    await tester.tap(find.byKey(const Key('apply-calculated-amount-button')));
    await tester.pumpAndSettle();

    final amountField = tester.widget<TextField>(
      find.byKey(const Key('transaction-amount-field')),
    );
    expect(amountField.controller?.text, '14.00');
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

    await _selectAccount(tester, 'usd-wallet');

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

  testWidgets('item name input suggests existing item names on focus', (
    tester,
  ) async {
    final repository = _FakeTransactionRepository([
      _transaction(merchant: 'Coffee Beans'),
      _transaction(id: 'tx-2', merchant: 'Monthly Rent'),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          transactionRepositoryProvider.overrideWithValue(repository),
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
    await tester.tap(find.widgetWithText(TextField, 'Item name'));
    await tester.pumpAndSettle();

    expect(find.text('Coffee Beans'), findsOneWidget);
    expect(find.text('Monthly Rent'), findsOneWidget);

    await tester.tap(find.text('Coffee Beans').last);
    await tester.pumpAndSettle();

    final itemField = tester.widget<TextField>(
      find.widgetWithText(TextField, 'Item name'),
    );
    expect(itemField.controller?.text, 'Coffee Beans');
  });

  testWidgets('tag input suggests existing tags and saves chips', (
    tester,
  ) async {
    final repository = _FakeTransactionRepository([
      _transaction(tags: const ['coffee', 'work']),
      _transaction(id: 'tx-2', tags: const ['cashback']),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          transactionRepositoryProvider.overrideWithValue(repository),
          categoriesProvider.overrideWith(() => _EmptyCategoriesNotifier()),
          accountsProvider.overrideWith(
            () => _AccountsNotifier([
              Account(
                id: 'cash',
                userId: 'user',
                name: 'Cash',
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
    await tester.enterText(
      find.widgetWithText(TextField, 'Item name'),
      'Coffee',
    );
    await tester.enterText(
      find.byKey(const Key('transaction-amount-field')),
      '4.50',
    );
    await _selectAccount(tester, 'cash');
    await tester.scrollUntilVisible(
      find.byKey(const Key('transaction-tags-field')),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(
      find.byKey(const Key('transaction-tags-field')),
      'co',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('coffee').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('transaction-tags-field')),
      'work',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('transaction-tags-field')),
      'reimbursable,',
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('transaction-tag-chip-coffee')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('transaction-tag-chip-work')), findsOneWidget);
    expect(
      find.byKey(const Key('transaction-tag-chip-reimbursable')),
      findsOneWidget,
    );

    final saveButton = find.widgetWithText(FilledButton, 'Save Transaction');
    await tester.ensureVisible(saveButton);
    await tester.pumpAndSettle();
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(repository.savedTransaction?.tags, [
      'coffee',
      'work',
      'reimbursable',
    ]);
  });

  testWidgets('blank item name saves selected category name as merchant', (
    tester,
  ) async {
    final repository = _FakeTransactionRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          transactionRepositoryProvider.overrideWithValue(repository),
          categoriesProvider.overrideWith(
            () => _CategoriesNotifier([
              _category('groceries', 'Groceries', CategoryType.expense),
            ]),
          ),
          accountsProvider.overrideWith(
            () => _AccountsNotifier([
              Account(
                id: 'cash',
                userId: 'user',
                name: 'Cash',
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
    await tester.enterText(
      find.byKey(const Key('transaction-amount-field')),
      '4.50',
    );
    await _selectCategory(tester, 'groceries');
    await _selectAccount(tester, 'cash');

    final saveButton = find.widgetWithText(FilledButton, 'Save Transaction');
    await tester.scrollUntilVisible(
      saveButton,
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(repository.savedTransaction?.merchant, 'Groceries');
  });

  testWidgets('blank income item name saves selected income category name', (
    tester,
  ) async {
    final repository = _FakeTransactionRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          transactionRepositoryProvider.overrideWithValue(repository),
          categoriesProvider.overrideWith(
            () => _CategoriesNotifier([
              _category('groceries', 'Groceries', CategoryType.expense),
              _category('salary', 'Salary', CategoryType.income),
            ]),
          ),
          accountsProvider.overrideWith(
            () => _AccountsNotifier([
              Account(
                id: 'cash',
                userId: 'user',
                name: 'Cash',
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
    await tester.tap(find.text('Income'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('transaction-amount-field')),
      '1000',
    );
    await _selectCategory(tester, 'salary');
    await _selectAccount(tester, 'cash');

    final saveButton = find.widgetWithText(FilledButton, 'Save Transaction');
    await tester.scrollUntilVisible(
      saveButton,
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(repository.savedTransaction?.type, TransactionType.income);
    expect(repository.savedTransaction?.categoryId, 'salary');
    expect(repository.savedTransaction?.merchant, 'Salary');
  });

  testWidgets('income category fallback works after switching from expense', (
    tester,
  ) async {
    final repository = _FakeTransactionRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          transactionRepositoryProvider.overrideWithValue(repository),
          categoriesProvider.overrideWith(
            () => _CategoriesNotifier([
              _category('groceries', 'Groceries', CategoryType.expense),
              _category('salary', 'Salary', CategoryType.income),
            ]),
          ),
          accountsProvider.overrideWith(
            () => _AccountsNotifier([
              Account(
                id: 'cash',
                userId: 'user',
                name: 'Cash',
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
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AikoTheme.light(),
          home: const TransactionFormScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await _selectCategory(tester, 'groceries');
    await tester.tap(find.text('Income'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('transaction-amount-field')),
      '1000',
    );
    await _selectCategory(tester, 'salary');
    await _selectAccount(tester, 'cash');

    final saveButton = find.widgetWithText(FilledButton, 'Save Transaction');
    await tester.scrollUntilVisible(
      saveButton,
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(repository.savedTransaction?.type, TransactionType.income);
    expect(repository.savedTransaction?.categoryId, 'salary');
    expect(repository.savedTransaction?.merchant, 'Salary');
  });

  testWidgets('note field is multiline for longer notes', (tester) async {
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
    await tester.scrollUntilVisible(
      find.byKey(const Key('transaction-note-field')),
      240,
      scrollable: find.byType(Scrollable).first,
    );

    final noteField = tester.widget<TextField>(
      find.byKey(const Key('transaction-note-field')),
    );
    expect(noteField.minLines, 3);
    expect(noteField.maxLines, 4);
  });
}

Color? _selectedSelectorColor(WidgetTester tester) {
  final selector = tester.widget<SegmentedButton<String>>(
    find.byKey(const Key('transaction-type-selector')),
  );
  return selector.style?.backgroundColor?.resolve({WidgetState.selected});
}

Future<void> _openCategoryPicker(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('transaction-category-picker')));
  await tester.pumpAndSettle();
}

Future<void> _closeCategoryPicker(WidgetTester tester) async {
  await tester.tapAt(const Offset(8, 8));
  await tester.pumpAndSettle();
}

Future<void> _selectCategory(WidgetTester tester, String categoryId) async {
  await _openCategoryPicker(tester);
  await tester.tap(find.byKey(Key('transaction-category-option-$categoryId')));
  await tester.pumpAndSettle();
}

Future<void> _openAccountPicker(
  WidgetTester tester, {
  String field = 'account',
}) async {
  final picker = find.byKey(Key('transaction-$field-picker'));
  if (!tester.any(picker)) {
    await tester.scrollUntilVisible(
      picker,
      120,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.tap(picker);
  await tester.pumpAndSettle();
}

Future<void> _selectAccount(
  WidgetTester tester,
  String accountId, {
  String field = 'account',
}) async {
  await _openAccountPicker(tester, field: field);
  await tester.tap(find.byKey(Key('transaction-$field-option-$accountId')));
  await tester.pumpAndSettle();
}

class _EmptyCategoriesNotifier extends CategoriesNotifier {
  @override
  Future<List<Category>> build() async => const [];
}

class _CategoriesNotifier extends CategoriesNotifier {
  _CategoriesNotifier(this.categories);

  final List<Category> categories;

  @override
  Future<List<Category>> build() async => categories;
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

class _FakeTransactionRepository extends TransactionRepository {
  _FakeTransactionRepository([List<FinanceTransaction>? transactions])
    : _transactions = transactions ?? [];

  final List<FinanceTransaction> _transactions;
  FinanceTransaction? savedTransaction;

  @override
  Future<List<FinanceTransaction>> list() async {
    return savedTransaction == null
        ? _transactions
        : [..._transactions, savedTransaction!];
  }

  @override
  Future<FinanceTransaction> save(FinanceTransaction transaction) async {
    savedTransaction = transaction;
    return transaction;
  }
}

Category _category(
  String id,
  String name,
  CategoryType type, {
  CategoryGroup group = CategoryGroup.custom,
  String icon = 'category',
  String color = '#3B82F6',
}) {
  return Category(
    id: id,
    userId: 'user',
    name: name,
    type: type,
    group: group,
    icon: icon,
    color: color,
  );
}

FinanceTransaction _transaction({
  String id = 'tx-1',
  String? merchant,
  List<String> tags = const [],
}) {
  return FinanceTransaction(
    id: id,
    userId: 'user',
    accountId: 'cash',
    type: TransactionType.expense,
    amount: Money.parse('1', 'USD'),
    date: DateTime(2026, 1, 1),
    merchant: merchant,
    tags: tags,
  );
}
