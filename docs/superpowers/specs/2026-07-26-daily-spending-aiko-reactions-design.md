# Daily Spending Aiko Reactions

**Date:** 2026-07-26  
**Status:** Approved design

## Goal

Remove the standalone Pace Overview because it overlaps with the Home screen's
Daily Spending guidance. Make Daily Spending the single place where users see
whether today's spending is comfortable, approaching its safe amount, or has
used that amount up.

## Approved Experience

Keep the existing Daily Spending gauge and add an Aiko status strip between the
gauge and the summary metrics. The strip combines a tinted Aiko face, a short
status title, and one calm sentence of guidance.

The reaction follows the gauge's existing ratio of today's posted expenses to
the daily safe amount:

| Ratio | State | Color | Expression | Title | Guidance |
| --- | --- | --- | --- | --- | --- |
| Below 75% | Comfortable | Green | Smile | You're spending comfortably | Nice work—today's spending is in a healthy range. |
| 75% to below 100% | Caution | Orange | Worried | You're close to today's limit | Aiko is a little worried—take care with the next expense. |
| 100% or more | Exceeded | Red | Angry | Today's safe amount is used up | Aiko wants you to pause before spending more. |

The card keeps its current tap behavior, loading/error treatment, gauge,
Safe This Week, Left to Save, and Cash Flow metrics.

## Components and Data Flow

1. Daily Spending continues to calculate today's posted expense total and its
   ratio against `safeToSpend / 7`.
2. A small domain mapping converts the ratio into one of the three reaction
   states. Boundary behavior is explicit: `0.75` is caution and `1.0` is
   exceeded.
3. A focused reaction-strip widget maps the state to the approved color,
   custom-drawn Aiko expression, title, and guidance.
4. The Daily Spending card passes its ratio-derived state to that widget, so
   the gauge, accent color, and Aiko reaction cannot disagree.

The custom Aiko face will follow the simple outlined character language already
used by `assets/icons/aiko_aiko.svg`; no new package or raster asset is needed.

## Pace Removal

Remove the standalone pace surface and the code that exists only to support it:

- Pace Overview screen and its private color helper
- Settings navigation item
- `/settings/pace` route
- `budgetPaceProvider`
- unused `CategoryPace`, `BudgetPace`, and `BudgetInsightsService.pace`
- standalone pace tests
- unused dashboard `PaceStatus` calculation
- README references to the removed route and standalone pace surface

Keep safe-to-spend calculations and the assistant's independent budget context;
they continue to support active features.

## Error and Edge Behavior

Daily Spending keeps its existing loading and unavailable cards. The reaction
strip is part of the successful data state and uses the same computed ratio as
the gauge. This change does not introduce a fourth visual state or a new
navigation destination.

## Testing

- Unit-test reaction mapping below, at, and above the `0.75` and `1.0`
  boundaries.
- Widget-test all three reaction-strip variants for their approved text and
  semantic color/expression state.
- Assert the Settings navigation no longer exposes Pace.
- Retain and run safe-to-spend tests after removing standalone pace cases.
- Run formatting, targeted tests, the full Flutter test suite, and
  `flutter analyze`.

## Considered Alternatives

- **Header reaction:** compact, but too little room for useful guidance.
- **Reaction inside the gauge:** visually connected, but crowds the percentage
  and today's amount.
- **Status strip:** selected because it preserves gauge readability and gives
  Aiko enough space to communicate clearly.
