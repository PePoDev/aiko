import 'package:aiko/core/money/money.dart';
import 'package:aiko/features/dashboard/domain/dashboard_due_item.dart';
import 'package:aiko/features/dashboard/presentation/widgets/dashboard_due_items_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows due item details', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DashboardDueItemsWidget(
            items: [
              DashboardDueItem(
                id: 'bill',
                title: 'Internet',
                amount: Money.parse('60', 'USD'),
                dueDate: DateTime(2026, 5, 24),
                kind: DashboardDueItemKind.bill,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Upcoming due dates'), findsOneWidget);
    expect(find.text('Internet'), findsOneWidget);
    expect(find.textContaining('60'), findsOneWidget);
  });

  testWidgets('shows empty due item state', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: DashboardDueItemsWidget(items: [])),
      ),
    );

    expect(find.text('No bills or card payments due soon.'), findsOneWidget);
  });
}
