import 'package:aiko/features/bills/presentation/bills_screen.dart';
import 'package:aiko/features/settings/presentation/notification_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('bills screen shows subscription and lower-bill areas', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: BillsScreen()));

    expect(find.text('Upcoming bills'), findsOneWidget);
    expect(find.text('Subscription review'), findsOneWidget);
    expect(find.text('Lower your bills'), findsOneWidget);
  });

  testWidgets('notification settings shows bill and budget toggles', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: NotificationSettingsScreen()),
    );

    expect(find.text('Bill reminders'), findsOneWidget);
    expect(find.text('Budget alerts'), findsOneWidget);
  });
}
