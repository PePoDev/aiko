import 'package:aiko/features/learning_hub/presentation/learning_hub_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('learning hub shows lessons, quizzes, and glossary', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: LearningHubScreen()));
    expect(find.text('Recommended lessons'), findsOneWidget);
    expect(find.text('Quizzes'), findsOneWidget);
    expect(find.text('Glossary'), findsOneWidget);
  });
}
