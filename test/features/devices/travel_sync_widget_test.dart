import 'package:aiko/features/travel_mode/presentation/travel_mode_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('travel screen exposes trip state', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: TravelModeScreen()),
      ),
    );

    expect(find.text('Trip budget'), findsOneWidget);
  });
}
