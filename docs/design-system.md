# Design system implementation

The README's [Design System](../README.md#design-system) section holds the rules (tenets, color roles, type scale, spacing, components, accessibility, QA checklist). This page maps those rules to the code that implements them, so you can find the token or widget to use.

## Files

| File | Contents |
| --- | --- |
| `lib/theme/aiko_colors.dart` | Primitive color constants (`AikoColors`) |
| `lib/theme/aiko_status_colors.dart` | `AikoStatusColors`: readable status text colors per brightness (a theme extension) |
| `lib/theme/aiko_theme.dart` | `AikoTheme.light()` / `AikoTheme.dark()`: `ColorScheme`, scaffold color, component themes and the status-color extension |
| `lib/theme/aiko_typography.dart` | `AikoTypography.textTheme`: Hanken Grotesk headlines, Manrope body and labels, Noto Sans Thai fallback, all bundled in `assets/fonts/` |
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

### Status text

The green, orange and red accents are fills: bars, chips, and icons on tinted backgrounds. Words and small icons in a status color use `AikoStatusColors.of(context)` instead, whose shades keep at least 4.5:1 contrast on the panels in each theme (`test/theme/aiko_status_colors_test.dart`):

| Token | Light | Dark |
| --- | --- | --- |
| `successText` | `#166534` | `#4ADE80` |
| `warningText` | `#92400E` | `#FBBF24` |
| `dangerText` | `#B91C1C` | `#F87171` |

`textFor(accent)` maps a status fill to its text shade and returns any other color unchanged, so code that picks an accent per state can pass it through.

`test/theme/dark_theme_guard_test.dart` fails the build if presentation or shared code uses neutral constants (`darkNavy`, `neutralInk`, `mutedText`, `surfacePanel*`, `border*`, `appBackground*`) directly. Use the scheme instead.

Category colors are stored as `#RRGGBB` strings; `AikoColors.kAikoPrimaryColorHex` is the default.

## Typography

`AikoTypography.textTheme(foreground)` builds the Material text theme from the README's type scale: Hanken Grotesk for display, headline and title styles; Manrope for body and label styles; Noto Sans Thai as the fallback so Thai renders consistently. All three are bundled. Hanken Grotesk (700) and Manrope (400, 500, 700) ship as assets under the file names `google_fonts` looks for (`assets/fonts/hanken_grotesk/`, `assets/fonts/manrope/`, SIL OFL, about 340 KB), and `AikoTypography` sets `GoogleFonts.config.allowRuntimeFetching = false`, so text looks the same offline and on the first web load. A new family or weight needs its TTF and a `pubspec.yaml` asset line; `test/theme/latin_font_test.dart` fails otherwise. Noto Sans Thai is covered in [Localization → Fonts](localization.md#fonts).

## Component themes

`AikoTheme._base` sets app-wide themes for the app bar, cards, chips, dividers, dropdown menus, filled/outlined/text/icon buttons, the FAB, inputs, list tiles, the navigation bar, progress indicators, segmented buttons, snack bars and switches. Prefer the default widget plus the theme over per-widget styling.

Filled and outlined buttons have a minimum size of 64 × 48px: 48px tall touch targets, but only as wide as their label, so they fit list-tile trailing slots and dialog action rows. A full-width call to action gets its width from its parent (a stretched `Column`, a `ListView` or a `SizedBox`). Snack bars use a dark neutral background in both themes.

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
| `CachedAvatar` | `cached_avatar.dart` | Profile photo from the local cache or the Storage URL. Each saved photo has its own cache path, so a device holding an older photo shows the URL instead |
| `aikoSnackBar`, `showAikoSnackBar` | `aiko_snack_bar.dart` | Status messages (below) |
| `AikoPageScaffold` | `aiko_snack_bar.dart` | A page with its own snack bars, shown once inside it (below) |
| `FxRatesNote` | `fx_rates_note.dart` | Small print under totals that add other currencies: what was left out for lack of a rate, and "Rates as of …" when the saved rates were used |
| `GuestSignInTile` | `lib/features/auth/presentation/guest_sign_in_tile.dart` | "Sign in to back up and sync" for guests (Profile, Settings) |
| `AikoDiscardChangesGuard`, `confirmDiscardChanges` | `discard_changes_guard.dart` | Asking before a form with unsaved input closes (below) |
| `InlineGlossaryText` | `lib/features/learning_hub/presentation/inline_glossary_text.dart` | Inline term definitions in lessons |

Charts elsewhere use `fl_chart`. Every chart needs a text summary (README rule).

## Dialogs, forms and messages

- **Pages as dialogs.** On wide screens `openAikoPage` shows the page as a dialog with `barrierDismissible: false` by default, so a click outside it or Escape doesn't close it and lose form input. Pass `true` only for read-only pages. The page's own close (×) button still closes it.
- **Unsaved input.** Wrap a form's root in `AikoDiscardChangesGuard(hasUnsavedChanges: …)`. Every way out that goes through `Navigator.maybePop` (back or close button, system back gesture, a dialog barrier) then asks "Discard changes?" first. Closing in code after a save (`Navigator.pop`, `context.pop`) is never blocked. The transaction form, account form and Profile use it.
- **Snack bars.** Build them with `aikoSnackBar(message, tone: AikoSnackTone.success)` (or `showAikoSnackBar(context, …)`). Every tone uses the theme's neutral background; the tone adds a status icon (success, warning, error) in the matching `AikoStatusColors` shade. Don't fill a snack bar with orange, green or red: white text on those fails contrast. A page opened with `openAikoPage` is a dialog over the shell on wide screens, so a snack bar shown through the app's messenger would appear twice; show the page's own messages through `AikoPageScaffold`'s `messengerKey` (the transaction form and detail do). A message meant to outlive the page ("Saved" right before it closes, or "Saved, but an attachment couldn't be kept") still goes to the app's messenger. In a dialog, `AikoPageScaffold` keeps the app's messages out of the page, so one still showing when it opens, or arriving meanwhile, appears once, on the shell behind it.
- **Destructive confirmations** name the object and the effect, and confirm with a red button (`AikoColors.dangerRed`), for example deleting a transaction, an account or the user's account.

## Aiko artwork

| Asset | Used by |
| --- | --- |
| `aiko.riv` in `assets/rive/` (not yet committed; see `assets/rive/README.md`) | `AikoCharacter` (moods: neutral, thinking, happy, worried, celebrating) |
| `assets/images/aiko/aiko_{welcome,thinking,happy,warning,celebrating,encouraging}.png` | PNG fallback for `AikoCharacter`; the Welcome carousel. If one can't load, `AikoArtFallback` (a drawn circle with an icon) takes its place |
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
