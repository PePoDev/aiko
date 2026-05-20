import 'package:aiko/features/transactions/presentation/transaction_list_screen.dart';
import 'package:aiko/theme/aiko_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('transaction list shows search and demo transactions', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AikoTheme.light(),
          home: const TransactionListScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Search transactions'), findsOneWidget);
    expect(find.textContaining('Coffee'), findsOneWidget);
  });

  testWidgets('transaction item opens detail screen', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AikoTheme.light(),
          home: const TransactionListScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Coffee'));
    await tester.pumpAndSettle();

    expect(find.text('Transaction details'), findsOneWidget);
    expect(find.text('Coffee Shop'), findsWidgets);
    expect(find.text('-\$4.50'), findsOneWidget);
  });
}
