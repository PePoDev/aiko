# Aiko Design System

Aiko's interface is calm, clear, and companionable: financial data stays first, while the Aiko character and AI moments add warmth without covering numbers, charts, or decisions.

This document captures the visual system from the design reference and maps it to the Flutter theme in `lib/theme/`.

## Brand Principles

- **Data first, Aiko enhanced:** balances, budgets, transactions, charts, and decisions must remain the strongest visual signal.
- **Calm confidence:** use soft surfaces, generous spacing, and restrained contrast so finance workflows feel manageable.
- **Supportive AI:** Aiko's tone is warm, clear, and non-judgmental. Avoid shame, alarmism, or vague advice.
- **Mobile native:** controls should be thumb-friendly, predictable, and compact enough for repeated daily use.

## Color Tokens

The screenshot uses a blue-led palette with purple AI accents, a deep neutral ink, and pale lavender-blue surfaces.

| Token | Hex | Use |
|---|---:|---|
| Primary | `#3B82F6` | Primary actions, active states, key highlights |
| Secondary | `#1D4ED8` | Secondary emphasis, selected navigation, deeper charts |
| Tertiary | `#7C3AED` | Aiko/AI moments, premium features, insight accents |
| Neutral | `#0F172A` | Main text, inverted surfaces, high-emphasis icons |
| Surface | `#EEF2FF` | Cards, panels, input backgrounds on light screens |
| App background | `#D8E0F5` | Design reference background, empty space between panels |
| White | `#FFFFFF` | High-contrast text on colored surfaces |

Existing Dart mappings:

```dart
AikoColors.primaryBlue   // #3B82F6
AikoColors.deepBlue      // #1D4ED8
AikoColors.premiumPurple // #7C3AED
AikoColors.darkNavy      // #0F172A
```

### Color Ramps

Use ramps for charts, progress bars, selected states, and subtle backgrounds.

| Ramp | Stops |
|---|---|
| Primary blue | `#071426`, `#0B356F`, `#0C4A9A`, `#0B5DBD`, `#1D74E8`, `#3B82F6`, `#75A4F5`, `#A5C4F6`, `#D8E5FF`, `#FFFFFF` |
| Secondary blue | `#071426`, `#0B2A7A`, `#073AA8`, `#1D4ED8`, `#4268EA`, `#6385F0`, `#8AA4F5`, `#AFC0F8`, `#DCE5FF`, `#FFFFFF` |
| Tertiary purple | `#071426`, `#240052`, `#3B0785`, `#5B0BC0`, `#6D28D9`, `#7C3AED`, `#9B67F2`, `#B894F5`, `#DCCBFF`, `#FFFFFF` |
| Neutral | `#071426`, `#0F172A`, `#293348`, `#414B60`, `#5B6578`, `#778196`, `#9BA4B8`, `#BAC3D6`, `#DCE4F8`, `#FFFFFF` |

### Semantic Colors

Keep semantic color use consistent:

| Token | Hex | Use |
|---|---:|---|
| Success | `#16A34A` | Savings progress, completed goals, positive deltas |
| Warning | `#F59E0B` | Bills, thresholds, upcoming due dates |
| Danger | `#DC2626` | Overspending, failed payments, destructive actions |
| Analytics | `#0D9488` | Portfolio, reports, analysis surfaces |

## Typography

The reference pairs a friendly geometric headline face with a softer body face:

| Role | Font | Weight | Use |
|---|---|---:|---|
| Headline | Hanken Grotesk | 700 | Screen titles, major balances, hero numbers |
| Body | Manrope | 400-600 | Paragraphs, transaction text, settings, form copy |
| Label | Manrope | 600-700 | Buttons, chips, chart labels, tabs |

Current implementation uses Flutter text styles in `AikoTypography`. If custom fonts are added later, wire them through `pubspec.yaml` and keep this role mapping.

Recommended type scale:

| Style | Size | Weight | Use |
|---|---:|---:|---|
| Display | 48 | 700 | Rare, major onboarding or report moments |
| Headline | 28 | 700 | Screen titles |
| Title | 20 | 700 | Card titles, section headers |
| Body Large | 16 | 400 | Primary readable text |
| Body | 14 | 400 | Dense lists and supporting copy |
| Label | 14 | 700 | Buttons, tabs, tags |
| Caption | 12 | 500 | Metadata, timestamps, minor chart labels |

## Spacing And Shape

Use an 8px spacing grid.

| Token | Value | Use |
|---|---:|---|
| `space-xs` | 4 | Icon/text gaps, tight metadata |
| `space-sm` | 8 | Compact rows, chips |
| `space-md` | 16 | Screen padding, form gaps |
| `space-lg` | 24 | Card groups, major sections |
| `space-xl` | 32 | Top-level screen rhythm |

Shape:

- Cards and panels: `8px` radius by default.
- Buttons and inputs: `8px` radius.
- Large decorative reference tiles may use up to `22px`, but production app surfaces should stay closer to `8px` unless there is a clear brand moment.
- Avoid nested cards. Use full-width sections, rows, dividers, or simple spacing instead.

## Surfaces

Core surfaces from the screenshot:

- App background: soft blue-lavender.
- Cards: pale blue-lavender panels with no shadow.
- Active controls: saturated blue or deep navy.
- Inputs: lightly tinted fill with a subtle stroke.

Flutter guidance:

```dart
scaffoldBackgroundColor: Color(0xFFF8FAFC); // current app default
CardThemeData(
  elevation: 0,
  margin: EdgeInsets.zero,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(8)),
  ),
);
```

## Components

### Buttons

Button styles shown in the reference:

| Variant | Background | Text | Use |
|---|---|---|---|
| Primary | `#0B63C7` or `#3B82F6` | White | Main action on a screen |
| Secondary | pale blue tint | `#0F172A` | Alternate action |
| Inverted | `#293348` | White | High-contrast action on pale panels |
| Outlined | Transparent | `#0F172A` | Lower-emphasis action |

Rules:

- Minimum height: `48px`.
- Radius: `8px`.
- Use one primary action per section.
- Use icons for common actions when the meaning is familiar: edit, search, home, profile, delete, tag, analytics.

### Inputs

Search and text fields use:

- Height around `54px`.
- Pale blue fill.
- Thin blue-gray border.
- Leading icon for search.
- Placeholder color in muted neutral.

Do not place long helper text inside inputs. Put validation or helper copy below the field.

### Navigation

The screenshot uses a pill-shaped bottom navigation container with circular active selection.

Aiko app navigation:

- Five primary tabs: Home, Transactions, Budget, Insights, Aiko.
- Active tab: blue circular icon background with white icon.
- Inactive tabs: neutral icon on pale pill background.
- Keep labels optional only if icons are universally clear; otherwise use icon plus short label.

### Progress And Charts

Reference progress bars are horizontal, rounded, and color-coded.

- Primary metric: blue.
- Secondary metric: deep blue.
- AI or premium metric: purple.
- Track: pale blue tint.
- Height: `8px` for compact bars, `10-12px` for dashboard cards.
- Never rely on color alone; pair with label or numeric value.

### Icon Buttons

Use compact square or circular icon buttons for quick actions:

- Primary icon button: blue circle, white icon.
- AI action: purple square or circle, white icon.
- Destructive action: red circle, white icon.
- Size: `40-48px`.
- Tap target: at least `48px`.

### Cards

Cards are for financial objects and repeated content:

- Account cards
- Budget cards
- Transaction rows when grouped
- Goal cards
- Aiko insight cards

Cards should include a clear hierarchy:

1. Primary number or title.
2. Supporting metadata.
3. One clear action or status.

Avoid decorative cards that do not hold a real object, metric, or action.

## Aiko Character Usage

Use Aiko purposefully:

- Onboarding welcome and completion.
- Insight explanations.
- Goal encouragement.
- Budget warnings.
- Empty states that need reassurance.
- Aiko assistant chat.

Do not place Aiko on every screen. She should not cover tables, charts, balances, forms, or critical actions.

Tone examples:

- Use: "You are still on track. Groceries are running a little high, so I found two easy places to adjust."
- Avoid: "You spent too much again."

## Accessibility

- Maintain at least 4.5:1 contrast for body text.
- Do not use purple or blue alone to communicate financial state.
- Keep tap targets at least `48x48`.
- Support dynamic text without clipping.
- Make charts readable with labels, legends, and numeric summaries.
- Support light and dark themes.

## Flutter Implementation Notes

- Keep global tokens in `lib/theme/aiko_colors.dart`.
- Keep app-wide `ThemeData` in `lib/theme/aiko_theme.dart`.
- Keep text styles in `lib/theme/aiko_typography.dart`.
- Feature widgets should consume theme values instead of hard-coding colors where practical.
- Money views must use `Money` and locale-aware formatters.
- Screens should use Riverpod providers for state and repositories for data access.

## Design QA Checklist

Before considering a new screen complete:

- Primary action is obvious.
- Financial numbers are visible before AI guidance.
- No text overlaps or clips at small mobile widths.
- Blue, purple, and semantic colors are used consistently.
- Cards are not nested inside cards.
- Empty, loading, error, and offline states are designed.
- Aiko appears only when she adds clarity, reassurance, or guidance.
- Dark theme has been considered.
