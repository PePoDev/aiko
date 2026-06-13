import 'package:flutter_test/flutter_test.dart';

import 'package:aiko/app/app_router.dart';
import 'package:aiko/l10n/app_localizations.dart';
import 'package:aiko/theme/aiko_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../helpers/test_app.dart';

void main() {
  testWidgets('router starts on welcome and can show login entry', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    expect(find.text('Aiko'), findsWidgets);
    expect(find.text('Get Started'), findsOneWidget);
  });
}
