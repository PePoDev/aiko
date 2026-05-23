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

    // Check for key navigation items
    expect(find.textContaining('Account'), findsWidgets);
    expect(find.textContaining('Setting'), findsWidgets);
  });
}
