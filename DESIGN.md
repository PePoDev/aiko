# Aiko Design System

Aiko is a calm, data-first personal finance app. The UI must make money, risk, progress, and next actions easy to scan before it adds personality. Aiko, the assistant character, appears only where warmth or explanation helps a user decide.

This is the Flutter design source of truth. If screen code conflicts with this file, update the screen or shared component unless product requirements say otherwise.

## Product Register

Aiko is product UI, not a marketing site. It should feel trustworthy, native, repeatable, and efficient for daily finance work.

Use familiar app patterns, dense but readable hierarchy, consistent components, explanatory motion, and AI warmth only when it clarifies, reassures, or guides a decision.

Avoid decorative gradients, glassmorphism, ornamental cards, nested cards, oversized task-screen heroes, meaningless purple/blue accents, and Aiko artwork covering numbers, charts, forms, or actions. Category forms do not control budget inclusion; budget forms own it.

## Voice And Tenets

Tone is clear, supportive, specific, and non-judgmental.

Use: "Groceries are pacing high. Lower flexible spending by $18 this week to stay on track."

Avoid: "You overspent again."

Design tenets:

1. Data first, Aiko enhanced.
2. One primary action per screen region.
3. Every financial number needs context: period, account, category, target, or status.
4. Lists are compact by default; detail screens can breathe.
5. Cards represent real objects, metrics, or grouped tasks.
6. Forms disclose advanced controls only when the feature owns that choice.
7. Empty states teach the next action; errors explain recovery.
8. Dark mode is first-class.
9. Every tappable control has a 48px minimum touch target.

## Tokens

Use a three-layer model:

| Layer | Purpose | Flutter home |
|---|---|---|
| Primitive | Raw colors, type sizes, spacing, radius | `AikoColors`, `AikoTypography` |
| Semantic | Meaning: primary, danger, surface, muted, outline | `ColorScheme`, theme extensions |
| Component | Button, card, input, sheet, chip, nav specs | `AikoTheme`, shared widgets |

Do not add one-off colors or radii to feature screens when a token or theme value exists.

Document roles:

| File | Role |
|---|---|
| `PRODUCT.md` | Scope, coverage, acceptance criteria |
| `DESIGN.md` | Visual system, screen patterns, component rules, QA |
| `README.md` | Setup, architecture rules, implementation map |

When files conflict, use `PRODUCT.md` for product behavior and `DESIGN.md` for UI behavior and appearance.

## Color

Primitive and semantic colors:

| Role | Light | Dark | Use |
|---|---:|---:|---|
| Primary | `#3B82F6` | `#93C5FD` | Primary actions, selected state, active nav |
| Secondary | `#1D4ED8` | `#3B82F6` | Strong selection, key blue charts |
| AI/Premium | `#7C3AED` | `#B894F5` | Aiko, AI, optimization, premium |
| Scaffold | `#D8E0F5` | `#0F172A` | Main background |
| Alternate scaffold | `#F6F8FF` | `#0F172A` | Light alternate screens |
| Surface | `#EEF2FF` | `#121C31` | Cards, sheets, grouped controls |
| Surface strong | `#E3E9FF` | `#1B2740` | Selected or high-emphasis panels |
| Text primary | `#0F172A` | theme on-surface | Primary text |
| Text secondary | `#293348` | theme on-surface-variant | Secondary text |
| Text muted | `#778196` | theme muted | Metadata and helper text |
| Outline | `#BAC3D6` | `#414B60` | Focusable or visible borders |
| Outline subtle | `#DCE4F8` | `#293348` | Dividers and quiet outlines |
| Success | `#16A34A` | `#4ADE80` | Income, savings, completed, positive trend |
| Warning | `#F59E0B` | `#FBBF24` | Bills, due soon, budget caution |
| Danger | `#DC2626` | `#F87171` | Errors, destructive actions, overspending |
| Analytics | `#0D9488` | `#2DD4BF` | Reports, portfolio, allocation, analysis |

Rules:

- Primary blue means current, continue, or main action.
- Overview and Transactions app-bar action icons use the primary action color so action treatment stays consistent across daily workflows.
- Purple is reserved for Aiko, AI, optimization, premium, or review.
- Green, orange, red, and teal keep their semantic finance meanings.
- Never rely on color alone. Pair color with text, icon, label, or number.
- Inactive states are neutral, not pale saturated variants.

### Color Ramps

Use 10-stop ramps for charts, progress bars, and selected states:

| Ramp | Stops |
|---|---|
| Primary blue | `#071426`, `#0B356F`, `#0C4A9A`, `#0B5DBD`, `#1D74E8`, `#3B82F6`, `#75A4F5`, `#A5C4F6`, `#D8E5FF`, `#FFFFFF` |
| Secondary blue | `#071426`, `#0B2A7A`, `#073AA8`, `#1D4ED8`, `#4268EA`, `#6385F0`, `#8AA4F5`, `#AFC0F8`, `#DCE5FF`, `#FFFFFF` |
| Tertiary purple | `#071426`, `#240052`, `#3B0785`, `#5B0BC0`, `#6D28D9`, `#7C3AED`, `#9B67F2`, `#B894F5`, `#DCCBFF`, `#FFFFFF` |
| Neutral | `#071426`, `#0F172A`, `#293348`, `#414B60`, `#5B6578`, `#778196`, `#9BA4B8`, `#BAC3D6`, `#DCE4F8`, `#FFFFFF` |

Aiko character artwork should be tested on both dark and light backgrounds. Use a subtle glow or border if the artwork has transparent regions that blend into dark surfaces.

## Typography

| Role | Font | Use |
|---|---|---|
| Headline | Hanken Grotesk | Screen titles, major balances, hero numbers |
| Body | Manrope | Body text, forms, lists, settings |
| Label | Manrope | Buttons, chips, tabs, metadata |

| Theme style | Size | Weight | Use |
|---|---:|---:|---|
| `displayLarge` | 48 | 700 | Rare onboarding or report moments |
| `headlineLarge` | 36 | 700 | Major balance or summary number |
| `headlineMedium` | 28 | 700 | Screen-level headline inside body |
| `titleLarge` | 20 | 700 | App bar title, card title |
| `titleMedium` | 16 | 700 | Section title, prominent row title |
| `titleSmall` | 14 | 700 | Dense list title |
| `bodyLarge` | 16 | 400 | Primary readable text |
| `bodyMedium` | 14 | 400 | Default body and metadata |
| `bodySmall` | 12 | 500 | Helper text |
| `labelLarge` | 14 | 700 | Buttons and tabs |
| `labelMedium` | 12 | 700 | Chips and badges |
| `labelSmall` | 11 | 700 | Dense status labels |

Letter spacing is `0`. Use tabular figures for aligned money columns. Do not use display-scale text inside compact cards, lists, settings rows, sidebars, or form controls.

## Spacing, Shape, Surfaces

Spacing follows a 4/8px rhythm:

| Token | Value | Use |
|---|---:|---|
| `space-1` | 4 | Icon/text gaps, dense metadata |
| `space-2` | 8 | Row and chip gaps |
| `space-3` | 12 | Compact card internals |
| `space-4` | 16 | Screen gutters, form gaps, default card padding |
| `space-5` | 20 | Prominent card padding |
| `space-6` | 24 | Section gaps |
| `space-8` | 32 | Major screen rhythm |

Shape and surface rules:

- Cards, rows, inputs, chips, segmented controls: 8px radius.
- Bottom sheets: 20px top radius.
- FABs may use 16px radius.
- Avoid 20px+ radii in product cards and decorative shadows.
- Use scaffold, surface, surface strong, input fill, outline subtle, and outline by job.
- Do not put cards inside cards. Use rows and dividers for related content inside one card.
- Repeated objects use list tiles or object cards, not section cards wrapping cards.

Density rules: daily lists are compact, detail screens breathe, dashboard uses fewer stronger metrics, settings use grouped rows, and forms use full-width controls with consistent 16px gaps.

## Screen Archetypes

| Archetype | Examples | Rules |
|---|---|---|
| Dashboard | Home, Budget overview, Portfolio overview | Lead with one primary financial summary, then 2-4 supporting metrics. Put data before copy. Label charts with numbers and periods. |
| List and detail | Transactions, Accounts, Categories, Bills, Goals | Compact tappable rows with type mark, title, subtitle, trailing amount/status, and chevron. Details lead with primary number/title and grouped facts. |
| Form | Add transaction, Budget form, Profile, Add category | Required controls first, full-width fields, helper text under controls, primary save button, progressive disclosure. |
| Settings | Settings, Notifications, Profile | Grouped rows with icon, title, short description, and status/control. Separate security and destructive actions. |
| Assistant and AI | Aiko assistant, Optimize, Review | Cite financial context, give actions or dismiss reasons, avoid filler, keep finance states semantic even when AI uses purple. |
| Planning and education | Goals, Learning Hub, Calculators, Reports | Use progressive disclosure. Show progress or saved state. Calculators show input, result, conversion action. Reports pair chart visuals with summary text. |
| Supplemental tools | Filters, split transaction, receipt review, cash flow, loan calculator, profile security | Extend an owning feature, never duplicate top-level screens. First viewport shows the task object. Required completion actions use sticky bottom bars on mobile. |
| Placeholders | Expansion screens | State what the feature will do and provide one action. Do not show fake finished dashboards. Prefer `AikoScreenState` or `AikoFeatureOverviewScreen`. |

## Components

`FinanceCard` is for financial objects, metrics, and grouped task panels: 8px radius, 16px default padding, 20px prominent padding, outline-variant border, no default shadow, `titleMedium` title, `bodyMedium` body, 40px icon tile with 8px radius and 12 percent accent opacity, stable `InkWell` tap state. Never use it as a decorative wrapper around another card.

Cards carry a strict three-tier hierarchy:

1. Primary number or title.
2. Supporting metadata.
3. One clear action or status.

Avoid decorative cards that do not hold a real object, metric, or action.

Buttons: filled for primary, outlined for secondary, text for low-emphasis inline actions, icon buttons for familiar commands. Minimum height is 48px, radius is 8px, disabled state must be visible and non-interactive, and familiar commands should use icons.

Icon buttons: 40–48px touch target, 48px minimum tap target. Use circular tiles for primary and destructive actions, square or circular tiles for AI actions.

| Icon button | Style |
|---|---|
| Primary | Blue circle, white icon |
| AI / premium | Purple square or circle, white icon |
| Destructive | Red circle, white icon |

Inputs and pickers: visible labels, 54px minimum height, 8px radius, pale blue fill, thin blue-gray border, leading icon for search, primary focus border, danger error border. Placeholder text uses muted neutral. Do not place long helper text inside inputs — put validation or helper copy below the field. Custom pickers show selected value plus context such as category group or account balance. Bottom-sheet pickers use compact list rows with selected checkmarks.

Lists: compact `ListTile` rows, 48px tap target, single-line titles unless needed, trailing amounts/statuses aligned, dividers or card borders instead of nested containers.

Chips and badges: short labels for filters, tags, and small statuses. Status color must match semantic meaning and include text.

Navigation: authenticated shell tabs are Overview, Transactions, Aiko, Planning, Settings. Bottom nav stays visible, active state uses primary with white active icon, secondary feature routes live in Planning or Settings groups.

Overview layout editing is a scrollable in-page action labeled `Edit layout` / `Done` at the bottom of Overview content. Keep the Overview app bar reserved for utility navigation such as notifications.

Sheets and dialogs: use bottom sheets for mobile creation/editing and dialogs for destructive confirmation. Sheets need drag handle, safe area, scrollable content, and 20px top radius. Destructive dialogs name the object and effect.

Charts and progress: every chart needs a text summary. Every progress bar needs current, target, and period. Use semantic color plus label. Progress height is 8px compact and 10-12px on dashboards.

Interactive states:

| State | Treatment |
|---|---|
| Pressed / splash | Primary color at 12% opacity |
| Hover (web/desktop) | Surface tint at 8% opacity |
| Focused | 2px primary outline offset by 2px |
| Disabled | 40% opacity, no interaction |
| Dragging | Slight scale (1.02) with subtle shadow |

States: use `AikoScreenState` unless specialized. Loading uses skeleton/quiet progress with no fake data. Empty explains what is missing and gives one action. Error explains retry/recovery. Offline explains local mode. Locked explains authentication.

## Shared Widgets

Use `lib/shared/widgets/aiko_data_widgets.dart` for idea-backed supplemental screens and new finance detail screens.

| Widget | Use |
|---|---|
| `AikoDetailScaffold` | Detail/tool screens with app bar, scroll body, optional sticky bottom action |
| `AikoInlineNotice` | Aiko tips, warnings, review notes, contextual explanations |
| `AikoMetricCard` / `AikoMetricGrid` | Compact financial summaries |
| `AikoProgressBar` / `AikoProgressRow` | Budget, debt, goal, portfolio, tax progress |
| `AikoDataListCard` / `AikoDataRow` | Grouped facts and settings-style rows |
| `AikoMiniBarChart`, `AikoDonutChart`, `AikoGauge`, `AikoSankeyPreview` | Lightweight labeled preview charts |

Prefer shared widgets over local one-off cards or painters. Do not nest `AikoDataListCard`. Use sticky bottom actions through `AikoDetailScaffold.bottomBar` unless a feature already has a pattern.

## Iconography

Use Material Icons as the primary icon set. Custom SVG icons are acceptable for brand moments (Aiko logo, onboarding illustrations) but should not replace standard icons for common actions.

Sizes:

| Context | Size |
|---|---:|
| Inline with body text | 16 |
| List tile leading | 20 |
| Action bar / toolbar | 24 |
| Empty state / hero | 48 |

Icon color rules:

| Context | Color |
|---|---|
| Default | `onSurface` |
| Active / selected | `primary` |
| Destructive | `danger` |
| AI / premium | `tertiary` |
| Muted / disabled | `mutedText` |

## Aiko Character Usage

Use Aiko purposefully. She adds warmth, reassurance, or guidance — never decoration.

Use Aiko for:

- Onboarding welcome and completion.
- Insight explanations.
- Goal encouragement.
- Budget warnings.
- Empty states that need reassurance.
- Aiko assistant chat.

Do not place Aiko on every screen. She must not cover tables, charts, balances, forms, or critical actions.

Tone:

- Use: "You are still on track. Groceries are running a little high, so I found two easy places to adjust."
- Avoid: "You spent too much again."

## Ownership

| Owner | Owns |
|---|---|
| Categories | Name, type, group, icon, color, active/archive state |
| Budgets | Category inclusion, limits, periods, rollover, alerts |
| Transactions | Account, category, amount, merchant, notes, tags, receipt, voice, split data |
| Accounts | Balances, currency, account type, active state, net-worth inclusion |
| Settings | App config, profile, privacy, security, sync, notification, route links |
| Aiko | AI explanation, suggestions, review, optimization, chat |
| Dashboard | In-page monthly overview, scrollable layout customization, notifications, cross-feature summaries |
| Reports | Generated summaries and monthly report presentation |
| Calculators | Inputs, results, saved scenarios, conversion actions |
| Portfolio | Holdings and allocation detail |
| Assets/net worth | Household asset summaries |
| Debt/credit | Payoff, utilization, loan, statement detail states |

## Motion And Accessibility

Motion:

| Motion | Duration | Curve |
|---|---:|---|
| Tap feedback | 80-150 ms | Material state layer |
| Small reveal | 150-200 ms | `Curves.easeOut` |
| Sheet / modal entrance | 250-300 ms | `Curves.easeOut` |
| Page transition | 250-300 ms | `Curves.easeInOut` |
| Progress fill | 300-400 ms | `Curves.easeInOut` |
| Emphasis (celebrate, alert) | ~600 ms | `Curves.elasticOut` |

Animate opacity and transform, not layout size. Do not animate financial numbers while users read them — settle within 300 ms. Use `AnimatedSwitcher` for state transitions (loading to loaded, empty to populated). Avoid continuous looping animation except loading indicators. Respect reduced motion. No hover-only affordances.

Accessibility:

- Body text contrast: at least 4.5:1; secondary text: at least 3:1.
- Touch targets: at least 48x48.
- Focus indicators must be visible.
- Icon-only buttons need semantic labels or tooltips.
- Color never carries meaning alone.
- Text must not clip with dynamic type.
- Charts need labels, legends, or summaries.
- Form errors appear near the relevant field.
- Snackbars/toasts are not the only record of important changes.

## Flutter Rules

- Theme values live in `lib/theme/aiko_colors.dart`, `lib/theme/aiko_theme.dart`, and `lib/theme/aiko_typography.dart`.
- Shared UI primitives live in `lib/shared/widgets/`.
- Feature screens consume shared primitives instead of re-creating card, button, empty-state, or picker styles.
- Idea-backed detail/tool screens use `AikoDetailScaffold` and `lib/shared/widgets/aiko_data_widgets.dart`.
- Use `Money` for money values.
- Use Riverpod providers for state.
- Screens do not call persistence APIs directly.
- Prefer `AikoScreenState` for loading, empty, error, offline, locked, and permission states.
- Custom components cover default, pressed, focused, disabled, loading, error, and success where applicable.
- Required SVG assets are covered by `test/shared/widgets/aiko_svg_assets_test.dart`.
- Supplemental route coverage lives in `test/app/idea_route_coverage_test.dart`.

## Route And Idea Coverage

Apply the system in batches:

1. Shared foundation: `FinanceCard`, `AikoScreenState`, action buttons, icon tiles, shell navigation.
2. Core daily screens: Home, Transactions, Add transaction, Budget, Settings.
3. Money object screens: Accounts, Categories, Goals, Bills, Credit Cards, Debt.
4. Wealth/planning screens: Portfolio, Assets, Tax Center, Reports, Export, Travel Mode.
5. Aiko/learning screens: Aiko Assistant, Optimize, Review, Learning Hub, Subscription Plan.
6. Placeholder screens: import/export, calculators, saved scenarios, future expansion.

May 31, 2026 idea boards are references for density, hierarchy, and feature coverage, not separate themes. Existing feature screens absorb useful states through subroutes, menus, or inline tools.

| Idea group | Existing owner | Supplemental routes |
|---|---|---|
| Core app screens | Auth, onboarding, dashboard, accounts | `/notifications`, in-page This Month Overview, in-page Edit layout |
| Transactions, categories, accounts | Transactions, categories, accounts | inline transaction search and filters, `/transactions/split`, `/transactions/receipt-review` |
| Budget, goals, cash flow, reports | Budget, goals, reports | `/budget/pace`, `/budget/safe-to-spend`, `/budget/cash-flow`, `/budget/cash-flow-sankey`, `/goals/detail`, `/goals/saving-plan`, `/goals/chance-of-success`, `/reports/monthly` |
| Credit, debt, portfolio, tax | Credit cards, debt, portfolio, assets, tax | `/credit-cards/detail`, `/debt-overview`, `/loans/detail`, `/net-worth`, `/portfolio/allocation`, `/portfolio/holding`, `/tax-analytics` |
| Aiko AI, calculators, settings, extras | Aiko, calculators, bills, learning, travel, settings | `/aiko-insights`, `/calculator-result`, `/profile-security` |

Route rules:

- Do not duplicate an existing feature screen to match an idea board.
- Use sticky bottom actions for filter, save, confirm, and calculator-result screens when required.
- Use a scrollable in-page action for Overview layout editing; do not put the dashboard edit layout control in the app bar or fixed bottom bar.
- Keep sample data realistic and scoped to preview/offline states.
- Real repositories remain the source of persisted user data.
- Aiko guidance appears after the primary number or decision, except onboarding and assistant chat.
- Every supplemental route must render without a Supabase session.

Entry points:

| Owner screen | Access pattern |
|---|---|
| Home dashboard | App bar action for notifications; in-page This Month Overview and scrollable Edit layout action for customization |
| Transactions | Search in app bar with inline filters for type, amount, and date; split and receipt review remain transaction tools |
| Budget | Tools menu exposes pace, safe-to-spend, cash flow, Sankey |
| Goals | Tools menu exposes saving plan, chance of success, detail |
| Reports | Monthly report opens from reports list |
| Calculators | Hub links to focused calculators and result states |
| Planning | Links to budget, goals, recurring transactions, credit, debt, net worth, assets, tax, portfolio, and travel. Do not expose Accounts, Categories, or Accounting as Planning cards. |
| Settings | Owns profile, security, privacy, sync, notification preferences |

## SVG Icons

Reusable SVG icons live in `assets/icons/`, use `aiko_<name>.svg`, `viewBox="0 0 24 24"`, and `currentColor`.

Required assets: `aiko_home.svg`, `aiko_transactions.svg`, `aiko_budget.svg`, `aiko_insights.svg`, `aiko_aiko.svg`, `aiko_account.svg`, `aiko_bank.svg`, `aiko_wallet.svg`, `aiko_credit_card.svg`, `aiko_category.svg`, `aiko_receipt.svg`, `aiko_search_filter.svg`, `aiko_goal.svg`, `aiko_cash_flow.svg`, `aiko_debt.svg`, `aiko_loan.svg`, `aiko_portfolio.svg`, `aiko_tax.svg`, `aiko_calculator.svg`, `aiko_travel.svg`, `aiko_security.svg`, `aiko_notification.svg`.

Keep icons stroke-based, single-color, 24x24, and friendly but not cartoonish. Do not mix filled, duotone, and outline styles in the same control group. Use Material icons for platform-standard commands and SVGs for brand-owned navigation, exports, and reusable assets. New required SVGs need tests before UI reliance.

## QA Checklist

Before a screen is design-complete:

- Main task is visible in the first viewport.
- Primary action is obvious and reachable while scrolling when required.
- Financial numbers appear before AI guidance and include context.
- Lists are compact and tappable.
- Form fields have labels and recovery-oriented validation.
- Empty, loading, error, and offline states exist or are intentionally inherited.
- No nested cards, decorative shadows, or oversized radii.
- Raw colors are limited to theme files or explicit data visualization needs.
- Text does not overlap or clip at small phone widths.
- Dark theme contrast is sufficient.
- Aiko appears only when useful.
- The screen does not duplicate an existing main feature route.
- Widget tests cover critical rendering and interactions.
