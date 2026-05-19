import 'package:aiko/features/learning_hub/domain/glossary_entry.dart';
import 'package:aiko/features/learning_hub/domain/quiz_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('scores quizzes and stores glossary links', () {
    const quiz = QuizResult(correct: 8, total: 10);
    const entry = GlossaryEntry(
      term: 'APR',
      definition: 'Annual percentage rate',
    );

    expect(quiz.passed, isTrue);
    expect(entry.definition, contains('Annual'));
  });
}
