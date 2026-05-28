# Aiko Design System

Aiko is a calm, data-first personal finance app. The interface must make money, risk, progress, and next actions easy to scan before it adds personality. Aiko, the assistant character, is a guide for moments that benefit from warmth or explanation, not a decoration layer.

This file is the design source of truth for Flutter implementation. When local screen code conflicts with this document, update the screen or shared component unless there is a documented product reason.

## Product Register

Aiko is product UI, not a marketing site. The design should feel trustworthy, native, repeatable, and efficient for daily finance work.

Use:

- Familiar app patterns: app bars, bottom navigation, tabs, sheets, list rows, forms, and detail screens.
- Dense but readable information hierarchy.
- Consistent components across screens.
- Motion that explains state changes.
- AI warmth only where it clarifies, reassures, or guides a decision.

Avoid:

- Decorative gradients, glassmorphism, or ornamental cards.
- Nested cards.
- Overlarge hero sections in task screens.
- Purple/blue accents used as decoration instead of meaning.
- Aiko artwork covering financial numbers, charts, forms, or actions.
- Category-level budget inclusion controls. Budgets choose their included category; category forms do not.

## Scene And Tone

The primary use scene is a person checking money on a phone during a normal day: in line, at a desk, before paying a bill, or reviewing the month at night. The UI should reduce cognitive load, not perform.

Tone:

- Clear: show the number, label, period, and action.
- Supportive: phrase warnings as recoverable situations.
- Specific: avoid vague AI copy.
- Non-judgmental: never shame spending behavior.

Example:

- Use: "Groceries are pacing high. Lower flexible spending by $18 this week to stay on track."
- Avoid: "You overspent again."

## Design Tenets

1. Data first, Aiko enhanced.
2. One primary action per screen region.
3. Every financial number needs context: period, account, category, or status.
4. Lists should be compact by default. Detail screens can breathe.
5. Cards are for real objects, metrics, and grouped tasks, not decoration.
6. Forms use progressive disclosure. Do not expose advanced switches unless the feature owns that decision.
7. Empty states teach the next action.
8. Error states explain recovery.
9. Dark mode is a first-class theme.
10. Every tappable control has a 48px minimum touch target.

## Token Architecture

Use a three-layer token model.

| Layer | Purpose | Flutter home |
|---|---|---|
| Primitive | Raw colors, type sizes, spacing, radius | `AikoColors`, `AikoTypography` |
| Semantic | Meaning: primary, danger, surface, muted, outline | `ColorScheme`, theme extensions where needed |
| Component | Button, card, input, sheet, chip, nav specs | `AikoTheme`, shared widgets |

Do not add one-off colors or radii to feature screens when a token or theme value exists.

## Color System

### Primitive Tokens

| Token | Hex | Use |
|---|---:|---|
| Primary Blue | `#3B82F6` | Primary actions, selected state, active nav |
| Deep Blue | `#1D4ED8` | Strong selection, key charts, high-emphasis blue |
| Soft Blue | `#93C5FD` | Dark mode primary, soft highlights |
| Pale Blue | `#EFF6FF` | Info surfaces, subtle backgrounds |
| Premium Purple | `#7C3AED` | AI, premium, optimization, Aiko-specific moments |
| Dark Navy | `#0F172A` | Light mode primary text, dark scaffold |
| Neutral Ink | `#293348` | Secondary text on light surfaces, snackbar background |
| Muted Text | `#778196` | Metadata and helper text |
| App Background | `#D8E0F5` | Light scaffold |
| App Background Light | `#F6F8FF` | Light alternate screen background |
| Surface Panel | `#EEF2FF` | Cards and panels |
| Surface Panel Strong | `#E3E9FF` | Stronger cards, selected panels |
| Border | `#BAC3D6` | Visible borders |
| Border Subtle | `#DCE4F8` | Dividers and quiet outlines |
| Success Green | `#16A34A` | Income, savings, completed, positive trend |
| Warning Orange | `#F59E0B` | Bills, due soon, budget caution |
| Danger Red | `#DC2626` | Overspending, destructive actions, errors |
| Analytics Teal | `#0D9488` | Portfolio, reports, analysis |

### Semantic Color Rules

- Primary blue means "current", "continue", or "main action".
- Purple means Aiko, AI, optimization, premium, or review.
- Green means positive money movement or completed progress.
- Orange means attention needed soon.
- Red means destructive, failed, overdue, or materially over limit.
- Teal means analysis, allocation, portfolio, or reports.
- Never rely on color alone. Pair semantic color with text, icon, or number.
- Inactive states must be neutral, not pale saturated variants.

### Dark Theme

| Token | Light | Dark | Notes |
|---|---:|---:|---|
| Primary | `#3B82F6` | `#93C5FD` | Softer blue on navy |
| Secondary | `#1D4ED8` | `#3B82F6` | Clear selected state |
| Tertiary | `#7C3AED` | `#B894F5` | AI contrast |
| Scaffold | `#D8E0F5` | `#0F172A` | Main background |
| Surface | `#EEF2FF` | `#121C31` | Cards and sheets |
| Surface Strong | `#E3E9FF` | `#1B2740` | Selected panels |
| Outline | `#BAC3D6` | `#414B60` | Visible borders |
| Outline Variant | `#DCE4F8` | `#293348` | Subtle dividers |
| Success | `#16A34A` | `#4ADE80` | Positive state |
| Warning | `#F59E0B` | `#FBBF24` | Caution state |
| Danger | `#DC2626` | `#F87171` | Error/destructive state |
| Analytics | `#0D9488` | `#2DD4BF` | Data analysis |

## Typography

Current implementation uses:

| Role | Font | Use |
|---|---|---|
| Headline | Hanken Grotesk | Screen titles, major balances, hero numbers |
| Body | Manrope | Body text, forms, lists, settings |
| Label | Manrope | Buttons, chips, tabs, metadata |

Type scale:

| Theme style | Size | Weight | Use |
|---|---:|---:|---|
| `displayLarge` | 48 | 700 | Rare onboarding or report moments |
| `headlineLarge` | 36 | 700 | Major balance or summary number |
| `headlineMedium` | 28 | 700 | Screen-level headline when inside body |
| `titleLarge` | 20 | 700 | App bar title, card title |
| `titleMedium` | 16 | 700 | Section title, prominent row title |
| `titleSmall` | 14 | 700 | Dense list title |
| `bodyLarge` | 16 | 400 | Primary readable text |
| `bodyMedium` | 14 | 400 | Default body and list metadata |
| `bodySmall` | 12 | 500 | Metadata, helper text |
| `labelLarge` | 14 | 700 | Buttons and tabs |
| `labelMedium` | 12 | 700 | Chips, badges, compact labels |
| `labelSmall` | 11 | 700 | Dense status labels |

Rules:

- Letter spacing is `0`.
- Use tabular figures for aligned money tables if a screen introduces custom numeric columns.
- Keep body line length readable. Long educational copy should not run edge-to-edge on tablets.
- Do not use display-scale text inside compact cards, lists, sidebars, settings rows, or form controls.

## Spacing, Shape, And Density

Spacing follows a 4/8px rhythm.

| Token | Value | Use |
|---|---:|---|
| `space-1` | 4 | Icon/text gaps, dense metadata |
| `space-2` | 8 | Row gaps, chip gaps |
| `space-3` | 12 | Compact card internals |
| `space-4` | 16 | Screen gutters, form gaps, default card padding |
| `space-5` | 20 | Prominent card padding |
| `space-6` | 24 | Section gaps |
| `space-8` | 32 | Major screen rhythm |

Shape:

- Cards, rows, inputs, chips, segmented controls: 8px radius.
- Bottom sheets: 20px top radius.
- Floating action buttons may use 16px radius because Material uses larger affordance shapes.
- Avoid 20px+ radii in normal product cards.
- Avoid decorative shadows. Prefer borders and surface contrast.

Density:

- Daily-use list screens are compact.
- Detail screens use more vertical rhythm.
- Dashboard uses fewer, stronger metrics rather than many equal cards.
- Settings uses grouped list rows.
- Forms use full-width controls and consistent 16px gaps.

## Surface Model

Use surfaces by job:

| Surface | Use |
|---|---|
| Scaffold | Full screen background |
| Surface panel | Cards, sheets, grouped controls |
| Surface strong | Selected cards, high-emphasis panels |
| Input fill | Text fields, search fields, dropdown-like pickers |
| Border subtle | Dividers, non-selected outlines |
| Border | Focusable or higher-emphasis outlines |

Surface rules:

- Do not put cards inside cards.
- If content is visually related inside a card, use internal rows and dividers.
- If a screen needs several repeated objects, use list tiles or object cards, not section cards wrapping object cards.
- Keep empty/loading/error states on scaffold or a single panel, never nested inside a decorative card.

## Screen Archetypes

### Dashboard

Examples: Home, Budget overview, Portfolio overview.

- Lead with one primary financial summary.
- Follow with 2-4 supporting metrics.
- Use Aiko only for explanation or a useful suggestion.
- Keep charts labelled with numbers and periods.
- Avoid long copy before data.

### List And Detail

Examples: Transactions, Accounts, Categories, Bills, Goals.

- List rows should be compact, scannable, and tappable.
- Leading icon or mark identifies type.
- Title, subtitle, amount/status, and chevron are enough for most rows.
- Detail screens show the primary number or title first, then grouped facts.
- Destructive actions live in app bar menus or separated danger sections.

### Form

Examples: Add transaction, Budget form, Profile, Add category.

- Required controls appear before optional details.
- Use full-width form fields.
- Use custom pickers only when native dropdowns hide important context.
- Helper text goes under controls, not inside placeholders.
- Save buttons stay visually primary.
- Category forms do not control budget inclusion. Budget forms own category inclusion.

### Settings

Examples: Settings, Notifications, Profile.

- Use grouped rows.
- Each row has icon, title, short description, and status/control when needed.
- Avoid cards inside cards.
- Security and destructive actions are visually separated.
- External navigation rows use chevrons.

### Assistant And AI

Examples: Aiko assistant, Aiko optimize, Aiko review.

- AI responses should cite the financial context they used.
- Suggestions need an action or a reason to dismiss.
- Purple identifies AI, but important financial states still use semantic colors.
- Avoid chatty filler before the answer.

### Planning And Education

Examples: Goals, Learning Hub, Calculators, Reports.

- Use progressive disclosure.
- Show progress, completion, or saved state.
- Calculators show inputs, result, and conversion action in that order.
- Reports show chart summary text before or beside chart visuals.

### Placeholder And Expansion Screens

- Placeholder screens must state what the feature will do and give one next action.
- They should not look like finished dashboards with fake metrics.
- Use `AikoScreenState` or `AikoFeatureOverviewScreen` for consistency.

## Component Specifications

### FinanceCard

Use for financial objects, metrics, and grouped task panels.

| Property | Spec |
|---|---|
| Radius | 8px |
| Padding | 16px default, 20px prominent |
| Border | Theme outline variant |
| Shadow | None by default |
| Title | `titleMedium` |
| Body | `bodyMedium` |
| Icon tile | 40px square, 8px radius, accent at 12 percent opacity |
| Tap state | Stable `InkWell`, no layout-shifting scale |

Do not use `FinanceCard` as a decorative wrapper around another card or list of cards.

### Buttons

| Variant | Use |
|---|---|
| Filled | Primary action |
| Outlined | Secondary action |
| Text | Low-emphasis inline action |
| IconButton | Familiar command such as edit, delete, search, close |

Rules:

- Minimum height: 48px.
- Radius: 8px.
- Use icons for familiar commands.
- Do not create text-only rounded rectangles where a standard icon button is clearer.
- Disabled state must be visibly disabled and non-interactive.

### Inputs And Pickers

- Text fields use visible labels.
- Minimum height: 54px.
- Radius: 8px.
- Focus border uses primary.
- Error border uses danger.
- Custom pickers show selected value plus context, such as category group or account balance.
- Bottom-sheet picker rows are compact `ListTile` style rows with selected checkmark.

### Lists

- Use compact `ListTile` rows for repeated entities.
- Minimum tap target remains 48px.
- Title is single-line unless the entity name genuinely needs wrapping.
- Amounts/statuses align trailing.
- Use dividers or card borders, not nested containers.

### Chips And Badges

- Use chips for filters, tags, and small statuses.
- Status color must match semantic meaning.
- Use text plus color, not color alone.
- Keep labels short.

### Navigation

Primary shell tabs:

- Home
- Transactions
- Aiko
- Planning
- Settings

Rules:

- Bottom nav remains predictable and always visible inside the authenticated shell.
- Active state uses primary color with white active icon.
- Secondary feature routes live in Settings or Planning groups, not a separate hub screen.
- If a screen links to another screen, use explicit icon, label, and route.

### Sheets And Dialogs

- Use bottom sheets for mobile creation/editing flows.
- Use dialogs for destructive confirmation only.
- Bottom sheets use 20px top radius, drag handle, safe area, and scrollable content.
- Destructive dialogs state the object being removed and the effect.
- Avoid modal flows when inline controls are enough.

### Charts And Progress

- Every chart needs a text summary.
- Every progress bar needs current, target, and period.
- Use semantic color and label together.
- Track color uses outline variant or surface strong.
- Progress height: 8px compact, 10-12px dashboard.

### Empty, Loading, Error, Offline

Use `AikoScreenState` unless a screen needs a specialized state.

| State | Requirement |
|---|---|
| Loading | Skeleton or quiet progress, no fake data |
| Empty | Explain what is missing and provide one action |
| Error | State what failed and how to retry or recover |
| Offline | Explain local/offline mode clearly |
| Locked | Explain authentication requirement |

## Screen Ownership Rules

- Categories own naming, type, group, icon, color, and active/archive state.
- Budgets own category inclusion, limits, periods, rollover, and alerts.
- Transactions own account, category, amount, merchant, notes, tags, receipt, voice, and split data.
- Accounts own balances, currency, account type, active state, and net-worth inclusion.
- Settings owns app configuration, profile, privacy, security, sync, notification, and route links.
- Aiko screens own AI explanation, suggestions, review, optimization, and chat.

## Motion And Interaction

Durations:

| Motion | Duration | Curve |
|---|---:|---|
| Tap/pressed feedback | 80-150 ms | Material state layer |
| Small reveal | 150-200 ms | `Curves.easeOut` |
| Sheet entrance | 250-300 ms | `Curves.easeOut` |
| Page transition | 250-300 ms | `Curves.easeInOut` |
| Progress fill | 300-400 ms | `Curves.easeInOut` |

Rules:

- Animate opacity and transform, not layout size.
- Do not animate financial numbers while a user is reading them.
- Avoid continuous looping animation except loading indicators.
- Respect reduced-motion settings where custom animation is added.
- No hover-only affordances.

## Accessibility

- Body text contrast: at least 4.5:1.
- Secondary text contrast: at least 3:1.
- Touch targets: at least 48x48.
- Focus indicators must be visible.
- Icon-only buttons need semantic labels or tooltips.
- Color never carries meaning alone.
- Text must not clip with dynamic type.
- Charts need labels, legends, or summaries.
- Form errors appear near the relevant field.
- Toasts/snackbars should not be the only record of important changes.

## Flutter Implementation Rules

- Theme values live in `lib/theme/aiko_colors.dart`, `lib/theme/aiko_theme.dart`, and `lib/theme/aiko_typography.dart`.
- Shared UI primitives live in `lib/shared/widgets/`.
- Feature screens consume shared primitives instead of re-creating card, button, empty-state, or picker styles.
- Use `Money` for all money values.
- Use Riverpod providers for state.
- Screens do not call persistence APIs directly.
- Prefer `AikoScreenState` for loading, empty, error, offline, locked, and permission states.
- When adding a custom component, cover default, pressed, focused, disabled, loading, error, and success where applicable.

## Route And Screen Application Map

Apply the system in batches:

1. Shared foundation: `FinanceCard`, `AikoScreenState`, action buttons, icon tiles, shell navigation.
2. Core daily screens: Home, Transactions, Add transaction, Budget, Settings.
3. Money object screens: Accounts, Categories, Goals, Bills, Credit Cards, Debt.
4. Wealth and planning screens: Portfolio, Assets, Tax Center, Reports, Export, Travel Mode.
5. Aiko and learning screens: Aiko Assistant, Aiko Optimize, Aiko Review, Learning Hub, Subscription Plan.
6. Placeholder screens: Accounting, import/export, calculators, saved scenarios, future expansion screens.

## Per-Screen QA Checklist

Before a screen is considered design-complete:

- The main user task is visible in the first viewport.
- The primary action is obvious.
- Financial numbers appear before AI guidance.
- Each number has context: date, account, category, period, or target.
- Lists are compact and tappable.
- Form fields have labels and recovery-oriented validation.
- Empty, loading, error, and offline states are present or intentionally inherited.
- There are no nested cards.
- There are no decorative shadows or oversized radii.
- Raw colors are limited to theme files or explicit data visualization needs.
- Text does not overlap or clip at small phone widths.
- Dark theme has enough contrast.
- Aiko appears only when useful.

