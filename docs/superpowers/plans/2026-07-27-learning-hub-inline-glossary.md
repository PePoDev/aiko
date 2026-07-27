# Learning Hub Inline Glossary Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the Learning Hub's standalone Glossary card with accessible inline term definitions that work for current and future lesson content.

**Architecture:** Add a focused `InlineGlossaryText` presentation widget that parses case-insensitive complete-term matches and renders them as themed tooltip targets inside rich text. Keep the glossary data in the Learning Hub screen, update lesson content to use all current terms, and pass every rendered lesson or quiz string through the reusable widget.

**Tech Stack:** Flutter, Material `Tooltip`, Dart records and regular expressions, `flutter_test`.

---

## File Structure

- Create `lib/features/learning_hub/presentation/inline_glossary_text.dart`
  for glossary matching, rich-text rendering, semantics, and tooltip triggers.
- Create `test/features/learning_hub/inline_glossary_text_test.dart` for the
  reusable widget's matching and interaction behavior.
- Modify
  `lib/features/learning_hub/presentation/learning_hub_screen.dart` to remove
  the Glossary card, revise lesson copy, add the investing lesson, and render
  glossary-aware text.
- Create `test/features/learning_hub/learning_hub_screen_test.dart` for
  Learning Hub integration and regression coverage.

### Task 1: Reusable inline glossary text

**Files:**
- Create: `lib/features/learning_hub/presentation/inline_glossary_text.dart`
- Create: `test/features/learning_hub/inline_glossary_text_test.dart`

- [ ] **Step 1: Write the failing matching and tooltip tests**

Create `test/features/learning_hub/inline_glossary_text_test.dart`:

```dart
import 'package:aiko/features/learning_hub/presentation/inline_glossary_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const glossary = <String, String>{
    'APR': 'Annual percentage rate.',
    'Compound interest': 'Interest earned on principal and prior interest.',
  };

  Widget buildSubject(String text) {
    return MaterialApp(
      home: Scaffold(
        body: InlineGlossaryText(text: text, glossary: glossary),
      ),
    );
  }

  testWidgets('matches future glossary terms case-insensitively', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    addTearDown(semantics.dispose);
    await tester.pumpWidget(
      buildSubject('Learn how compound interest grows savings.'),
    );

    expect(find.text('compound interest'), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        'compound interest: Interest earned on principal and prior interest.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('does not match a glossary term inside another word', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    addTearDown(semantics.dispose);
    await tester.pumpWidget(buildSubject('APR matters, but APRIL is a month.'));

    expect(find.bySemanticsLabel('APR: Annual percentage rate.'), findsOneWidget);
    expect(
      find.textContaining('APRIL is a month.', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('shows the definition on tap and long press', (tester) async {
    await tester.pumpWidget(buildSubject('Compare APR before borrowing.'));

    await tester.tap(find.text('APR'));
    await tester.pumpAndSettle();
    expect(find.text('Annual percentage rate.'), findsOneWidget);

    Tooltip.dismissAllToolTips();
    await tester.pumpAndSettle();
    await tester.longPress(find.text('APR'));
    await tester.pumpAndSettle();
    expect(find.text('Annual percentage rate.'), findsOneWidget);
  });

  testWidgets('renders ordinary text unchanged', (tester) async {
    await tester.pumpWidget(buildSubject('No defined terms here.'));

    expect(
      find.text('No defined terms here.', findRichText: true),
      findsOneWidget,
    );
    expect(find.byType(Tooltip), findsNothing);
  });
}
```

- [ ] **Step 2: Run the widget tests to verify RED**

Run:

```powershell
flutter test test\features\learning_hub\inline_glossary_text_test.dart
```

Expected: FAIL because
`features/learning_hub/presentation/inline_glossary_text.dart` and
`InlineGlossaryText` do not exist.

- [ ] **Step 3: Implement complete-term parsing and tooltip targets**

Create `lib/features/learning_hub/presentation/inline_glossary_text.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../theme/aiko_colors.dart';

class InlineGlossaryText extends StatelessWidget {
  const InlineGlossaryText({
    required this.text,
    required this.glossary,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow = TextOverflow.clip,
    super.key,
  });

  final String text;
  final Map<String, String> glossary;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow overflow;

  @override
  Widget build(BuildContext context) {
    final terms = glossary.keys
        .where((term) => term.trim().isNotEmpty)
        .toList(growable: false)
      ..sort((a, b) => b.length.compareTo(a.length));

    if (text.isEmpty || terms.isEmpty) {
      return Text(
        text,
        style: style,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
      );
    }

    final definitions = <String, String>{
      for (final entry in glossary.entries)
        entry.key.toLowerCase(): entry.value,
    };
    final matcher = RegExp(
      terms.map(RegExp.escape).join('|'),
      caseSensitive: false,
    );
    final spans = <InlineSpan>[];
    var cursor = 0;

    for (final match in matcher.allMatches(text)) {
      if (!_hasTermBoundaries(text, match.start, match.end)) {
        continue;
      }
      if (match.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, match.start)));
      }
      final matchedTerm = text.substring(match.start, match.end);
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: _GlossaryTerm(
            term: matchedTerm,
            definition: definitions[matchedTerm.toLowerCase()]!,
            style: style,
          ),
        ),
      );
      cursor = match.end;
    }

    if (cursor == 0) {
      return Text(
        text,
        style: style,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
      );
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }

    return Text.rich(
      TextSpan(style: style, children: spans),
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}

bool _hasTermBoundaries(String text, int start, int end) {
  final beforeIsWord = start > 0 && _isWordCharacter(text[start - 1]);
  final afterIsWord = end < text.length && _isWordCharacter(text[end]);
  return !beforeIsWord && !afterIsWord;
}

bool _isWordCharacter(String character) {
  return RegExp(r'[A-Za-z0-9]').hasMatch(character);
}

class _GlossaryTerm extends StatefulWidget {
  const _GlossaryTerm({
    required this.term,
    required this.definition,
    required this.style,
  });

  final String term;
  final String definition;
  final TextStyle? style;

  @override
  State<_GlossaryTerm> createState() => _GlossaryTermState();
}

class _GlossaryTermState extends State<_GlossaryTerm> {
  final _tooltipKey = GlobalKey<TooltipState>();

  void _showTooltip() {
    _tooltipKey.currentState?.ensureTooltipVisible();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${widget.term}: ${widget.definition}',
      child: Focus(
        onFocusChange: (hasFocus) {
          if (hasFocus) _showTooltip();
        },
        child: GestureDetector(
          onLongPress: _showTooltip,
          child: Tooltip(
            key: _tooltipKey,
            message: widget.definition,
            triggerMode: TooltipTriggerMode.tap,
            enableTapToDismiss: true,
            excludeFromSemantics: true,
            child: Text(
              widget.term,
              style: widget.style?.copyWith(
                    color: AikoColors.analyticsTeal,
                    decoration: TextDecoration.underline,
                    decorationStyle: TextDecorationStyle.dotted,
                    decorationColor: AikoColors.analyticsTeal,
                  ) ??
                  const TextStyle(
                    color: AikoColors.analyticsTeal,
                    decoration: TextDecoration.underline,
                    decorationStyle: TextDecorationStyle.dotted,
                    decorationColor: AikoColors.analyticsTeal,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run the widget tests to verify GREEN**

Run:

```powershell
dart format lib\features\learning_hub\presentation\inline_glossary_text.dart test\features\learning_hub\inline_glossary_text_test.dart
flutter test test\features\learning_hub\inline_glossary_text_test.dart
```

Expected: all four tests PASS with no exceptions or warnings.

- [ ] **Step 5: Commit the reusable widget**

```powershell
git add -- lib/features/learning_hub/presentation/inline_glossary_text.dart test/features/learning_hub/inline_glossary_text_test.dart
git commit -m "feat: add inline learning glossary tooltips"
```

### Task 2: Integrate inline definitions into the Learning Hub

**Files:**
- Modify: `lib/features/learning_hub/presentation/learning_hub_screen.dart`
- Create: `test/features/learning_hub/learning_hub_screen_test.dart`

- [ ] **Step 1: Write the failing Learning Hub regression tests**

Create `test/features/learning_hub/learning_hub_screen_test.dart`:

```dart
import 'package:aiko/features/learning_hub/presentation/learning_hub_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpLearningHub(WidgetTester tester) {
    return tester.pumpWidget(
      const MaterialApp(home: LearningHubScreen()),
    );
  }

  testWidgets('replaces the standalone glossary with inline terms', (
    tester,
  ) async {
    await pumpLearningHub(tester);

    expect(find.text('Glossary'), findsNothing);
    expect(find.text('Safe-to-spend'), findsOneWidget);
    expect(find.text('APR'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Rebalancing'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Rebalancing'), findsWidgets);
  });

  testWidgets('shows a lesson term definition beside its content', (
    tester,
  ) async {
    await pumpLearningHub(tester);
    await tester.scrollUntilVisible(
      find.text('APR'),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    await tester.tap(find.text('APR'));
    await tester.pumpAndSettle();

    expect(find.text('Annual percentage rate.'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run the Learning Hub tests to verify RED**

Run:

```powershell
flutter test test\features\learning_hub\learning_hub_screen_test.dart
```

Expected: FAIL because the standalone `Glossary` card is still visible and the
current lesson copy does not render the three inline terms.

- [ ] **Step 3: Replace the glossary records with a reusable map**

In `lib/features/learning_hub/presentation/learning_hub_screen.dart`, import
the new widget:

```dart
import 'inline_glossary_text.dart';
```

Delete:

```dart
typedef _GlossaryEntry = ({String term, String definition});
```

Replace `_glossary` with:

```dart
const _glossary = <String, String>{
  'APR': 'Annual percentage rate.',
  'Safe-to-spend':
      'Money left after bills, savings, goals, and posted spending.',
  'Rebalancing':
      'Adjusting investments back toward target allocation weights.',
};
```

- [ ] **Step 4: Remove the Glossary card and render glossary-aware copy**

Delete the `SizedBox` and `FinanceCard` whose title is `Glossary`.

Change `_LessonTile.build` to:

```dart
@override
Widget build(BuildContext context) {
  return ListTile(
    contentPadding: EdgeInsets.zero,
    leading: CircularProgressIndicator(
      value: _completionPercent(lesson.progress),
      strokeWidth: 4,
    ),
    title: InlineGlossaryText(
      text: lesson.title,
      glossary: _glossary,
    ),
    subtitle: InlineGlossaryText(
      text:
          '${lesson.category} - ${lesson.estimatedMinutes} min\n'
          '${lesson.summary}',
      glossary: _glossary,
    ),
    isThreeLine: true,
    trailing: const Icon(Icons.chevron_right),
  );
}
```

In the Quizzes card, replace its `Text` with:

```dart
InlineGlossaryText(
  text:
      '${lesson.title}: '
      '${lesson.quizQuestions.length} question quiz',
  glossary: _glossary,
),
```

- [ ] **Step 5: Revise lesson copy and add the investing lesson**

Change the budgeting summary to:

```dart
summary:
    'Safe-to-spend helps you balance needs, wants, goals, and flexible spending.',
```

Change the credit summary to:

```dart
summary:
    'Understand APR, balance-to-limit ratios, and why paydown timing matters.',
```

Append this record to `_lessons`:

```dart
(
  key: 'portfolio-rebalancing',
  title: 'Rebalancing your portfolio',
  category: 'Investing',
  summary:
      'Learn when to bring investments back toward target allocation weights.',
  estimatedMinutes: 6,
  progress: _LessonProgress.notStarted,
  quizQuestions: [
    (
      prompt: 'What does rebalancing restore?',
      options: ['Target allocation weights', 'A guaranteed return'],
      correctOptionIndex: 0,
    ),
  ],
),
```

- [ ] **Step 6: Run both Learning Hub test files to verify GREEN**

Run:

```powershell
dart format lib\features\learning_hub\presentation\learning_hub_screen.dart test\features\learning_hub\learning_hub_screen_test.dart
flutter test test\features\learning_hub
```

Expected: all inline glossary and Learning Hub integration tests PASS.

- [ ] **Step 7: Commit the Learning Hub integration**

```powershell
git add -- lib/features/learning_hub/presentation/learning_hub_screen.dart test/features/learning_hub/learning_hub_screen_test.dart
git commit -m "feat: move learning glossary into lesson text"
```

### Task 3: Final verification

**Files:**
- Verify:
  `lib/features/learning_hub/presentation/inline_glossary_text.dart`
- Verify:
  `lib/features/learning_hub/presentation/learning_hub_screen.dart`
- Verify: `test/features/learning_hub/`

- [ ] **Step 1: Confirm standalone glossary UI references are gone**

Run:

```powershell
rg -n "title: 'Glossary'|_GlossaryEntry|for \\(final entry in _glossary\\)" lib/features/learning_hub
```

Expected: no matches.

- [ ] **Step 2: Run static analysis**

Run:

```powershell
flutter analyze
```

Expected: `No issues found!`

- [ ] **Step 3: Run the complete test suite**

Run:

```powershell
flutter test
```

Expected: all tests PASS with zero failures.

- [ ] **Step 4: Inspect the final diff**

Run:

```powershell
git diff --check
git status --short
```

Expected: no whitespace errors; only intentional pre-existing worktree changes
remain after the two feature commits.
