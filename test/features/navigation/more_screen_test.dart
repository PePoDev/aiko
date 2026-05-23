import 'package:aiko/features/navigation/presentation/more_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('more screen exposes secondary feature routes', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: MoreScreen()));

    expect(find.text('Daily Money'), findsOneWidget);
    expect(find.text('Accounts'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Bills'), 300);
    expect(find.text('Bills'), findsOneWidget);
    expect(find.text('Budget'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Portfolio'), 300);
    expect(find.text('Portfolio'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Aiko Optimize'), 300);
    expect(find.text('Aiko Optimize'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Settings'), 300);
    expect(find.text('Settings'), findsOneWidget);
  });
}
