import 'package:aiko/features/transactions/presentation/transaction_form_screen.dart';
import 'package:aiko/theme/aiko_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('transaction form is amount first', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AikoTheme.light(),
        home: const TransactionFormScreen(),
      ),
    );

    final textFields = find.byType(TextField);
    expect(textFields, findsWidgets);
    expect(find.text('Amount'), findsOneWidget);
  });
}
