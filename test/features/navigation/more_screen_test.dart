import 'package:aiko/features/navigation/presentation/more_screen.dart';
import 'package:aiko/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('more screen exposes secondary feature routes', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: MoreScreen(),
      ),
    );

    await tester.pumpAndSettle();

    // Planning-owned workspaces are not duplicated in Aiko Hub.
    expect(find.text('Accounts'), findsNothing);
    expect(find.text('Debt and Loans'), findsNothing);
    expect(find.text('Credit Cards'), findsNothing);
    expect(find.text('Categories'), findsNothing);
    expect(find.text('Assets'), findsNothing);
    expect(find.text('Tax Center'), findsNothing);
    expect(find.text('Accounting'), findsNothing);
    expect(find.text('Portfolio'), findsNothing);
    expect(find.text('Budget'), findsNothing);
    expect(find.text('Goals'), findsNothing);
    expect(find.text('Bills'), findsNothing);
    expect(find.text('Rules'), findsNothing);
    await tester.scrollUntilVisible(find.text('Settings'), 500);
    expect(find.textContaining('Setting'), findsWidgets);
  });
}
