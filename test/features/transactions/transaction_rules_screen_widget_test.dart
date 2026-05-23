import 'package:aiko/core/storage/secure_storage_service.dart';
import 'package:aiko/features/transactions/presentation/transaction_rules_screen.dart';
import 'package:aiko/theme/aiko_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('transaction rules screen shows external source rules and FAB', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AikoTheme.light(),
        home: TransactionRulesScreen(storage: MemorySecureStorageService()),
      ),
    );

    expect(find.text('Transaction rules'), findsOneWidget);
    expect(find.text('Credit card statement imports'), findsOneWidget);
    expect(find.text('Mobile banking slip photos'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Bank SMS alerts'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Bank SMS alerts'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Bank app notifications'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Bank app notifications'), findsOneWidget);
    expect(find.text('New rule'), findsOneWidget);
  });

  testWidgets('user can create a custom external transaction rule', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AikoTheme.light(),
        home: TransactionRulesScreen(storage: MemorySecureStorageService()),
      ),
    );

    await tester.tap(find.text('New rule'));
    await tester.pumpAndSettle();

    await _enterField(tester, 'Rule name', 'Wallet alerts');
    await _enterField(tester, 'Match text or pattern', 'Wallet paid');
    await _enterField(tester, 'Merchant or payee mapping', 'Wallet merchant');
    await _enterField(tester, 'Account mapping', 'E-wallet');
    await _enterField(tester, 'Category mapping', 'Shopping');
    await _enterField(tester, 'Tags', 'wallet, auto');

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Wallet alerts'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Wallet alerts'), findsOneWidget);
    expect(find.text('Wallet paid'), findsOneWidget);
    expect(find.text('Shopping • wallet, auto'), findsOneWidget);
  });
}

Future<void> _enterField(
  WidgetTester tester,
  String label,
  String value,
) async {
  final labelFinder = find.text(label);
  await tester.scrollUntilVisible(
    labelFinder,
    240,
    scrollable: find.byType(Scrollable).first,
  );
  final field = find.ancestor(
    of: labelFinder,
    matching: find.byType(TextFormField),
  );
  await tester.enterText(field, value);
}
