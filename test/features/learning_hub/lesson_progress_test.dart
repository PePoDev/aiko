import 'package:aiko/core/storage/secure_storage_service.dart';
import 'package:aiko/features/learning_hub/application/lesson_progress.dart';
import 'package:aiko/features/learning_hub/domain/lesson.dart';
import 'package:aiko/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('rings are empty, half and full for not started, read, completed', () {
    expect(LessonProgress.notStarted.ringValue, 0);
    expect(LessonProgress.read.ringValue, 0.5);
    expect(LessonProgress.completed.ringValue, 1);
  });

  test('a quiz passes only when every question is answered correctly', () {
    const questions = [
      LessonQuizQuestion(
        prompt: 'a',
        options: ['x', 'y'],
        correctOptionIndex: 1,
      ),
      LessonQuizQuestion(
        prompt: 'b',
        options: ['x', 'y'],
        correctOptionIndex: 0,
      ),
    ];
    expect(quizPassed(questions, {}), isFalse);
    expect(quizPassed(questions, {0: 1}), isFalse);
    expect(quizPassed(questions, {0: 1, 1: 1}), isFalse);
    expect(quizPassed(questions, {0: 1, 1: 0}), isTrue);
  });

  test('every lesson has a stable key and a quiz', () {
    final lessons = lessonsFor(lookupAppLocalizations(const Locale('en')));
    expect(lessons.map((l) => l.key).toSet(), hasLength(lessons.length));
    for (final lesson in lessons) {
      expect(lesson.quizQuestions, isNotEmpty);
      for (final question in lesson.quizQuestions) {
        expect(
          question.correctOptionIndex,
          inInclusiveRange(0, question.options.length - 1),
        );
      }
    }
  });

  group('LessonProgressStore', () {
    test('records progress and never moves it backwards', () async {
      final store = LessonProgressStore(MemorySecureStorageService());
      expect(await store.load(), isEmpty);

      await store.record('budget-basics', LessonProgress.read);
      expect(await store.load(), {'budget-basics': LessonProgress.read});

      await store.record('budget-basics', LessonProgress.completed);
      await store.record('budget-basics', LessonProgress.read);
      expect(await store.load(), {'budget-basics': LessonProgress.completed});
    });

    test('skips unknown values and survives corrupt storage', () async {
      final storage = MemorySecureStorageService();
      await storage.write(
        LessonProgressStore.storageKey,
        '{"a": "completed", "b": "mastered"}',
      );
      expect(await LessonProgressStore(storage).load(), {
        'a': LessonProgress.completed,
      });

      await storage.write(LessonProgressStore.storageKey, '[oops');
      expect(await LessonProgressStore(storage).load(), isEmpty);
    });
  });

  test('the provider loads stored progress and records new progress', () async {
    final storage = MemorySecureStorageService();
    await LessonProgressStore(
      storage,
    ).record('emergency-fund', LessonProgress.read);
    final container = ProviderContainer(
      overrides: [lessonProgressStorageProvider.overrideWithValue(storage)],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(lessonProgressProvider, (_, _) {});
    addTearDown(subscription.close);

    expect(await container.read(lessonProgressProvider.future), {
      'emergency-fund': LessonProgress.read,
    });

    await container
        .read(lessonProgressProvider.notifier)
        .record('emergency-fund', LessonProgress.completed);
    expect(container.read(lessonProgressProvider).value, {
      'emergency-fund': LessonProgress.completed,
    });
    expect(await LessonProgressStore(storage).load(), {
      'emergency-fund': LessonProgress.completed,
    });
  });
}
