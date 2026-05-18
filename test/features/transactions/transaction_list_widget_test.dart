import 'package:aiko/features/transactions/presentation/transaction_list_screen.dart';
import 'package:aiko/theme/aiko_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('transaction list shows search and demo transactions', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AikoTheme.light(),
        home: const TransactionListScreen(),
      ),
    );

    expect(find.text('Search transactions'), findsOneWidget);
    expect(find.textContaining('Coffee'), findsOneWidget);
  });
}
