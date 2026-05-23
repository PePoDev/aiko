import 'package:aiko/core/money/money.dart';
import 'package:aiko/features/dashboard/domain/dashboard_due_item.dart';
import 'package:aiko/features/dashboard/presentation/widgets/dashboard_due_items_widget.dart';
import 'package:aiko/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() {
  testWidgets('shows due item details', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
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

    await tester.pumpAndSettle();
    expect(find.text('Internet'), findsOneWidget);
    expect(find.textContaining('60'), findsOneWidget);
  });

  testWidgets('shows empty due item state', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: DashboardDueItemsWidget(items: [])),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.textContaining('due'), findsWidgets);
  });
}
