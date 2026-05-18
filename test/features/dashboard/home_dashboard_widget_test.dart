import 'package:aiko/features/dashboard/presentation/home_dashboard_screen.dart';
import 'package:aiko/theme/aiko_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('home dashboard shows safe-to-spend and Aiko welcome', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: AikoTheme.light(), home: const HomeDashboardScreen()),
    );

    expect(find.text('Hi, I am Aiko'), findsOneWidget);
    expect(find.text('Safe to spend'), findsOneWidget);
  });
}
