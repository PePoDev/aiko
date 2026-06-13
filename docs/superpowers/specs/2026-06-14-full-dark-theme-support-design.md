# Full Dark Theme Support — Design

## Problem

The Aiko mobile app's theme system defines both `AikoTheme.light()` and `AikoTheme.dark()` in `lib/theme/aiko_theme.dart`, but the dark theme is essentially unused:

- 231 hardcoded color references in `lib/features/**` and `lib/shared/widgets/`
- Most screens set `Scaffold(backgroundColor: AikoColors.X)` or pass `AikoColors.X` to widgets directly
- A handful of screens explicitly hardcode light-only values like `AikoColors.appBackgroundLight`, `AikoColors.white`, or `AikoColors.darkNavy` for text
- A few screens construct a local `ColorScheme.light()` inside `build()`, breaking dark mode entirely (`goals_overview_screen.dart:387`, `transaction_form_screen.dart:2586`)

The result: dark mode renders most screens with light backgrounds, white-on-light text, and missing contrast.

## Goals

1. Every screen in `lib/features/**` and `lib/shared/widgets/**` renders correctly under both `ThemeMode.light` and `ThemeMode.dark`
2. The existing dark theme is verified, tuned, and consumed
3. Brand identity preserved (Aiko blue, success/warning/danger/purple/teal stay the same in both modes — those are brand)
4. Auth and onboarding screens are included
5. All existing tests continue to pass
6. A small static guard prevents regressions

## Non-Goals

- Adding a theme toggle to settings (separate feature)
- Generating new Aiko character assets for dark mode
- Full design system audit (color ramp accessibility, etc.)
- Backdrop tinting in dark mode (will use scaffold background)

## Strategy

### Theme Token Mapping

| Hardcoded color | Light value | Dark value | Theme token to use |
|---|---|---|---|
| `AikoColors.darkNavy` (text color) | `0xFF0F172A` | (white via theme) | `Theme.of(context).colorScheme.onSurface` |
| `AikoColors.neutralInk` (text color) | `0xFF293348` | (white via theme) | `Theme.of(context).colorScheme.onSurface` |
| `AikoColors.mutedText` | `0xFF778196` | `0xFFBAC3D6` | `Theme.of(context).colorScheme.onSurfaceVariant` |
| `AikoColors.white` (on accent) | white | darkNavy | `Theme.of(context).colorScheme.onPrimary` |
| `AikoColors.surfacePanel` (light bg) | `0xFFEEF2FF` | `0xFF121C31` | `Theme.of(context).colorScheme.surface` |
| `AikoColors.surfacePanelStrong` | `0xFFE3E9FF` | `0xFF1B2740` | `Theme.of(context).colorScheme.surfaceContainerHighest` |
| `AikoColors.border` | `0xFFBAC3D6` | `0xFF414B60` | `Theme.of(context).colorScheme.outline` |
| `AikoColors.borderSubtle` | `0xFFDCE4F8` | `0xFF293348` | `Theme.of(context).colorScheme.outlineVariant` |
| `AikoColors.appBackground` (Scaffold bg) | `0xFFD8E0F5` | `0xFF0F172A` | Theme `scaffoldBackgroundColor` (remove explicit) |
| `AikoColors.appBackgroundLight` (input fill, sheets) | `0xFFF6F8FF` | (input fill from theme) | `colorScheme.surfaceContainerHighest` or theme `inputFillColor` |

### Brand Colors to KEEP Hardcoded

These are brand identity and do not change between modes:

- `AikoColors.primaryBlue`, `deepBlue`, `softBlue`, `paleBlue`
- `AikoColors.successGreen`, `warningOrange`, `dangerRed`
- `AikoColors.premiumPurple`, `analyticsTeal`
- `AikoColors.primaryRamp`, `secondaryRamp`, `tertiaryRamp`, `neutralRamp` (gradient ramps)

### Hardcoded values to KEEP

- `Colors.white` / `AikoColors.white` for icons/text ON a colored button background (e.g. `FilledButton.styleFrom(foregroundColor: Colors.white)` on top of `AikoColors.primaryBlue`) — these are semantic `onPrimary`
- `Colors.black` used as a luminance probe for icon-color selection on accent colors (functional, not visual)
- `AikoColors.darkNavy` in gradient ramp definitions only

### Theme Improvements (Phase 1)

Audit the existing dark theme. Likely additions:

1. **Add `onSurfaceVariant` to the dark ColorScheme** — currently unset, defaults to gray. Set to a soft light gray that reads as "muted text on dark surface" (e.g. `0xFFBAC3D6`)
2. **Add `onSurface` to the light ColorScheme explicitly** — already set to `darkNavy`, but ensure the matching dark value `white` is also set (currently hardcoded `AikoColors.white` in the dark scheme)
3. **Verify contrast** for the text/bg combinations defined by the theme
4. **Document the muted color** — the existing `_base()` method takes a `mutedColor` parameter but is not exposed via the `ColorScheme`. Map `mutedText` to `colorScheme.onSurfaceVariant` in both modes. If a screen needs a different shade of muted (e.g. very faint), introduce a new theme extension token on the `ThemeData` (via `ThemeData.extensions`); otherwise use `onSurfaceVariant`
5. **Re-evaluate `inputFillColor` for dark mode** — currently `surfacePanelDarkStrong` (`0xFF1B2740`). Verify it has enough contrast with text typed into the field

If the audit reveals visual problems (e.g. cards disappear, contrast is too low), adjust the dark palette in `aiko_colors.dart` and `aiko_theme.dart`.

### Per-File Refactor (Phase 2)

Apply the mapping table to all 28 feature modules and the shared widgets directory.

**Approach per file:**

1. Find all hardcoded semantic colors listed in the table
2. Replace with `Theme.of(context).colorScheme.*` or the relevant text theme
3. For Card/surface fills: prefer `Theme.of(context).colorScheme.surface` or `surfaceContainerHighest`
4. For `Text` widgets with explicit `style: TextStyle(color: AikoColors.darkNavy)`: prefer removing the color and letting `textTheme.X.color` (from the theme) decide. If a custom shade is needed, use `colorScheme.onSurface` or `colorScheme.onSurfaceVariant`
5. For `Border` and `Outline` colors: use `colorScheme.outline` / `outlineVariant`
6. For `withValues(alpha: x)` on `AikoColors.border`: switch to `colorScheme.outline.withValues(alpha: x)`
7. For `Scaffold(backgroundColor: AikoColors.X)`: remove the `backgroundColor` line entirely — let the theme's `scaffoldBackgroundColor` apply
8. For `AppBar(backgroundColor: AikoColors.X)`: remove the `backgroundColor` line — the theme AppBarTheme uses `Colors.transparent` which lets the scaffold show through
9. For local `ColorScheme.light()` constructors in widget code (`goals_overview_screen.dart:387`, `transaction_form_screen.dart:2586`): use the current `Theme.of(context).colorScheme` instead
10. For `AppLocalizations` lookups that may need dark variants: not in scope (intl strings don't change with theme)

**Files to refactor (all under `lib/features/**/presentation/` unless noted):**

- `lib/features/aiko_assistant/presentation/aiko_assistant_screen.dart`
- `lib/features/aiko_character/presentation/aiko_avatar.dart` (uses `AikoColors.white` colorFilter)
- `lib/features/aiko_optimize/...`
- `lib/features/accounts/presentation/accounts_screen.dart`
- `lib/features/accounts/presentation/onboarding_account_form.dart`
- `lib/features/assets/...`
- `lib/features/auth/presentation/auth_screens.dart`
- `lib/features/budgets/presentation/budget_form_screen.dart`
- `lib/features/budgets/presentation/budget_overview_screen.dart`
- `lib/features/calculators/presentation/calculator_conversion_review_screen.dart`
- `lib/features/calculators/presentation/calculator_detail_screen.dart`
- `lib/features/calculators/presentation/calculator_library_screen.dart`
- `lib/features/calculators/presentation/saved_scenario_screen.dart`
- `lib/features/categories/presentation/category_editor_sheet.dart`
- `lib/features/categories/presentation/category_group_editor_sheet.dart`
- `lib/features/categories/presentation/category_management_screen.dart`
- `lib/features/categories/presentation/category_visual.dart`
- `lib/features/credit_cards/...`
- `lib/features/dashboard/presentation/home_dashboard_screen.dart`
- `lib/features/dashboard/presentation/widgets/dashboard_due_items_widget.dart`
- `lib/features/dashboard/presentation/widgets/dashboard_empty_states.dart`
- `lib/features/dashboard/presentation/widgets/calculator_shortcuts_widget.dart`
- `lib/features/dashboard/presentation/home_shell_placeholder.dart`
- `lib/features/debt_loans/presentation/debt_payoff_plan_screen.dart`
- `lib/features/devices/...`
- `lib/features/export/presentation/export_screen.dart`
- `lib/features/goals/presentation/goals_overview_screen.dart`
- `lib/features/insights/...`
- `lib/features/investments/presentation/investments_screen.dart`
- `lib/features/learning_hub/presentation/learning_hub_screen.dart`
- `lib/features/monetization/presentation/upgrade_prompt.dart`
- `lib/features/navigation/presentation/planning_screen.dart`
- `lib/features/onboarding/presentation/onboarding_screens.dart`
- `lib/features/overview/presentation/finance_detail_screens.dart`
- `lib/features/reports/...`
- `lib/features/settings/presentation/notification_settings_screen.dart`
- `lib/features/settings/presentation/profile_screen.dart`
- `lib/features/settings/presentation/settings_screen.dart`
- `lib/features/tax_center/presentation/tax_center_screen.dart`
- `lib/features/transactions/presentation/transaction_attachment_section.dart`
- `lib/features/transactions/presentation/transaction_detail_screen.dart`
- `lib/features/transactions/presentation/transaction_form_screen.dart`
- `lib/features/transactions/presentation/transaction_list_screen.dart`
- `lib/features/transactions/presentation/transaction_rules_screen.dart`
- `lib/features/transactions/presentation/transaction_split_editor.dart`
- `lib/features/travel_mode/presentation/travel_mode_screen.dart`
- `lib/shared/widgets/aiko_data_widgets.dart`
- `lib/shared/widgets/aiko_idea_widgets.dart`
- `lib/shared/widgets/expansion_placeholder_screen.dart`
- `lib/shared/widgets/feature_overview_screen.dart`
- `lib/shared/widgets/finance_card.dart`
- `lib/app/authenticated_shell.dart`

### Risks and Mitigations

| Risk | Mitigation |
|---|---|
| fl_chart widgets use hardcoded color constants | Pass `colorScheme.onSurface` / `colorScheme.primary` / theme `muted` to chart configs in each feature's chart helper; verify visually in dark mode |
| Modal/bottom sheets look wrong in dark mode | Use `colorScheme.surfaceContainerHighest` for sheet backgrounds in dark mode |
| Aiko character PNGs are light-themed | Accept the visual break; add a `darkModeAware` flag on the avatar to apply a brightness filter (`BrightnessFilter` via `ColorFilter.matrix`) — out of scope to generate new assets |
| Some text colors are intentionally custom (not `onSurface`) | Use `colorScheme.onSurfaceVariant` for muted text, but accept that some screen-specific shades may need new theme tokens |
| `withValues(alpha: x)` on hardcoded colors creates invisible-on-dark borders | Replace with `colorScheme.outline.withValues(alpha: x)` |
| Existing tests assert specific colors | Update tests to use `Theme.of(context).colorScheme.X` references or accept theme-derived colors |
| `lib/features/transactions/presentation/transaction_form_screen.dart` is very large (2700+ lines) | Refactor in passes: scan for hardcoded colors, replace systematically, then move to next file |

### Testing Strategy

1. **Build smoke test**: Run `flutter build` for both Android and iOS to ensure compilation
2. **Widget tests pass**: Run `flutter test` and fix any test that asserted hardcoded colors
3. **Manual visual sweep**: Toggle dark mode in the running app, walk through every tab and detail screen
4. **Static guard test**: Add `test/theme/dark_theme_guard_test.dart` that scans `lib/features/**/presentation/**` and `lib/shared/widgets/**` for the forbidden color names listed in the mapping table. Allow a small whitelist (button foregrounds on colored backgrounds, gradient ramps). The test fails CI if a new violation is introduced.

### Verification

Before declaring the work done, confirm:
- `flutter analyze` is clean
- `flutter test` is clean (or pre-existing failures are unchanged and unrelated)
- `flutter build apk --debug` succeeds
- `flutter build ios --debug --no-codesign` succeeds
- Visual dark mode smoke test passes
- New static guard test passes

## Open Questions

- Should `appBackgroundLight` be removed entirely from `aiko_colors.dart` after the refactor? **Proposal: remove** — the only remaining usage should be internal to the theme for `inputFillColor` light value, in which case a new private constant can replace it.
- Should `darkNavy` be removed from `aiko_colors.dart`? **Proposal: no** — it remains the light-mode text color in the theme, and is used in the dark-mode `scaffoldBackgroundColor`.
- Should `surfacePanel` and `surfacePanelStrong` be removed? **Proposal: no** — they map directly to `colorScheme.surface` and `surfaceContainerHighest` in the light theme; keeping them as the light scheme tokens preserves a single source of truth.

## Implementation Order

1. Phase 1: Theme audit and improvements (`aiko_theme.dart`, possibly `aiko_colors.dart`)
2. Phase 2a: Refactor shared widgets and shell (`lib/shared/widgets/**`, `lib/app/authenticated_shell.dart`) — these affect every screen
3. Phase 2b: Refactor each feature module one at a time, in order:
   - Bottom-tab screens (Overview, Transactions, Aiko, Planning, Settings) — highest traffic
   - Detail screens and subroutes
   - Onboarding/auth flows
4. Phase 3: Static guard test
5. Phase 4: Visual sweep and any follow-up fixes
6. Phase 5: Run all quality gates (analyze, test, format)
