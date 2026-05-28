import 'package:flutter_test/flutter_test.dart';

import 'package:aiko/app/app_router.dart';
import 'package:aiko/l10n/app_localizations.dart';
import 'package:aiko/theme/aiko_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../helpers/test_app.dart';

void main() {
  testWidgets('router starts on splash and can show onboarding entry', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    expect(find.text('Aiko'), findsWidgets);
    expect(find.text('Get started'), findsOneWidget);
  });

  testWidgets('router no longer exposes the removed Aiko Hub route', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp.router(
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AikoTheme.light(),
        routerConfig: createAikoRouter(initialLocation: '/more'),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Route not found'), findsOneWidget);
    expect(find.text('Aiko Hub'), findsNothing);
  });

  testWidgets('router no longer exposes the removed subscription plan route', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp.router(
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AikoTheme.light(),
        routerConfig: createAikoRouter(initialLocation: '/subscription-plan'),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Route not found'), findsOneWidget);
    expect(find.text('Subscription Plan'), findsNothing);
  });

  testWidgets('router no longer exposes the removed devices route', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp.router(
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AikoTheme.light(),
        routerConfig: createAikoRouter(initialLocation: '/devices'),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Route not found'), findsOneWidget);
    expect(find.text('Trusted Devices'), findsNothing);
  });
}
