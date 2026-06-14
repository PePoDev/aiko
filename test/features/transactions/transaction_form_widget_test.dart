import 'package:aiko/app/providers.dart';
import 'package:aiko/core/money/money.dart';
import 'package:aiko/features/accounts/domain/account.dart';
import 'package:aiko/features/categories/domain/category.dart';
import 'package:aiko/features/categories/domain/category_defaults.dart';
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
          home: TransactionFormScreen(
            initialTransaction: _transaction(id: 'tx-edit', merchant: 'Coffee'),
          ),
        ),
      ),
    );

    await tester.pump();

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
          home: TransactionFormScreen(
            initialTransaction: _transaction(id: 'tx-edit', merchant: 'Coffee'),
          ),
        ),
      ),
    );

    await tester.pump();
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

  testWidgets(
    'transfer account pickers swap when selecting duplicate account',
    (tester) async {
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
                  currentBalance: Money.zero('USD'),
                ),
                Account(
                  id: 'bank',
                  userId: 'user',
                  name: 'Bank',
                  type: AccountType.bank,
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

      await _selectAccount(tester, 'cash', field: 'from-account');
      _expectSelectedAccountLabel(tester, field: 'from-account', label: 'Cash');
      _expectSelectedAccountLabel(
        tester,
        field: 'to-account',
        label: 'Select account',
      );

      await _selectAccount(tester, 'cash', field: 'to-account');
      _expectSelectedAccountLabel(
        tester,
        field: 'from-account',
        label: 'Select account',
      );
      _expectSelectedAccountLabel(tester, field: 'to-account', label: 'Cash');

      await _selectAccount(tester, 'bank', field: 'from-account');
      _expectSelectedAccountLabel(tester, field: 'from-account', label: 'Bank');
      _expectSelectedAccountLabel(tester, field: 'to-account', label: 'Cash');

      await _selectAccount(tester, 'cash', field: 'from-account');
      _expectSelectedAccountLabel(tester, field: 'from-account', label: 'Cash');
      _expectSelectedAccountLabel(tester, field: 'to-account', label: 'Bank');
    },
  );

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
                group: CategoryBudgetGroup.needs,
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

  testWidgets('category picker sheet groups categories under their groups', (
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
                groupId: CategoryGroupDefaults.foodAndDrinkId,
                icon: 'food',
                color: '#F97316',
              ),
              _category(
                'coffee',
                'Coffee',
                CategoryType.expense,
                groupId: CategoryGroupDefaults.foodAndDrinkId,
                icon: 'coffee',
                color: '#F97316',
              ),
              _category(
                'fuel',
                'Fuel',
                CategoryType.expense,
                groupId: CategoryGroupDefaults.transportId,
                icon: 'fuel',
                color: '#3B82F6',
              ),
            ]),
          ),
          categoryGroupsProvider.overrideWith(() => _EmptyGroupsNotifier()),
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
    await _openCategoryPicker(tester);

    // Group names from the 13 default groups appear twice — once in the
    // group chip bar and once as a section header — so each name shows up
    // at least once.
    expect(find.text('Food & Drink'), findsWidgets);
    expect(find.text('Transport'), findsWidgets);

    // Group chips show counts for each section so the user can size up
    // the picker before scrolling.
    final foodChip = find.byKey(
      Key(
        'transaction-category-group-chip-${CategoryGroupDefaults.foodAndDrinkId}',
      ),
    );
    expect(foodChip, findsOneWidget);
    expect(
      find.descendant(of: foodChip, matching: find.text('2')),
      findsOneWidget,
    );

    final transportChip = find.byKey(
      Key(
        'transaction-category-group-chip-${CategoryGroupDefaults.transportId}',
      ),
    );
    expect(
      find.descendant(of: transportChip, matching: find.text('1')),
      findsOneWidget,
    );

    // The picker still selects via the same option key the form already
    // listens on.
    await tester.tap(find.byKey(const Key('transaction-category-option-fuel')));
    await tester.pumpAndSettle();

    expect(find.text('Fuel'), findsWidgets);
  });

  testWidgets('category picker sheet search filters across all groups', (
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
                groupId: CategoryGroupDefaults.foodAndDrinkId,
              ),
              _category(
                'lunch',
                'Lunch Out',
                CategoryType.expense,
                groupId: CategoryGroupDefaults.foodAndDrinkId,
              ),
              _category(
                'fuel',
                'Fuel',
                CategoryType.expense,
                groupId: CategoryGroupDefaults.transportId,
              ),
            ]),
          ),
          categoryGroupsProvider.overrideWith(() => _EmptyGroupsNotifier()),
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
    await _openCategoryPicker(tester);

    // Searching collapses the group chip bar (only useful for the full list)
    // and narrows the body to matching entries.
    await tester.enterText(
      find.byKey(const Key('transaction-category-search-field')),
      'lun',
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('transaction-category-group-chips')),
      findsNothing,
    );
    expect(find.text('Lunch Out'), findsOneWidget);
    expect(find.text('Groceries'), findsNothing);
    expect(find.text('Fuel'), findsNothing);

    // Clearing the search restores the full grouped view.
    await tester.tap(
      find.byKey(const Key('transaction-category-search-clear')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Lunch Out'), findsOneWidget);
    expect(find.text('Groceries'), findsOneWidget);
    expect(find.text('Fuel'), findsOneWidget);
    expect(
      find.byKey(const Key('transaction-category-group-chips')),
      findsOneWidget,
    );
  });

  testWidgets('category picker sheet renders categories as a 2-column grid', (
    tester,
  ) async {
    // Lay out three groups of three categories each so we can verify the
    // grid wraps categories inside a single group on a single row pair.
    final categories = <Category>[
      for (final id in const ['breakfast', 'lunch', 'dinner'])
        _category(
          id,
          id[0].toUpperCase() + id.substring(1),
          CategoryType.expense,
          groupId: CategoryGroupDefaults.foodAndDrinkId,
        ),
      for (final id in const ['bus', 'taxi', 'train'])
        _category(
          id,
          id[0].toUpperCase() + id.substring(1),
          CategoryType.expense,
          groupId: CategoryGroupDefaults.transportId,
        ),
    ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          categoriesProvider.overrideWith(
            () => _CategoriesNotifier(categories),
          ),
          categoryGroupsProvider.overrideWith(() => _EmptyGroupsNotifier()),
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
    await _openCategoryPicker(tester);

    // All six categories are visible without scrolling — the compact 2-up
    // grid packs the full set inside the first viewport.
    expect(find.text('Breakfast'), findsOneWidget);
    expect(find.text('Lunch'), findsOneWidget);
    expect(find.text('Dinner'), findsOneWidget);
    expect(find.text('Bus'), findsOneWidget);
    expect(find.text('Taxi'), findsOneWidget);
    expect(find.text('Train'), findsOneWidget);

    // Each card sits within the picker's body width / 2, confirming the
    // grid is actually rendering 2 columns rather than 1.
    final cardFinder = find.byKey(const Key('transaction-category-option-bus'));
    final cardBox = tester.getRect(cardFinder);
    final bodyWidth = tester
        .getRect(find.byKey(const Key('transaction-category-section-list')))
        .width;
    expect(cardBox.width, lessThan(bodyWidth / 1.5));
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

  testWidgets(
    'switching transaction type in add mode clears typed form fields',
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
            accountsProvider.overrideWith(
              () => _AccountsNotifier([
                Account(
                  id: 'cash',
                  userId: 'user',
                  name: 'Cash',
                  type: AccountType.cash,
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

      // Fill the form as an expense so we can confirm every typed field is
      // wiped after the type switch.
      await tester.enterText(
        find.widgetWithText(TextField, 'Item name'),
        'Lunch Out',
      );
      await tester.enterText(
        find.byKey(const Key('transaction-amount-field')),
        '12.50',
      );
      await _selectCategory(tester, 'groceries');
      await _selectAccount(tester, 'cash');
      await tester.scrollUntilVisible(
        find.byKey(const Key('transaction-tags-field')),
        240,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(
        find.byKey(const Key('transaction-tags-field')),
        'work,',
      );
      await tester.pump();
      await tester.scrollUntilVisible(
        find.byKey(const Key('transaction-note-field')),
        240,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(
        find.byKey(const Key('transaction-note-field')),
        'Client meeting',
      );
      await tester.pumpAndSettle();

      // Switch from Expense to Income. The typed fields should all reset.
      // The selector is at the top of the form; drag the ListView back up
      // to make it tappable.
      for (var i = 0; i < 6; i++) {
        await tester.drag(find.byType(ListView).first, const Offset(0, 600));
        await tester.pump();
      }
      await tester.tap(find.text('Income'));
      await tester.pumpAndSettle();

      // Item name, amount, note, tags, and category/account selections are
      // all cleared.
      final itemField = tester.widget<TextField>(
        find.widgetWithText(TextField, 'Item name'),
      );
      expect(itemField.controller?.text, '');

      final amountField = tester.widget<TextField>(
        find.byKey(const Key('transaction-amount-field')),
      );
      expect(amountField.controller?.text, '');

      final noteField = tester.widget<TextField>(
        find.byKey(const Key('transaction-note-field')),
      );
      expect(noteField.controller?.text, '');

      // Category and account pickers drop back to their "Select" placeholder.
      expect(find.text('Select category'), findsOneWidget);
      _expectSelectedAccountLabel(
        tester,
        field: 'account',
        label: 'Select account',
      );

      // No leftover tag chips.
      expect(find.byType(InputChip), findsNothing);

      // The selected type did change.
      expect(_selectedSelectorColor(tester), AikoColors.successGreen);
    },
  );

  testWidgets(
    'switching transaction type in add mode preserves date and recurring settings',
    (tester) async {
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

      // Type a value so we can verify the switch clears it.
      await tester.enterText(
        find.byKey(const Key('transaction-amount-field')),
        '12.50',
      );

      // Toggle the recurring switch on. This must survive the type switch.
      await tester.scrollUntilVisible(
        find.byKey(const Key('transaction-recurring-toggle')),
        240,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('transaction-recurring-toggle')));
      await tester.pumpAndSettle();

      // Switch the type to Income.
      for (var i = 0; i < 6; i++) {
        await tester.drag(find.byType(ListView).first, const Offset(0, 600));
        await tester.pump();
      }
      await tester.tap(find.text('Income'));
      await tester.pumpAndSettle();

      // Amount is cleared …
      final amountField = tester.widget<TextField>(
        find.byKey(const Key('transaction-amount-field')),
      );
      expect(amountField.controller?.text, '');

      // … but the recurring switch is still on. Scroll back down to it
      // since the form was scrolled to the top after the type switch.
      await tester.scrollUntilVisible(
        find.byKey(const Key('transaction-recurring-toggle')),
        240,
        scrollable: find.byType(Scrollable).first,
      );
      final recurringSwitch = tester.widget<Switch>(
        find.byKey(const Key('transaction-recurring-toggle')),
      );
      expect(recurringSwitch.value, isTrue);
    },
  );

  testWidgets(
    'switching transaction type in edit mode preserves the transaction data',
    (tester) async {
      final repository = _FakeTransactionRepository();
      final initial = FinanceTransaction(
        id: 'tx-edit',
        userId: 'user',
        accountId: 'cash',
        categoryId: 'groceries',
        type: TransactionType.expense,
        amount: Money.parse('42.50', 'USD'),
        date: DateTime(2026, 5, 1),
        merchant: 'Office lunch',
        tags: const ['work', 'reimbursable'],
      );

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
            home: TransactionFormScreen(initialTransaction: initial),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Editing fields are populated from the initial transaction.
      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, 'Item name'))
            .controller
            ?.text,
        'Office lunch',
      );
      expect(find.text('Groceries'), findsOneWidget);

      // Flip the type to Income.
      await tester.tap(find.text('Income'));
      await tester.pumpAndSettle();

      // Item name and amount are preserved …
      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, 'Item name'))
            .controller
            ?.text,
        'Office lunch',
      );
      expect(
        tester
            .widget<TextField>(
              find.byKey(const Key('transaction-amount-field')),
            )
            .controller
            ?.text,
        '42.5',
      );

      // … but the expense category is cleared (different category set).
      expect(find.text('Groceries'), findsNothing);
      expect(find.text('Select category'), findsOneWidget);
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

  testWidgets(
    'item name input suggests on focus when empty and narrows after typing',
    (tester) async {
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

      await tester.enterText(
        find.widgetWithText(TextField, 'Item name'),
        'cof',
      );
      await tester.pumpAndSettle();

      expect(find.text('Coffee Beans'), findsOneWidget);
      expect(find.text('Monthly Rent'), findsNothing);

      await tester.tap(find.text('Coffee Beans').last);
      await tester.pumpAndSettle();

      final itemField = tester.widget<TextField>(
        find.widgetWithText(TextField, 'Item name'),
      );
      expect(itemField.controller?.text, 'Coffee Beans');

      await tester.enterText(
        find.widgetWithText(TextField, 'Item name'),
        'Coffee Beans',
      );
      await tester.pumpAndSettle();

      expect(find.text('Coffee Beans'), findsOneWidget);
    },
  );

  testWidgets(
    'item name focus with empty input shows five most recent suggestions',
    (tester) async {
      final repository = _FakeTransactionRepository([
        _transaction(
          id: 'tx-1',
          merchant: 'Old Item',
          date: DateTime(2026, 1, 1),
        ),
        _transaction(
          id: 'tx-2',
          merchant: 'Second Newest',
          date: DateTime(2026, 1, 7),
        ),
        _transaction(
          id: 'tx-3',
          merchant: 'Newest Item',
          date: DateTime(2026, 1, 8),
        ),
        _transaction(
          id: 'tx-4',
          merchant: 'Fourth Item',
          date: DateTime(2026, 1, 5),
        ),
        _transaction(
          id: 'tx-5',
          merchant: 'Third Item',
          date: DateTime(2026, 1, 6),
        ),
        _transaction(
          id: 'tx-6',
          merchant: 'Fifth Item',
          date: DateTime(2026, 1, 4),
        ),
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

      expect(
        find.byKey(const Key('transaction-item-name-option-Newest Item')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('transaction-item-name-option-Second Newest')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('transaction-item-name-option-Third Item')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('transaction-item-name-option-Fourth Item')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('transaction-item-name-option-Fifth Item')),
        findsOneWidget,
      );
    },
  );

  testWidgets('item name suggestions disappear after losing focus', (
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

    expect(
      find.byKey(const Key('transaction-item-name-option-Coffee Beans')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('transaction-amount-field')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('transaction-item-name-option-Coffee Beans')),
      findsNothing,
    );
  });

  testWidgets(
    'item name suggestions are filtered by selected transaction type',
    (tester) async {
      final repository = _FakeTransactionRepository([
        _transaction(merchant: 'Coffee Beans', type: TransactionType.expense),
        _transaction(
          id: 'tx-2',
          merchant: 'Monthly Salary',
          type: TransactionType.income,
        ),
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
      expect(find.text('Monthly Salary'), findsNothing);

      await tester.enterText(find.widgetWithText(TextField, 'Item name'), 'm');
      await tester.pumpAndSettle();

      expect(find.text('Coffee Beans'), findsNothing);
      expect(find.text('Monthly Salary'), findsNothing);

      await tester.tap(find.text('Income'));
      await tester.pumpAndSettle();

      expect(find.text('Coffee Beans'), findsNothing);
      expect(find.text('Monthly Salary'), findsOneWidget);
    },
  );

  testWidgets(
    'selecting an item name suggestion prefills amount, title, and tags',
    (tester) async {
      final repository = _FakeTransactionRepository([
        _transaction(
          id: 'tx-coffee',
          merchant: 'Morning Latte',
          amount: Money.parse('4.75', 'USD'),
          tags: const ['caffeine', 'work'],
          date: DateTime(2026, 1, 5),
        ),
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

      // Open the item-name suggestions and select the historical entry.
      await tester.tap(find.widgetWithText(TextField, 'Item name'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('transaction-item-name-option-Morning Latte')),
      );
      await tester.pumpAndSettle();

      // Item name and amount are prefilled from the suggestion.
      final itemField = tester.widget<TextField>(
        find.widgetWithText(TextField, 'Item name'),
      );
      expect(itemField.controller?.text, 'Morning Latte');

      final amountField = tester.widget<TextField>(
        find.byKey(const Key('transaction-amount-field')),
      );
      expect(amountField.controller?.text, '4.75');

      // Tags were replaced by the source tags.
      await tester.scrollUntilVisible(
        find.byKey(const Key('transaction-tag-chip-caffeine')),
        240,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.byKey(const Key('transaction-tag-chip-caffeine')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('transaction-tag-chip-work')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'item name suggestion source transaction must match the selected type',
    (tester) async {
      final repository = _FakeTransactionRepository([
        _transaction(
          id: 'tx-coffee',
          merchant: 'Morning Latte',
          amount: Money.parse('4.75', 'USD'),
          type: TransactionType.expense,
        ),
        _transaction(
          id: 'tx-salary',
          merchant: 'Monthly Salary',
          amount: Money.parse('5000', 'USD'),
          type: TransactionType.income,
        ),
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

      // Switch to income so the income-only suggestion is visible.
      await tester.tap(find.text('Income'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextField, 'Item name'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('transaction-item-name-option-Monthly Salary')),
      );
      await tester.pumpAndSettle();

      // The amount is prefilled from the income source transaction.
      final amountField = tester.widget<TextField>(
        find.byKey(const Key('transaction-amount-field')),
      );
      expect(amountField.controller?.text, '5000.00');
    },
  );

  testWidgets('tag input saves chips', (tester) async {
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
          home: TransactionFormScreen(
            initialTransaction: _transaction(id: 'tx-edit', merchant: 'Coffee'),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.enterText(
      find.widgetWithText(TextField, 'Item name'),
      'Coffee',
    );
    await tester.enterText(
      find.byKey(const Key('transaction-amount-field')),
      '4.50',
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('transaction-tags-field')),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(
      find.byKey(const Key('transaction-tags-field')),
      'coffee,',
    );
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('transaction-tags-field')),
      'work',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('transaction-tags-field')),
      'reimbursable,',
    );
    await tester.pump();

    expect(
      find.byKey(const Key('transaction-tag-chip-coffee')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('transaction-tag-chip-work')), findsOneWidget);
    expect(
      find.byKey(const Key('transaction-tag-chip-reimbursable')),
      findsOneWidget,
    );

    final saveButton = find.widgetWithText(FilledButton, 'Save Changes');
    for (var i = 0; i < 8 && saveButton.evaluate().isEmpty; i++) {
      await tester.drag(find.byType(ListView).first, const Offset(0, -240));
      await tester.pump();
    }
    await tester.ensureVisible(saveButton);
    await tester.pump();
    await tester.tap(saveButton);
    await tester.pump();

    expect(repository.savedTransaction?.tags, [
      'coffee',
      'work',
      'reimbursable',
    ]);
  });

  testWidgets('tag suggestions are filtered by selected transaction type', (
    tester,
  ) async {
    final repository = _FakeTransactionRepository([
      _transaction(
        tags: const ['groceries', 'daily'],
        type: TransactionType.expense,
      ),
      _transaction(
        id: 'tx-2',
        tags: const ['payroll', 'bonus'],
        type: TransactionType.income,
      ),
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
    await tester.enterText(
      find.byKey(const Key('transaction-tags-field')),
      'gr',
    );
    await tester.pumpAndSettle();

    expect(find.text('groceries'), findsOneWidget);
    expect(find.text('payroll'), findsNothing);

    await tester.tap(find.text('Income'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('transaction-tags-field')),
      'pa',
    );
    await tester.pumpAndSettle();

    expect(find.text('groceries'), findsNothing);
    expect(find.text('payroll'), findsOneWidget);
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
  for (var i = 0; i < 8 && !tester.any(picker); i++) {
    await tester.drag(find.byType(ListView).first, const Offset(0, -240));
    await tester.pump();
  }
  await tester.tap(picker);
  await tester.pump();
}

Future<void> _selectAccount(
  WidgetTester tester,
  String accountId, {
  String field = 'account',
}) async {
  await _openAccountPicker(tester, field: field);
  final option = find.byKey(Key('transaction-$field-option-$accountId'));
  tester.widget<ListTile>(option).onTap?.call();
  await tester.pump();
}

void _expectSelectedAccountLabel(
  WidgetTester tester, {
  required String field,
  required String label,
}) {
  final selectedLabelFinder = find.byKey(
    Key('transaction-$field-selected-account-name'),
  );
  expect(selectedLabelFinder, findsOneWidget);
  expect(tester.widget<Text>(selectedLabelFinder).data, label);
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

class _EmptyGroupsNotifier extends CategoryGroupsNotifier {
  @override
  Future<List<CategoryGroup>> build() async => const [];
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
  CategoryBudgetGroup group = CategoryBudgetGroup.custom,
  String icon = 'category',
  String color = '#3B82F6',
  String? groupId,
}) {
  return Category(
    id: id,
    userId: 'user',
    name: name,
    type: type,
    group: group,
    groupId: groupId,
    icon: icon,
    color: color,
  );
}

FinanceTransaction _transaction({
  String id = 'tx-1',
  String? merchant,
  List<String> tags = const [],
  TransactionType type = TransactionType.expense,
  DateTime? date,
  Money? amount,
  String? categoryId,
  String accountId = 'cash',
}) {
  return FinanceTransaction(
    id: id,
    userId: 'user',
    accountId: accountId,
    type: type,
    amount: amount ?? Money.parse('1', 'USD'),
    date: date ?? DateTime(2026, 1, 1),
    merchant: merchant,
    tags: tags,
    categoryId: categoryId,
  );
}
