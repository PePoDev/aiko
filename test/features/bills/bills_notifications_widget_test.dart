import 'package:aiko/features/bills/presentation/bills_screen.dart';
import 'package:aiko/features/settings/presentation/notification_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('bills screen shows subscription and lower-bill areas', (
    tester,
  ) async {
    // Set viewport size and device pixel ratio to ensure wide logical width
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: BillsScreen(),
        ),
      ),
    );

    // Resolve the async Riverpod future loader
    await tester.pumpAndSettle();

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
