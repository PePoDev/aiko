# Design system implementation

The README's [Design System](../README.md#design-system) section holds the rules (tenets, color roles, type scale, spacing, components, accessibility, QA checklist). This page maps those rules to the code that implements them, so you can find the token or widget to use.

## Files

| File | Contents |
| --- | --- |
| `lib/theme/aiko_colors.dart` | Primitive color constants (`AikoColors`) |
| `lib/theme/aiko_theme.dart` | `AikoTheme.light()` / `AikoTheme.dark()`: `ColorScheme`, scaffold color and component themes |
| `lib/theme/aiko_typography.dart` | `AikoTypography.textTheme`: Hanken Grotesk headlines, Manrope body and labels, Noto Sans Thai fallback |
| `lib/shared/widgets/` | Shared components (below) |
| `assets/icons/`, `assets/images/aiko/`, `assets/rive/` | App icon and SVG marks, Aiko PNG expressions, Rive character slot |

## Color tokens

Use theme tokens (`Theme.of(context).colorScheme`) for anything that changes between light and dark. `AikoColors` constants are for brand and semantic accents.

| Scheme role | Light | Dark |
| --- | --- | --- |
| `primary` | `primaryBlue` `#3B82F6` | `softBlue` `#93C5FD` |
| `secondary` | `deepBlue` `#1D4ED8` | `primaryBlue` `#3B82F6` |
| `tertiary` (AI/premium) | `premiumPurple` `#7C3AED` | `#B894F5` |
| `surface` | `surfacePanel` `#EEF2FF` | `surfacePanelDark` `#121C31` |
| `outline` / `outlineVariant` | `border` `#BAC3D6` / `borderSubtle` `#DCE4F8` | `#414B60` / `#293348` |
| `error` | `dangerRed` `#DC2626` | `#F87171` |
| Scaffold background | `appBackground` `#D8E0F5` | `darkNavy` `#0F172A` |

Semantic accents: `successGreen` `#16A34A`, `warningOrange` `#F59E0B`, `dangerRed` `#DC2626`, `analyticsTeal` `#0D9488`, `premiumPurple` `#7C3AED`.

`test/theme/dark_theme_guard_test.dart` fails the build if presentation or shared code uses neutral constants (`darkNavy`, `neutralInk`, `mutedText`, `surfacePanel*`, `border*`, `appBackground*`) directly. Use the scheme instead.

Category colors are stored as `#RRGGBB` strings; `AikoColors.kAikoPrimaryColorHex` is the default.

## Typography

`AikoTypography.textTheme(foreground)` builds the Material text theme from the README's type scale: Hanken Grotesk for display, headline and title styles; Manrope for body and label styles; Noto Sans Thai as the fallback so Thai renders consistently. Fonts load at runtime through `google_fonts` (nothing is bundled), so the first offline launch falls back to system fonts.

## Component themes

`AikoTheme._base` sets app-wide themes for the app bar, cards, chips, dividers, dropdown menus, filled/outlined/text/icon buttons, the FAB, inputs, list tiles, the navigation bar, progress indicators, segmented buttons, snack bars and switches. Prefer the default widget plus the theme over per-widget styling.

## Shared widgets

| Widget | File | Use for |
| --- | --- | --- |
| `FinanceCard` | `finance_card.dart` | Cards for real objects, metrics and grouped panels: title, icon tile, optional action. Never nest one inside another. |
| `PrimaryActionButton` | `finance_card.dart` | The region's one primary action |
| `AmountText` | `finance_card.dart` | A headline-size primary amount (already formatted text) |
| `AikoScreenState` (`.loading`, `.empty`, `.error`) | `screen_states.dart` | Full-screen loading, empty and error states with a recovery action |
| `AikoDetailScaffold` | `aiko_data_widgets.dart` | Detail and tool screens with an optional sticky bottom action |
| `AikoInlineNotice` | `aiko_data_widgets.dart` | Tips, warnings, notes |
| `AikoMetricCard`, `AikoMetricGrid` | `aiko_data_widgets.dart` | Metric summaries with optional progress |
| `AikoDataListCard`, `AikoDataRow` | `aiko_data_widgets.dart` | Grouped facts and settings rows |
| `AikoDonutChart`, `AikoGauge` | `aiko_data_widgets.dart` | Labeled preview charts |
| `AikoWordmark`, `AikoPrimaryButton`, `AikoSparkleBackdrop` | `aiko_idea_widgets.dart` | Brand moments on Welcome and Login |
| `CachedAvatar` | `cached_avatar.dart` | Profile photo from the local cache or the Storage URL |
| `InlineGlossaryText` | `lib/features/learning_hub/presentation/inline_glossary_text.dart` | Inline term definitions in lessons |

Charts elsewhere use `fl_chart`. Every chart needs a text summary (README rule).

## Aiko artwork

| Asset | Used by |
| --- | --- |
| `aiko.riv` in `assets/rive/` (not yet committed; see `assets/rive/README.md`) | `AikoCharacter` (moods: neutral, thinking, happy, worried, celebrating) |
| `assets/images/aiko/aiko_{welcome,thinking,happy,warning,celebrating,encouraging}.png` | PNG fallback for `AikoCharacter`; the Welcome carousel |
| `assets/icons/aiko_aiko.svg` | `AikoAvatar` |
| `assets/icons/aiko_title.svg` | Not referenced by code (the wordmark is text in `AikoWordmark`) |
| `assets/icons/app_icon.png`, `app_icon_padded.png` | Launcher-icon sources for `flutter_launcher_icons`; deliberately not bundled into the app (`pubspec.yaml` lists only the SVGs) |

Use the character where it helps (onboarding, chat, encouragement, gentle warnings), never over numbers, charts, forms or critical actions.

## Web and mobile

Web, Android and iOS run one Flutter UI. The **window width** picks the layout (`AikoBreakpoints` in `lib/shared/layout/aiko_breakpoints.dart`), never the platform, so a phone browser gets the phone layout and a tablet or desktop window gets the wide one. A change to a screen, destination or panel therefore lands on every platform at once.

| | Compact (< 840px) | Expanded (≥ 840px) |
| --- | --- | --- |
| Navigation | 60dp bottom bar: Accounts, Categories, Overview, Transactions, Aiko | `AikoSidebar`: brand, **New transaction**, the same five destinations (Overview first), Tools, then Settings and Profile. Icon rail with tooltips under 1200px, labeled from 1200px |
| Content | Full width | Centered column: Overview 1320px, Aiko chat 960px, Settings/Profile/forms 880px, everything else 1120px (`AikoBreakpoints.contentWidthFor`) |
| Overview | One column of panels | Two columns once the column is 960px wide (`AikoAdaptiveColumns`, panels dealt left/right in `_homeWidgets` order) |
| Add transaction | Floating **+** on Overview and Transactions | Sidebar **New transaction**; the floating buttons are hidden |
| Panels (pickers, editors) | Bottom sheet | Centered dialog, 560px wide (`showAikoSheet`) |
| Detail and form pages | Full-screen page | Dialog over the current screen, 760px wide, close (×) instead of back (`openAikoPage`) |

How to keep both layouts in sync:

| Do | Instead of |
| --- | --- |
| Add a primary destination to `aikoPrimaryDestinations` (and its slot in `aikoBottomBarPaths`) | Editing the bottom bar or sidebar directly |
| Add a tool to `aikoNavigationItems` (Settings list and sidebar Tools) | A second list for one layout |
| `showAikoSheet(...)` | `showModalBottomSheet(...)` |
| `openAikoPage(context, page)`, or a GoRouter route | `Navigator.push(MaterialPageRoute(...))` |
| `const AikoSheetHandle()` in a custom sheet body | A hand-drawn drag handle (it would show inside the dialog) |
| `AikoBreakpoints.isExpanded(context)` for a layout switch | Checking `kIsWeb`, `Platform.isX`, or a new pixel threshold |

`test/shared/layout/adaptive_presentation_guard_test.dart` fails the build if code outside `lib/shared/layout/` calls `showModalBottomSheet`, `MaterialPageRoute` or `CupertinoPageRoute`, or if navigation widgets (`NavigationRail`, `NavigationBar`, `BottomNavigationBar`) appear outside `lib/app/`. `test/app/aiko_navigation_test.dart` checks that the bottom bar and sidebar list the same destinations and that every destination and tool is a registered route. Before finishing UI work, look at it at a phone width (390px) and a desktop width (1440px).

## Navigation chrome

The compact bottom bar follows the README's navigation spec: flush 60dp, 1px top border, 3dp top indicator in primary blue (purple for Aiko, from the destination's `accentColor`). Sidebar entries use the same colors: a 12% tint behind the selected entry and a 3px leading indicator.
