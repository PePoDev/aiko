import 'package:aiko/features/devices/presentation/devices_screen.dart';
import 'package:aiko/features/travel_mode/presentation/travel_mode_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('devices and travel screens expose sync and trip states', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: DevicesScreen()));
    expect(find.text('Trusted devices'), findsOneWidget);
    await tester.pumpWidget(const MaterialApp(home: TravelModeScreen()));
    expect(find.text('Trip budget'), findsOneWidget);
  });
}
