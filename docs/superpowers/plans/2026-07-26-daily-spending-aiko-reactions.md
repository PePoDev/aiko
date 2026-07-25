# Daily Spending Aiko Reactions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Retire the standalone Pace Overview and make Home's Daily Spending card the single, expressive spending-status surface with green/smiling, orange/worried, and red/angry Aiko reactions.

**Architecture:** A pure dashboard-domain enum owns the ratio thresholds. A focused presentation widget owns the color, copy, semantics, and custom-painted Aiko face; Home derives one state from its existing ratio and shares that state between the gauge color and reaction strip. Standalone monthly pace UI, provider, models, tests, and dead summary fields are removed while safe-to-spend and assistant budget context remain intact.

**Tech Stack:** Flutter, Dart 3 records/enums, Material `CustomPainter`, Riverpod, GoRouter, `flutter_test`

---

## File Map

**Create**

- `lib/features/dashboard/domain/daily_spending_reaction.dart` — pure ratio-to-reaction mapping.
- `lib/features/dashboard/presentation/widgets/aiko_spending_reaction_strip.dart` — approved strip, copy, semantic state, colors, and Aiko face painter.
- `test/features/dashboard/daily_spending_reaction_test.dart` — threshold boundary coverage.
- `test/features/dashboard/aiko_spending_reaction_strip_test.dart` — all three visual/semantic variants.
- `test/app/aiko_navigation_test.dart` — regression coverage for the retired Settings entry.

**Modify**

- `lib/features/dashboard/presentation/home_dashboard_screen.dart` — derive one reaction and insert the strip.
- `lib/app/aiko_navigation.dart` — remove Budget: Pace.
- `lib/app/app_router.dart` — remove `/settings/pace`.
- `lib/features/overview/presentation/finance_detail_screens.dart` — remove `PaceOverviewScreen` and `_paceColor`.
- `lib/app/providers.dart` — remove `budgetPaceProvider` and unused summary pace calculations.
- `lib/features/dashboard/domain/dashboard_summary.dart` — remove unused `PaceStatus`.
- `lib/features/overview/application/budget_insights_service.dart` — retain safe-to-spend, remove standalone pace models/method.
- `test/features/overview/budget_insights_service_test.dart` — retain safe-to-spend coverage, remove retired pace cases.
- `lib/l10n/app_en.arb` and `lib/l10n/app_th.arb` — remove unused standalone pace strings.
- `README.md` — remove the route/tool and describe Aiko reactions in Daily Spending.

### Task 1: Model Daily Spending Reaction Thresholds

**Files:**

- Create: `test/features/dashboard/daily_spending_reaction_test.dart`
- Create: `lib/features/dashboard/domain/daily_spending_reaction.dart`

- [ ] **Step 1: Write the failing threshold test**

```dart
import 'package:aiko/features/dashboard/domain/daily_spending_reaction.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DailySpendingReaction.fromRatio', () {
    test('is comfortable below 75 percent', () {
      expect(
        DailySpendingReaction.fromRatio(0.749),
        DailySpendingReaction.comfortable,
      );
    });

    test('is caution from 75 percent until the safe amount is used', () {
      expect(
        DailySpendingReaction.fromRatio(0.75),
        DailySpendingReaction.caution,
      );
      expect(
        DailySpendingReaction.fromRatio(0.999),
        DailySpendingReaction.caution,
      );
    });

    test('is exceeded from 100 percent onward', () {
      expect(
        DailySpendingReaction.fromRatio(1),
        DailySpendingReaction.exceeded,
      );
      expect(
        DailySpendingReaction.fromRatio(1.2),
        DailySpendingReaction.exceeded,
      );
    });
  });
}
```

- [ ] **Step 2: Run the test and verify RED**

Run:

```powershell
flutter test test/features/dashboard/daily_spending_reaction_test.dart
```

Expected: FAIL because `daily_spending_reaction.dart` does not exist.

- [ ] **Step 3: Add the minimal domain enum**

```dart
enum DailySpendingReaction {
  comfortable,
  caution,
  exceeded;

  static DailySpendingReaction fromRatio(double ratio) {
    if (ratio >= 1) return DailySpendingReaction.exceeded;
    if (ratio >= 0.75) return DailySpendingReaction.caution;
    return DailySpendingReaction.comfortable;
  }
}
```

- [ ] **Step 4: Format and verify GREEN**

Run:

```powershell
dart format lib/features/dashboard/domain/daily_spending_reaction.dart test/features/dashboard/daily_spending_reaction_test.dart
flutter test test/features/dashboard/daily_spending_reaction_test.dart
```

Expected: 3 tests PASS.

- [ ] **Step 5: Commit only this task**

```powershell
git add lib/features/dashboard/domain/daily_spending_reaction.dart test/features/dashboard/daily_spending_reaction_test.dart
git commit -m "feat: model daily spending reactions"
```

### Task 2: Build the Approved Aiko Status Strip

**Files:**

- Create: `test/features/dashboard/aiko_spending_reaction_strip_test.dart`
- Create: `lib/features/dashboard/presentation/widgets/aiko_spending_reaction_strip.dart`

- [ ] **Step 1: Write the failing widget test**

```dart
import 'package:aiko/features/dashboard/domain/daily_spending_reaction.dart';
import 'package:aiko/features/dashboard/presentation/widgets/aiko_spending_reaction_strip.dart';
import 'package:aiko/theme/aiko_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final cases = <({
    DailySpendingReaction reaction,
    Color color,
    String title,
    String message,
    String semantics,
  })>[
    (
      reaction: DailySpendingReaction.comfortable,
      color: AikoColors.successGreen,
      title: "You're spending comfortably",
      message: "Nice work—today's spending is in a healthy range.",
      semantics: 'Aiko is smiling',
    ),
    (
      reaction: DailySpendingReaction.caution,
      color: AikoColors.warningOrange,
      title: "You're close to today's limit",
      message: 'Aiko is a little worried—take care with the next expense.',
      semantics: 'Aiko looks worried',
    ),
    (
      reaction: DailySpendingReaction.exceeded,
      color: AikoColors.dangerRed,
      title: "Today's safe amount is used up",
      message: 'Aiko wants you to pause before spending more.',
      semantics: 'Aiko looks angry',
    ),
  ];

  for (final testCase in cases) {
    testWidgets('renders ${testCase.reaction.name} reaction', (tester) async {
      final semantics = tester.ensureSemantics();
      addTearDown(semantics.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AikoSpendingReactionStrip(reaction: testCase.reaction),
          ),
        ),
      );

      expect(find.text(testCase.title), findsOneWidget);
      expect(find.text(testCase.message), findsOneWidget);
      expect(find.bySemanticsLabel(testCase.semantics), findsOneWidget);

      final container = tester.widget<Container>(
        find.byKey(ValueKey('aiko-reaction-${testCase.reaction.name}')),
      );
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.color, testCase.color.withValues(alpha: 0.10));
      expect(testCase.reaction.color, testCase.color);
    });
  }
}
```

- [ ] **Step 2: Run the widget test and verify RED**

Run:

```powershell
flutter test test/features/dashboard/aiko_spending_reaction_strip_test.dart
```

Expected: FAIL because `AikoSpendingReactionStrip` and the presentation
extension do not exist.

- [ ] **Step 3: Implement the strip and custom Aiko face**

Create `aiko_spending_reaction_strip.dart` with this complete implementation:

```dart
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../theme/aiko_colors.dart';
import '../../domain/daily_spending_reaction.dart';

extension DailySpendingReactionPresentation on DailySpendingReaction {
  Color get color => switch (this) {
    DailySpendingReaction.comfortable => AikoColors.successGreen,
    DailySpendingReaction.caution => AikoColors.warningOrange,
    DailySpendingReaction.exceeded => AikoColors.dangerRed,
  };

  String get title => switch (this) {
    DailySpendingReaction.comfortable => "You're spending comfortably",
    DailySpendingReaction.caution => "You're close to today's limit",
    DailySpendingReaction.exceeded => "Today's safe amount is used up",
  };

  String get message => switch (this) {
    DailySpendingReaction.comfortable =>
      "Nice work—today's spending is in a healthy range.",
    DailySpendingReaction.caution =>
      'Aiko is a little worried—take care with the next expense.',
    DailySpendingReaction.exceeded =>
      'Aiko wants you to pause before spending more.',
  };

  String get semanticsLabel => switch (this) {
    DailySpendingReaction.comfortable => 'Aiko is smiling',
    DailySpendingReaction.caution => 'Aiko looks worried',
    DailySpendingReaction.exceeded => 'Aiko looks angry',
  };
}

class AikoSpendingReactionStrip extends StatelessWidget {
  const AikoSpendingReactionStrip({required this.reaction, super.key});

  final DailySpendingReaction reaction;

  @override
  Widget build(BuildContext context) {
    final color = reaction.color;
    return Container(
      key: ValueKey('aiko-reaction-${reaction.name}'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Semantics(
            label: reaction.semanticsLabel,
            image: true,
            child: ExcludeSemantics(
              child: CustomPaint(
                size: const Size.square(52),
                painter: _AikoReactionPainter(
                  reaction: reaction,
                  color: color,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reaction.title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  reaction.message,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AikoReactionPainter extends CustomPainter {
  const _AikoReactionPainter({
    required this.reaction,
    required this.color,
  });

  final DailySpendingReaction reaction;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 52;
    Offset point(double x, double y) => Offset(x * scale, y * scale);

    final backdrop = Paint()..color = color.withValues(alpha: 0.14);
    final outline = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2 * scale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final features = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.drawCircle(point(26, 26), 25 * scale, backdrop);
    canvas.drawCircle(point(26, 26), 24 * scale, outline);
    canvas.drawOval(
      Rect.fromCenter(
        center: point(26, 28),
        width: 30 * scale,
        height: 34 * scale,
      ),
      outline,
    );
    canvas.drawLine(point(18, 12), point(14, 6), outline);
    canvas.drawLine(point(34, 12), point(38, 6), outline);

    switch (reaction) {
      case DailySpendingReaction.comfortable:
        canvas.drawCircle(point(21, 24), 1.3 * scale, features);
        canvas.drawCircle(point(31, 24), 1.3 * scale, features);
        final smile = Path()
          ..moveTo(point(20, 31).dx, point(20, 31).dy)
          ..quadraticBezierTo(
            point(26, 36).dx,
            point(26, 36).dy,
            point(32, 31).dx,
            point(32, 31).dy,
          );
        canvas.drawPath(smile, outline);
        break;
      case DailySpendingReaction.caution:
        canvas.drawLine(point(19, 22), point(23, 21), outline);
        canvas.drawLine(point(29, 21), point(33, 22), outline);
        canvas.drawCircle(point(21, 25), 1.2 * scale, features);
        canvas.drawCircle(point(31, 25), 1.2 * scale, features);
        final worried = Path()
          ..moveTo(point(21, 34).dx, point(21, 34).dy)
          ..quadraticBezierTo(
            point(26, 30).dx,
            point(26, 30).dy,
            point(31, 34).dx,
            point(31, 34).dy,
          );
        canvas.drawPath(worried, outline);
        break;
      case DailySpendingReaction.exceeded:
        canvas.drawLine(point(18, 20), point(23, 22), outline);
        canvas.drawLine(point(34, 20), point(29, 22), outline);
        canvas.drawCircle(point(21, 25), 1.2 * scale, features);
        canvas.drawCircle(point(31, 25), 1.2 * scale, features);
        final angry = Path()
          ..moveTo(point(20, 35).dx, point(20, 35).dy)
          ..quadraticBezierTo(
            point(26, 29).dx,
            point(26, 29).dy,
            point(32, 35).dx,
            point(32, 35).dy,
          );
        canvas.drawPath(angry, outline);
        break;
    }

    final highlight = Paint()
      ..color = Colors.white.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, scale);
    canvas.drawArc(
      Rect.fromCircle(center: point(26, 26), radius: 21 * scale),
      math.pi * 1.05,
      math.pi * 0.35,
      false,
      highlight,
    );
  }

  @override
  bool shouldRepaint(covariant _AikoReactionPainter oldDelegate) =>
      reaction != oldDelegate.reaction || color != oldDelegate.color;
}
```

- [ ] **Step 4: Format and verify GREEN**

Run:

```powershell
dart format lib/features/dashboard/presentation/widgets/aiko_spending_reaction_strip.dart test/features/dashboard/aiko_spending_reaction_strip_test.dart
flutter test test/features/dashboard/aiko_spending_reaction_strip_test.dart
```

Expected: 3 widget tests PASS with no overflow or semantics errors.

- [ ] **Step 5: Commit only this task**

```powershell
git add lib/features/dashboard/presentation/widgets/aiko_spending_reaction_strip.dart test/features/dashboard/aiko_spending_reaction_strip_test.dart
git commit -m "feat: add Aiko spending reaction strip"
```

### Task 3: Integrate the Reaction with Daily Spending

**Files:**

- Modify: `lib/features/dashboard/presentation/home_dashboard_screen.dart`
- Test: `test/features/dashboard/daily_spending_reaction_test.dart`
- Test: `test/features/dashboard/aiko_spending_reaction_strip_test.dart`

- [ ] **Step 1: Add the domain and widget imports**

```dart
import '../domain/daily_spending_reaction.dart';
import 'widgets/aiko_spending_reaction_strip.dart';
```

- [ ] **Step 2: Replace the duplicated color thresholds with the shared state**

Replace:

```dart
final color = ratio >= 1
    ? AikoColors.dangerRed
    : ratio >= 0.75
    ? AikoColors.warningOrange
    : AikoColors.successGreen;
```

with:

```dart
final reaction = DailySpendingReaction.fromRatio(ratio);
final color = reaction.color;
```

- [ ] **Step 3: Insert the approved strip below the gauge**

Immediately after the centered `AikoGauge`, add:

```dart
const SizedBox(height: 12),
AikoSpendingReactionStrip(reaction: reaction),
```

Keep the existing `Divider`, metric row, card accent, and transaction tap
behavior unchanged.

- [ ] **Step 4: Format and verify the component contracts**

Run:

```powershell
dart format lib/features/dashboard/presentation/home_dashboard_screen.dart
flutter test test/features/dashboard/daily_spending_reaction_test.dart test/features/dashboard/aiko_spending_reaction_strip_test.dart
flutter analyze lib/features/dashboard
```

Expected: 6 tests PASS and dashboard analysis reports no issues.

- [ ] **Step 5: Commit only this task**

```powershell
git add lib/features/dashboard/presentation/home_dashboard_screen.dart
git commit -m "feat: react to daily spending on Home"
```

### Task 4: Remove the Standalone Pace Surface

**Files:**

- Create: `test/app/aiko_navigation_test.dart`
- Modify: `lib/app/aiko_navigation.dart`
- Modify: `lib/app/app_router.dart`
- Modify: `lib/features/overview/presentation/finance_detail_screens.dart`

- [ ] **Step 1: Write the failing Settings regression test**

```dart
import 'package:aiko/app/aiko_navigation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Settings omits the retired Pace Overview', () {
    expect(
      aikoNavigationItems.map((item) => item.path),
      isNot(contains('/settings/pace')),
    );
    expect(
      aikoNavigationItems.map((item) => item.label),
      isNot(contains('Budget: Pace')),
    );
    expect(aikoNavigationItems.first.path, '/settings/safe-to-spend');
  });
}
```

- [ ] **Step 2: Run the test and verify RED**

Run:

```powershell
flutter test test/app/aiko_navigation_test.dart
```

Expected: FAIL because `/settings/pace` is still the first Settings item.

- [ ] **Step 3: Remove the Pace Settings item**

Delete this complete entry from `aikoNavigationItems`:

```dart
AikoNavigationItem(
  label: 'Budget: Pace',
  path: '/settings/pace',
  icon: Icons.speed_outlined,
  description: 'See whether this month is on track, per category.',
  accentColor: AikoColors.warningOrange,
),
```

- [ ] **Step 4: Remove the route and screen**

Delete the `/settings/pace` `GoRoute` from `lib/app/app_router.dart`:

```dart
GoRoute(
  path: '/settings/pace',
  builder: (context, state) => const PaceOverviewScreen(),
),
```

Delete `_paceColor` and the complete `PaceOverviewScreen` class from
`lib/features/overview/presentation/finance_detail_screens.dart`. Leave
`SafeToSpendScreen` and all later detail screens in place.

- [ ] **Step 5: Format and verify GREEN**

Run:

```powershell
dart format lib/app/aiko_navigation.dart lib/app/app_router.dart lib/features/overview/presentation/finance_detail_screens.dart test/app/aiko_navigation_test.dart
flutter test test/app/aiko_navigation_test.dart
flutter analyze
```

Expected: the regression test PASSes and analysis reports no missing
`PaceOverviewScreen` references.

- [ ] **Step 6: Commit only this task**

```powershell
git add lib/app/aiko_navigation.dart lib/app/app_router.dart lib/features/overview/presentation/finance_detail_screens.dart test/app/aiko_navigation_test.dart
git commit -m "refactor: remove Pace Overview surface"
```

### Task 5: Remove Dead Pace Data Logic

**Files:**

- Modify: `lib/features/overview/application/budget_insights_service.dart`
- Modify: `test/features/overview/budget_insights_service_test.dart`
- Modify: `lib/app/providers.dart`
- Modify: `lib/features/dashboard/domain/dashboard_summary.dart`

- [ ] **Step 1: Establish the safe-to-spend safety net**

Run the retained behavior before deleting pace code:

```powershell
flutter test test/features/overview/budget_insights_service_test.dart --plain-name "safe to spend = income - spent - unspent budget"
```

Expected: PASS.

- [ ] **Step 2: Remove standalone pace models and service method**

From `budget_insights_service.dart`, delete the complete definitions whose
declarations are:

```dart
class CategoryPace
class BudgetPace
```

Also delete the method whose declaration is:

```dart
BudgetPace pace({
  required List<FinanceTransaction> transactions,
  required List<Category> categories,
  required DateTime asOf,
})
```

Keep `SafeToSpend`, `BudgetInsightsService.safeToSpend`,
`_spentByCategory`, and `_currency` unchanged.

- [ ] **Step 3: Remove only the retired pace tests**

Delete these tests from `budget_insights_service_test.dart`:

```text
pace sums spending against limits and ranks by fraction used
pace flags ahead-of-pace when usage outruns the calendar
no budgets -> pace reports no budgets
```

Keep the test helpers used by the safe-to-spend case and keep:

```text
safe to spend = income - spent - unspent budget
```

- [ ] **Step 4: Remove the unused provider and dashboard pace fields**

Delete `budgetPaceProvider` from `lib/app/providers.dart`:

```dart
final budgetPaceProvider = FutureProvider.autoDispose<BudgetPace>((ref) async {
  final transactions = await ref.watch(transactionsProvider.future);
  final categories = await ref.watch(categoriesProvider.future);
  final result = const BudgetInsightsService().pace(
    transactions: transactions,
    categories: categories,
    asOf: DateTime.now(),
  );
  ref.keepAlive();
  return result;
});
```

In `_buildDashboardSummary`, delete `totalBudget`,
`percentOfBudgetUsed`, and `daysElapsedRatio`, then construct the summary as:

```dart
return DashboardSummary(
  netWorth: Money(amount: netWorth, currency: currency),
  totalCash: Money(amount: totalCash, currency: currency),
  monthlyIncome: Money(amount: monthlyIncome, currency: currency),
  monthlySpending: Money(amount: monthlySpending, currency: currency),
  safeToSpend: Money(amount: safeToSpend, currency: currency),
);
```

Change `DashboardSummary` to:

```dart
class DashboardSummary {
  const DashboardSummary({
    required this.netWorth,
    required this.totalCash,
    required this.monthlyIncome,
    required this.monthlySpending,
    required this.safeToSpend,
  });

  final Money netWorth;
  final Money totalCash;
  final Money monthlyIncome;
  final Money monthlySpending;
  final Money safeToSpend;
}
```

Delete the complete `PaceStatus` class.

- [ ] **Step 5: Format and verify safe-to-spend remains GREEN**

Run:

```powershell
dart format lib/features/overview/application/budget_insights_service.dart test/features/overview/budget_insights_service_test.dart lib/app/providers.dart lib/features/dashboard/domain/dashboard_summary.dart
flutter test test/features/overview/budget_insights_service_test.dart test/app/providers_test.dart
flutter analyze
```

Expected: retained tests PASS and analysis reports no `BudgetPace`,
`budgetPaceProvider`, or `PaceStatus` references.

- [ ] **Step 6: Commit only this task**

```powershell
git add lib/features/overview/application/budget_insights_service.dart test/features/overview/budget_insights_service_test.dart lib/app/providers.dart lib/features/dashboard/domain/dashboard_summary.dart
git commit -m "refactor: remove unused budget pace logic"
```

### Task 6: Remove Stale Copy and Verify the Whole Change

**Files:**

- Modify: `lib/l10n/app_en.arb`
- Modify: `lib/l10n/app_th.arb`
- Modify: `README.md`

- [ ] **Step 1: Remove unused ARB keys**

Delete `pace`, `paceAhead`, and `paceOnTrack` from both ARB files. Preserve
valid JSON commas and leave unrelated localization entries untouched.

- [ ] **Step 2: Update README feature and route documentation**

Make these exact documentation changes:

```text
Settings tools: remove "Budget Pace".
Secondary routes (both lists): remove "/settings/pace".
Budgeting: replace "Pace compares velocity vs limits." with
"Daily Spending compares today's posted expenses with the daily safe amount
and shows Aiko's green, orange, or red reaction."
Insights & Predictions: remove standalone "pace" from the feature list.
```

- [ ] **Step 3: Regenerate localization output and format**

Run:

```powershell
flutter gen-l10n
```

Then format only the Dart files changed by Tasks 1–5:

```powershell
dart format lib/features/dashboard/domain/daily_spending_reaction.dart lib/features/dashboard/presentation/widgets/aiko_spending_reaction_strip.dart lib/features/dashboard/presentation/home_dashboard_screen.dart lib/app/aiko_navigation.dart lib/app/app_router.dart lib/features/overview/presentation/finance_detail_screens.dart lib/features/overview/application/budget_insights_service.dart lib/app/providers.dart lib/features/dashboard/domain/dashboard_summary.dart test/features/dashboard/daily_spending_reaction_test.dart test/features/dashboard/aiko_spending_reaction_strip_test.dart test/app/aiko_navigation_test.dart test/features/overview/budget_insights_service_test.dart
```

Expected: localization generation succeeds; generated ignored files no longer
expose the three retired keys; only feature-owned Dart files are formatted.

- [ ] **Step 4: Check retirement scope**

Run:

```powershell
rg -n "PaceOverviewScreen|budgetPaceProvider|BudgetPace|CategoryPace|PaceStatus|/settings/pace|Budget: Pace|paceAhead|paceOnTrack" lib test README.md
```

Expected: no matches. Do not remove the assistant financial-context field
named `pace`; it is a separate per-budget AI classification.

- [ ] **Step 5: Run targeted tests**

Run:

```powershell
flutter test test/features/dashboard/daily_spending_reaction_test.dart test/features/dashboard/aiko_spending_reaction_strip_test.dart test/app/aiko_navigation_test.dart test/features/overview/budget_insights_service_test.dart test/app/providers_test.dart
```

Expected: all targeted tests PASS.

- [ ] **Step 6: Run full verification**

Run:

```powershell
flutter test
flutter analyze
git diff --check ec84b4e..HEAD
```

Expected: complete test suite PASSes, analysis reports `No issues found!`, and
the diff check prints no whitespace errors.

- [ ] **Step 7: Inspect scope and commit documentation**

Run:

```powershell
git status --short
git diff -- README.md lib/l10n/app_en.arb lib/l10n/app_th.arb
```

Confirm unrelated user changes remain untouched, then commit only:

```powershell
git add README.md lib/l10n/app_en.arb lib/l10n/app_th.arb
git commit -m "docs: retire standalone budget pace"
```

- [ ] **Step 8: Final implementation audit**

Re-read
`docs/superpowers/specs/2026-07-26-daily-spending-aiko-reactions-design.md`
and confirm:

```text
[x] Pace screen, route, Settings item, provider, model, and dead tests removed
[x] Daily Spending gauge and existing metrics preserved
[x] Approved Aiko status strip inserted below the gauge
[x] Green <75%, orange 75–99%, red >=100%
[x] Smile, worried, and angry states have approved copy and semantics
[x] Loading/error and Transactions tap behavior unchanged
[x] Full tests and analyzer pass
```
