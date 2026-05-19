import 'package:aiko/features/aiko_optimize/presentation/aiko_optimize_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('optimize screen shows suggestions and predictions', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: AikoOptimizeScreen()));
    expect(find.text('Optimization suggestions'), findsOneWidget);
    expect(find.text('Prediction scenarios'), findsOneWidget);
  });
}
