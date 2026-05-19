import 'package:aiko/features/accounting/presentation/accounting_screen.dart';
import 'package:aiko/features/tax_center/presentation/tax_center_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'tax and accounting screens expose estimate and reconciliation states',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: TaxCenterScreen()));
      expect(find.text('Tax estimates'), findsOneWidget);
      await tester.pumpWidget(const MaterialApp(home: AccountingScreen()));
      expect(find.text('Reconciliation'), findsOneWidget);
    },
  );
}
