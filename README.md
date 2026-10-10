# Aiko — Personal Finance Management App

**AI-powered personal finance, guided by Aiko** — a calm, blue-haired AI companion. Track · Budget · Save · Invest · Plan.

## Rules

- Brief; include risks, assumptions, validation. Recheck this file before repo work; update only for durable conventions.
- Keep this file compact yet readable — when editing, condense wording without dropping any instruction or detail.
- Agent workflow: work directly on `main` and execute inline. Do not create worktrees or feature branches, delegate to subagents, or ask about execution/branch disposition unless the user explicitly requests an exception.
- The user owns Git integration. Agents must not commit, push, merge, create pull requests, or offer branch-handoff options unless explicitly requested.
- Learning Hub definitions belong inline through `InlineGlossaryText`; agents must not restore a standalone Glossary section.

---

## What Is Aiko?

Cross-platform (web + iOS + Android) personal finance app: Flutter + Firebase. **Aiko** (calm, anime-style, blue hair) gives friendly, non-judgmental money guidance. A data-first financial OS: 13 transaction types, category-owned budget limits (envelope / zero-based / 50-30-20, monthly/weekly/yearly/daily, rollover), goal accounts (SMART target/date/priority, Monte Carlo probability), cash flow + Daily Spending reactions, credit/debt/loan payoff, portfolio + net worth, tax organization, ~60 calculators, AI guidance, Ask Aiko chat, monthly Review, learning hub, multi-currency Travel Mode.

This is a single repo for the Aiko product surface: Flutter app, landing page, Firebase emulators/functions/rules, docs, visual references, and tests. Keep `landing/` and `screenshots/`; Firebase Emulator Suite replaces the former Docker backend workflow.

## Brand Identity & Voice

- **Aiko:** blue-haired, supportive, calm, non-judgmental. **Voice:** warm, positive, solution-oriented, never shame-based ("Groceries are pacing high. Lower flexible spending by $18 this week" — not "You overspent again").
- **Color:** Primary blue `#3B82F6` (Deep `#1D4ED8` | Soft `#93C5FD` | Pale `#EFF6FF`). Semantic: Success Green (savings/income), Warning Orange (bills/limits), Danger Red (overspending), Purple (Premium/AI), Teal (analytics/portfolio).
- **Principle — *Data first, Aiko enhanced*:** the character guides onboarding/greetings/reviews/insights without obscuring data or charts.
- **Product register:** product UI, not marketing. Dense-but-readable, consistent components, AI warmth only when it clarifies. Avoid decorative gradients, glassmorphism, nested cards, oversized heroes, Aiko artwork over numbers/charts/forms/actions. Category forms own budget fields — no separate Budgets form.

**Design tenets:** (1) Data first, Aiko enhanced. (2) One primary action per region. (3) Every number needs context. (4) Lists compact, detail screens breathe. (5) Cards = real objects/metrics/grouped tasks. (6) Forms disclose advanced controls only when the feature owns the choice. (7) Empty states teach next action; errors explain recovery. (8) Dark mode first-class. (9) 48px min touch target.

---

## Tech Stack

| Component | Technology |
| --- | --- |
| Web & Mobile | Flutter & Dart (SDK ^3.11.5) |
| State | Riverpod |
| Navigation | GoRouter |
| Backend | Firebase Auth, Firestore, Storage, Cloud Functions, Security Rules |
| Offline Store | Firestore SDK persistence when signed in; SQLite for local-only data and existing mobile migrations |
| Sync | Firestore SDK offline queue + shared collection listeners on web/mobile |
| Attachments | Firebase Storage + Firestore metadata; persistent local byte cache on both platforms |
| Money | `decimal` (no floating-point) |
| Charts | `fl_chart` |
| Security | `flutter_secure_storage` |
| IDs | `uuid` |
| Export | `csv`, `share_plus`, `path_provider` |
| Formatting | `intl` (locale-aware) |

---

## Getting Started

**Prerequisites:** Flutter stable (Dart ^3.11.5), Node 22+, Java 21+; Android Studio/Xcode for native builds. No hosted project is needed for emulator development.

```sh
flutter pub get
npm ci
npm --prefix firebase/functions ci
npm run functions:build
dart run sqflite_common_ffi_web:setup

# Build the shared Flutter app
flutter build web --dart-define=FIREBASE_PROJECT_ID=demo-aiko \
  --dart-define=FIREBASE_EMULATOR_HOST=127.0.0.1

# Auth, Firestore, Storage, Functions, Hosting, emulator UI
npm run firebase:start
```

Open **http://localhost:8080**. Emulator UI: **http://127.0.0.1:4000**. Create an email/password account in the app. The emulator exports data to `.firebase-data/` on graceful shutdown and imports it on the next run. These files contain local account/data state and stay gitignored. Use the same host/port to preserve browser storage. Build once before starting Hosting on a fresh clone. For live Flutter development use `flutter run -d chrome --web-port=8082` with the same defines.

**Mobile against the same backend:** run `flutter run -d <device>` with those defines; Android emulators use `FIREBASE_EMULATOR_HOST=10.0.2.2`. A physical phone needs the development machine's LAN address and emulator hosts explicitly bound to that interface. Share the same `demo-aiko` project and sign in with the same account. Google sign-in requires production Firebase/Google configuration; email/password works locally.

**Local-only mode:** omit Firebase defines. SQLite stores finance data on mobile and in browser IndexedDB through `sqflite_common_ffi_web`. The app opens directly to the dashboard. No cross-device synchronization or cloud functions run in this mode. Browser storage requires HTTPS or localhost and can be removed by clearing site data.

**Production configuration:** register web, Android and iOS apps in one Firebase project. Enable Email/Password and Google Auth; configure authorized web domains, Android signing SHA fingerprints, and the iOS reversed Google client-ID URL scheme. Supply each platform's `FIREBASE_PROJECT_ID`, `FIREBASE_API_KEY`, `FIREBASE_APP_ID`, `FIREBASE_MESSAGING_SENDER_ID`, `FIREBASE_STORAGE_BUCKET`, `FIREBASE_AUTH_DOMAIN`, and optional `FIREBASE_REGION`. Leave `FIREBASE_EMULATOR_HOST` unset. Native Google login also uses `GOOGLE_WEB_CLIENT_ID` and `GOOGLE_IOS_CLIENT_ID`. These client configuration values are public; provider secrets and Admin credentials never belong in the Flutter build.

**Deployment:** GitHub Actions (`.github/workflows/ci.yml`) runs the quality gates on every push and publishes a Vercel preview for non-`main` branches. On `main`, after the gates pass, it deploys Firebase rules/indexes (plus Storage/Functions when enabled) and the production web app. One-time Firebase, Vercel and GitHub setup: [Deployment](docs/deployment.md). Test rules/functions locally first. See [Firebase migration and verification](docs/firebase.md) for data import, service configuration, and platform limits.

---

## Project Structure

```sh
lib/
├── brick/        # Brick offline models, adapters, SQLite schema, mappers
├── main.dart     # Entry point
├── app/          # App wiring (router, bootstrap, providers)
├── core/         # Framework utilities, no UI: config, errors, formatting, monetization,
│                 #   money, notifications, offline, prediction, security, storage, firebase, sync
├── features/     # 16 feature modules (accounts, aiko_assistant, aiko_character, auth,
│                 #   calculators, categories, dashboard, export, investments, learning_hub,
│                 #   onboarding, overview, settings, transaction_capture, transactions,
│                 #   travel_mode)
├── shared/       # Cross-feature widgets, state, test data
├── l10n/         # .arb sources; AppLocalizations is generated by Flutter
└── theme/        # Design system (colors, typography, spacing, themes)

firebase/         # Firestore/Storage rules, Functions, emulator tests, legacy import tool
web/              # Flutter web entrypoint and SQLite worker assets
tool/             # Local emulator startup helpers
.github/          # CI quality gates; Vercel and Firebase deploy workflows
landing/          # standalone Aiko landing page
screenshots/      # product/idea screenshots and visual references
assets/           # icons/ (aiko_*.svg), images/aiko/ (6 expression variants)
test/             # Unit tests
```

Each feature module is layered: `application/` (services, orchestration), `data/` (repositories, DTOs, sync adapters), `domain/` (immutable models, value objects), `presentation/` (screens, widgets, controllers).

---

## Navigation

GoRouter around a bottom-nav shell, 5 primary tabs:

1. **Accounts (`/accounts`)** — Bank/Cash/Wallet accounts, including credit cards.
2. **Categories (`/categories`)** — 13 default groups + custom categories.
3. **Overview (`/home`)** — Static dashboard, fixed panel set/order (Aiko greeting, Daily spending, Safe this week, Daily summary, Net earnings, Category budgets, Spending calendar, This Month Overview, Cash flow mapping, Aiko Goal Simulator, balance/net-worth/asset summaries) + notifications action. Set/order defined by `_homeWidgets` in `home_dashboard_screen.dart`, **not** user-customizable.
4. **Transactions (`/transactions`)** — Search, filters, recurring, auto-categorization rules.
5. **Aiko (`/aiko`)** — Chat (`/aiko-assistant`), optimize (`/aiko-optimize`), course hub; opens the Settings hub.

**Settings (`/settings`)** — via Aiko tab settings icon. Flat tools list: Chance of Success, Investments, Asset Allocation, Holding Detail, Learning Hub, Calculators, and Export. App preferences include Appearance and Language.

**Secondary routes:** `/notifications`, `/transaction-rules`, `/transaction-capture`, `/settings/chance-of-success`, `/reports/monthly`, `/export`, `/account-form`, `/profile`, `/connect-line`, `/portfolio`, `/portfolio/allocation`, `/portfolio/holding`, `/calculators`, `/learning-hub`, `/travel-mode`.

---

## Architecture

One Flutter implementation shares domain logic, routes, repositories, and Firebase data across web, iOS and Android. Backend SDKs stay behind repository/service boundaries.

### Feature Module Pattern

`application/` (services, workflows), `data/` (repositories, DTOs, sync adapters), `domain/` (immutable models), `presentation/` (screens, widgets, controllers).

- Screens compose UI + consume Riverpod providers; application services hold business logic + coordinate repositories.
- Repositories own persistence/sync — screens never call Firebase, Brick, or SQLite directly.
- Domain models stay framework-light. Brick models (`lib/brick/models/`) store primitives only, map to domain via `lib/brick/offline_model_mappers.dart`.

### Offline-First & Sync

Signed-in finance data lives at `users/{uid}/{collection}/{id}` in Firestore. The Firebase SDK owns its persistent offline cache, retry queue, and last-write-wins document conflict behavior. `OfflineStore` delegates to that SDK; no custom finance outbox. `firebaseSyncProvider` owns one listener per collection and invalidates shared providers on inserts, updates and deletes, so views on both platforms refresh. Late rejected writes surface a sync error in the app.

Local-only installations keep the existing Brick SQLite schema. Its models, schema migrations and SQLite/Firestore codecs are in `lib/brick/`. Codecs are maintained source (`model_dictionary.dart`, `adapters/*.dart`): update them and round-trip tests together when adding fields. Existing SQLite migrations remain immutable; add a migration for any local schema change. `details_json` remains a local string while Firestore `details` is a map; legacy local NULL values remain supported.

System templates remain the same 81 categories and 13 groups. Sign-in creates deterministic per-user UUIDv5 clones transactionally only when missing. Existing profile preferences and budgets are never reset. Anonymous account/category/group/transaction/holding data is claimed on sign-in, category references are rekeyed, and successfully queued local rows are removed to avoid repeated imports. Existing cloud exports can be imported with the create-only dry-run tool in `firebase/tools/`.

Appearance/profile data, language, Travel Mode and transaction rules synchronize. OS capture permissions and native notification scheduling remain device-specific. Browser receipt/image/PDF previews and export downloads use bytes instead of native filesystem APIs.

### Code Conventions

- **State:** Riverpod for all state; avoid `setState` outside trivial local UI. Top-level providers in `lib/app/providers.dart`; feature providers in-module; shared state in `lib/shared/state/`.
- **Provider caching:** long-lived list/summary providers call `ref.keepAlive()` *after* a successful load, so switching tabs reuses cached data (no full-screen skeleton flash). A failed load isn't cached and retries. Firebase collection listeners invalidate these providers when data changes on any client. Pull-to-refresh remains available for manual refresh.
- **Routing:** all routes in `lib/app/app_router.dart`. Kebab-case paths. Idea-inspired screens belong to the existing feature owner — add subroutes/menus/inline tools, never duplicate a main screen. Accounts/Categories are primary nav tabs — don't add them as Planning/Menu cards.
- **Money:** never `double`. Use `Money` (`lib/core/money/money.dart`, wraps `Decimal`); format via `lib/core/formatting/money_formatter.dart`. Base currency in profile; multi-currency for travel/portfolio.
- **Naming:** files `snake_case.dart`, classes `PascalCase`, vars/functions `camelCase`, routes `/kebab-case`, DB `snake_case`.
- **`super.key` (T-705):** every widget constructor taking `Key?` forwards it as `super.key`.
- **Notifier / Service / Controller (T-601):** `*Notifier` (reactive Riverpod state, owns in-memory snapshot, `ref.keepAlive()`); `*Service` (pure/near-pure function object, no Riverpod/refs, `const` ctor, unit-testable); `*Controller` (orchestrates Notifier + Service + UI side effects, owns stream/retry/message derivation); `*Repository` in `data/` (wraps `OfflineStore`, never touches `ref`/`BuildContext`).

### Sync Fields & Conflict Resolution

User-owned finance documents retain stable `id`, `user_id`, ISO timestamps and decimal **strings**. Firebase applies last-write-wins per document and handles offline write replay. Deletes are SDK document deletes, reflected by listeners on other clients; no stale SQLite rows are merged back into cloud reads. Default category identity is read-only under Security Rules, while budget fields remain editable. Aggregates are recalculated from source records. Concurrent edits to the same financial record still require user review; this migration does not introduce a transactional double-entry ledger.

### Summaries

Dashboards/reports calculate summaries from repository projections. Cloud AI tools also aggregate per currency with `decimal.js`, never binary floating-point money.

### Receipt & Attachment Strategy

Bytes are cached durably in SQLite (IndexedDB-backed on web) before attachment metadata is saved. Uploads use Firebase Storage paths `users/{uid}/receipts/{id}/{fileName}` and Firestore `attachments` metadata. Remote files download through authenticated Storage access and cache locally. Failed uploads remain local and retry when their transaction's attachments are opened. Avatars use `users/{uid}/avatars/`; the profile contains the returned download URL. Local cache paths are device-specific and fall back to cloud images on other devices.

The domain supports PDF, JPEG, PNG, WebP, HEIC, text/CSV/Markdown and Word files, up to 10 MiB. Images, PDFs and text have browser/native previews; HEIC and Word use an unsupported-preview fallback. Browser scheduled notifications and Android SMS/notification capture are not available; reminder times remain part of the shared transaction.

### Cost & Boundaries

Use the SDK cache and shared listeners, not a new listener per widget. Keep files in Storage and structured records in Firestore. Financial calculations stay in Dart/domain services. Cloud Functions own privileged deletion, LINE linking, AI and optional external providers; UI never accesses Admin credentials.

---

## Core Features

- **🏠 Dashboard** — static fixed-order panels (above) + quick-add. Not user-customizable.
- **💰 Money Tracking** — 13 transaction types (income, expense, transfer, refund, investment buy/sell, dividend, interest, loan payment, credit card payment, tax payment, fee, adjustment). Splits, receipts, recurring (Once/Daily/Weekly/Monthly/Annually, each with own end date), duplicate detection. Amount-first quick entry with OCR + voice. Rules auto-apply categories/tags/splits/names by merchant keyword, account, or amount.
- **📊 Budgeting (in Categories)** — each Category owns an optional budget: monthly/weekly/yearly/daily, envelope / zero-based / 50-30-20, one-period rollover, thresholds (default 50/75/90/100%). Safe-to-Spend: `Leftover = Income − Fixed Bills − Reserves − Debt − Goals − Current Spending`. Daily Spending compares today's posted expenses with the daily safe amount and shows Aiko's green, orange, or red reaction.
- **🎯 Goals (in Accounts)** — goal accounts (`Account.type == goal`) carry SMART target, date, priority. `currentBalance` is saved amount; monthly contribution, Monte Carlo probability, saving plan all read the same row.
- **📈 Insights & Predictions** — spending trends, cash flow + Sankey, leftover/safe-to-spend, end-of-month forecasts, overrun prediction, net worth projection, retirement readiness.
- **🤖 Aiko AI Assistant** — chat, personalized guidance, budget recommendations, debt strategies, monthly reviews.
- **💳 Credit & Debt** — statement balances, APR, rewards, due dates, utilization; snowball/avalanche payoff with extra-payment + interest-savings simulation.
- **📱 Portfolio, Assets & Tax** — holdings (performance, allocation, dividends, realized/unrealized gains); allocation by class/currency/geography/risk; net worth trends; tax flagging, capital gains, document storage, estimated tax reports.
- **🌍 Travel Mode** — multi-currency accounts, auto exchange rates, travel budgets, foreign-fee tracking, trip reports.

## Calculator Suite (~60 Tools)

Calculator scenario saving/comparison is not wired yet.

- **Finance & Investment:** TVM, Compound Interest, ROI, IRR/NPV, Savings Goal, CD, Bond, Tax Equivalent Yield, Rule of 72.
- **Loan & Mortgage:** Amortization & Comparison, Refinance, APR, Rent vs. Buy, Home Affordability, bi-weekly, Rental Property.
- **Retirement:** Savings & Income Planner, Traditional vs. Roth IRA, RMD, Social Security, Annuity.
- **Credit Card & Auto:** CC Payoff & Minimum Payment, Balance Transfer, Auto Loan vs. Lease.
- **Stock & Portfolio:** WACC, Black-Scholes, Expected Return, CAPM, Holding Period Return, Capital Gains.
- **Everyday & Tax:** Salary to Hourly, Paycheck Tax, Inflation, Effective Rate, Margin/Markup, Tip & Percentage.

## Prediction & AI System

- Rule-based forecasting (end-of-month balance, overrun risk, goal completion); moving averages for recurring-expense trends; seasonality detection.
- Monte Carlo for advanced goal/retirement probability under three scenarios (optimistic/expected/conservative). Logic in `lib/core/prediction/`.
- Ask Aiko streams guidance from the server-side chat function. Persist generated insight rows only when a real product screen and generator own them.
- **Disclaimer required:** *AI insights are estimates, not certified financial, investment, or tax advice.*

---

### Ask Aiko, LINE, and optional providers

`HttpChatEngine` streams `data: {"delta":"..."}` events from the `aikoChat` Firebase HTTPS function, ending with `{"done":true}` or an error. The function verifies the Firebase ID token, rate limits the user, and owns the system prompt. It accepts the on-device financial snapshot and six read-only tools for account summaries, budget status, spending by category, cash flow, recent transactions and goal progress. Every tool receives the verified UID and reads only that user's collections; model input cannot choose another owner. Provider failures before or during streaming are reported without inventing an answer.

Server-only secrets: `AI_API_KEY`, `AI_MODEL`, `AI_BASE_URL` (OpenAI-compatible endpoint). Local values belong in `firebase/functions/.secret.local` (gitignored). Unconfigured cloud AI returns 503; builds without Firebase retain the existing local guidance engine. Production secrets use Firebase Secret Manager.

`lineWebhook` verifies the LINE HMAC; `redeemLinePairing` consumes a hashed, expiring code transactionally under Firebase Auth. Link records are server-only; the profile sees an `integrations/line` status document. Unlike the previous backend, no user refresh token is stored for LINE. Configure `LINE_CHANNEL_SECRET` and `LINE_CHANNEL_ACCESS_TOKEN`, then point LINE to `lineWebhook`. OCR (`ocrScanner`) and price refresh (`marketFeed`) use explicitly configured server providers (`OCR_API_URL`/`OCR_API_KEY`, `MARKET_API_URL`/`MARKET_API_KEY`); they report unavailable when unset.

## Account Deletion

Profile deletion calls the authenticated `deleteAccount` callable. It requires a sign-in from the last five minutes, deletes the user's Firestore subtree, Storage objects and LINE mapping, then deletes the Firebase Auth identity. It is immediate and permanent; no grace period. Privileged server code always derives the UID from verified authentication.

## Database Schema

`users/{uid}` contains `profiles`, `accounts`, `transactions`, `transaction_splits`, `categories`, `category_groups`, `attachments`, `investment_holdings`, `preferences`, and read-only `integrations`. Profiles use the UID as document ID; other entities keep their existing IDs and snake_case fields. Money values are decimal strings. Budgets remain category fields, goals remain account fields, recurring/reminder metadata remains on transactions, and attachment metadata references Storage paths. Global server-only `line_links`, `line_pairings`, and `rate_limits` cannot be read by clients. All other unspecified paths are denied.

**Backend changes:** update `firebase/firestore.rules`, `firebase/storage.rules`, Functions and tests together. Run emulator tests and the function build; merging to `main` deploys them through CI once tests pass. `firebase/tools/import_legacy.cjs` imports existing exported users, records and files with stable IDs; dry run is the default. Historical SQL design notes under `docs/superpowers/` describe the replaced backend, not active deployment instructions.

---

## Design System

Source of truth for visuals/patterns/components. Don't add one-off colors/radii when a token exists. Code: `lib/theme/aiko_colors.dart`, `aiko_theme.dart`, `aiko_typography.dart`, `aiko_spacing.dart`.

**Tokens — three layers:** Primitive (`AikoColors`, `AikoTypography`), Semantic (`ColorScheme`, theme extensions), Component (`AikoTheme`, shared widgets).

### Color

| Role | Light | Dark | Use |
| --- | ---: | ---: | --- |
| Primary | `#3B82F6` | `#93C5FD` | Primary actions, selected, active nav |
| Secondary | `#1D4ED8` | `#3B82F6` | Strong selection, key blue charts |
| AI/Premium | `#7C3AED` | `#B894F5` | Aiko, AI, optimization, premium |
| Scaffold | `#D8E0F5` | `#0F172A` | Main background |
| Alternate scaffold | `#F6F8FF` | `#0F172A` | Light alternate screens |
| Surface | `#EEF2FF` | `#121C31` | Cards, sheets, grouped controls |
| Surface strong | `#E3E9FF` | `#1B2740` | Selected/high-emphasis panels |
| Text primary | `#0F172A` | on-surface | Primary text |
| Text secondary | `#293348` | on-surface-variant | Secondary text |
| Text muted | `#778196` | muted | Metadata, helper |
| Outline | `#BAC3D6` | `#414B60` | Visible borders |
| Outline subtle | `#DCE4F8` | `#293348` | Dividers, quiet outlines |
| Success | `#16A34A` | `#4ADE80` | Income, savings, positive |
| Warning | `#F59E0B` | `#FBBF24` | Bills, due soon, caution |
| Danger | `#DC2626` | `#F87171` | Errors, destructive, overspending |
| Analytics | `#0D9488` | `#2DD4BF` | Reports, portfolio, allocation |

Rules: primary blue = current/continue/main action (+ Overview/Transactions app-bar icons); purple reserved for Aiko/AI/optimization/premium/review; green/orange/red/teal keep semantic meanings; never rely on color alone; inactive states neutral, not pale saturated.

10-stop ramps (charts, progress, selected):

| Ramp | Stops |
| --- | --- |
| Primary blue | `#071426`, `#0B356F`, `#0C4A9A`, `#0B5DBD`, `#1D74E8`, `#3B82F6`, `#75A4F5`, `#A5C4F6`, `#D8E5FF`, `#FFFFFF` |
| Secondary blue | `#071426`, `#0B2A7A`, `#073AA8`, `#1D4ED8`, `#4268EA`, `#6385F0`, `#8AA4F5`, `#AFC0F8`, `#DCE5FF`, `#FFFFFF` |
| Tertiary purple | `#071426`, `#240052`, `#3B0785`, `#5B0BC0`, `#6D28D9`, `#7C3AED`, `#9B67F2`, `#B894F5`, `#DCCBFF`, `#FFFFFF` |
| Neutral | `#071426`, `#0F172A`, `#293348`, `#414B60`, `#5B6578`, `#778196`, `#9BA4B8`, `#BAC3D6`, `#DCE4F8`, `#FFFFFF` |

### Typography

Headline = Hanken Grotesk (titles, balances, hero numbers); Body & Label = Manrope. Letter spacing `0`. Tabular figures for money columns. No display-scale text in compact cards/lists/settings/sidebars/form controls.

| Style | Size | Weight | Use |
| --- | ---: | ---: | --- |
| `displayLarge` | 48 | 700 | Rare onboarding/report |
| `headlineLarge` | 36 | 700 | Major balance/summary |
| `headlineMedium` | 28 | 700 | Screen headline in body |
| `titleLarge` | 20 | 700 | App bar / card title |
| `titleMedium` | 16 | 700 | Section title, prominent row |
| `titleSmall` | 14 | 700 | Dense list title |
| `bodyLarge` | 16 | 400 | Primary readable text |
| `bodyMedium` | 14 | 400 | Default body, metadata |
| `bodySmall` | 12 | 500 | Helper text |
| `labelLarge` | 14 | 700 | Buttons, tabs |
| `labelMedium` | 12 | 700 | Chips, badges |
| `labelSmall` | 11 | 700 | Dense status labels |

### Spacing, Shape, Surfaces

Spacing 4/8px: `space-1` 4, `space-2` 8, `space-3` 12, `space-4` 16 (default card padding), `space-5` 20 (prominent), `space-6` 24, `space-8` 32.

Shape: cards/rows/inputs/chips/segmented 8px radius; bottom sheets 20px top; FABs may use 16px; avoid 20px+ radii on product cards and decorative shadows. Don't nest cards. Density: daily lists compact, detail screens breathe, dashboards fewer stronger metrics, settings grouped rows, forms full-width controls with 16px gaps.

### Screen Archetypes

| Archetype | Rules |
| --- | --- |
| Dashboard | One primary summary, then 2-4 metrics. Data before copy. Label charts with numbers + periods. |
| List & detail | Compact tappable rows (mark, title, subtitle, trailing amount/status, chevron). Details lead with primary number + grouped facts. |
| Form | Required controls first, full-width fields, helper text under controls, primary save, progressive disclosure. |
| Settings | Grouped rows (icon, title, description, control). Separate security/destructive. |
| Assistant & AI | Cite context, give actions/dismiss reasons, no filler, semantic finance states even with purple. |
| Planning & education | Progressive disclosure. Show progress/saved state. Calculators: input → result → conversion. Reports pair charts with summary text. |
| Supplemental tools | Extend an owning feature, never duplicate top-level screens. First viewport shows the task object. Sticky bottom bars for completion. |
| Placeholders | State what the feature will do + one action. No fake dashboards. Use `AikoScreenState` / `AikoFeatureOverviewScreen`. |

### Components

- **`FinanceCard`** (objects/metrics/grouped panels): 8px radius, 16px default / 20px prominent padding, outline-variant border, no shadow, `titleMedium` title, `bodyMedium` body, 40px icon tile (8px radius, 12% accent opacity), stable `InkWell`. Three-tier hierarchy: primary number/title → metadata → one action/status. Never a wrapper around another card.
- **Buttons:** filled (primary), outlined (secondary), text (inline), icon. Min 48px, 8px radius, visible disabled.
- **Icon buttons:** 40–48px tile, 48px tap target — Primary blue circle/white, AI/premium purple, Destructive red.
- **Inputs/pickers:** visible labels, 54px min height, 8px radius, pale-blue fill, thin blue-gray border, leading search icon, primary focus border, danger error border, muted placeholder, helper/validation below. Pickers show selected value + context; bottom-sheet pickers use compact rows with checkmarks.
- **Lists:** compact `ListTile`, 48px tap target, single-line titles, aligned trailing, dividers/card borders not nested containers.
- **Chips/badges:** short labels; status color matches semantic meaning + text.
- **Navigation:** shell tabs Accounts/Categories/Overview/Transactions/Aiko; flush compact 60dp bar (1px top border, surface bg, no pill/shadow); active = 3dp top indicator in primary blue (purple for Aiko) with icon + label; Aiko's unselected label muted purple. Aiko tab opens Settings hub.
- **Sheets/dialogs:** bottom sheets for mobile create/edit (drag handle, safe area, scrollable, 20px top radius); dialogs for destructive confirmation (name object + effect).
- **Charts/progress:** every chart needs a text summary; every progress bar shows current/target/period with semantic color + label (8px compact, 10–12px dashboards).

| Interactive state | Treatment |
| --- | --- |
| Pressed / splash | Primary at 12% opacity |
| Hover | Surface tint at 8% opacity |
| Focused | 2px primary outline offset 2px |
| Disabled | 40% opacity, no interaction |
| Dragging | Scale 1.02 + subtle shadow |

Use `AikoScreenState` for loading/empty/error/offline/locked.

### Shared Widgets

`lib/shared/widgets/aiko_data_widgets.dart` for idea-backed supplemental + new detail screens. Prefer shared widgets over one-off cards/painters; don't nest `AikoDataListCard`; sticky bottom actions via `AikoDetailScaffold.bottomBar`.

`AikoDetailScaffold` (detail/tool screens, optional sticky bottom action), `AikoInlineNotice` (tips/warnings/notes), `AikoMetricCard`/`AikoMetricGrid` (summaries), `AikoDataListCard`/`AikoDataRow` (grouped facts/settings rows), `AikoDonutChart`/`AikoGauge` (labeled preview charts).

### Iconography

Material Icons primary; custom SVGs for brand moments only. Sizes: 16 inline, 20 list-leading, 24 toolbar, 48 hero. Colors: Default `onSurface`, Active `primary`, Destructive `danger`, AI/premium `tertiary`, Muted `mutedText`.

Reusable SVGs in `assets/icons/` as `aiko_<name>.svg`, `viewBox="0 0 24 24"`, `currentColor`, stroke-based, single-color. Don't mix filled/duotone/outline in one group. New required SVGs need tests in `test/shared/widgets/aiko_svg_assets_test.dart` before UI reliance. Required: `aiko_home`, `aiko_transactions`, `aiko_budget`, `aiko_aiko`, `aiko_account`, `aiko_bank`, `aiko_wallet`, `aiko_credit_card`, `aiko_category`, `aiko_receipt`, `aiko_search_filter`, `aiko_goal`, `aiko_cash_flow`, `aiko_debt`, `aiko_loan`, `aiko_portfolio`, `aiko_tax`, `aiko_calculator`, `aiko_travel`, `aiko_security`, `aiko_notification`.

### Aiko Character Usage

Six variants: `happy`, `thinking`, `encouraging`, `warning`, `celebrating`, `welcome`. Use purposefully — onboarding welcome/completion, insight explanations, goal encouragement, budget warnings, reassuring empty states, chat. Never over tables/charts/balances/forms/critical actions; not on every screen.

### Ownership

| Owner | Owns |
| --- | --- |
| Categories | Name, type, group, icon, color, active/archive, + optional budget limit (amount, period, rollover, thresholds) |
| Budgets | Dissolved — limits live on the Category |
| Transactions | Account, category, amount, merchant, notes, tags, receipt, voice, split |
| Accounts | Balances, currency, type, active state, net-worth inclusion, and (type=goal) target/date/priority |
| Settings | App config, profile, privacy, security, sync, notification, route links |
| Aiko | AI explanation, suggestions, review, optimization, chat |
| Dashboard | In-page monthly overview, notifications, cross-feature summaries (fixed layout) |
| Reports | Generated summaries, monthly report presentation |
| Calculators | Inputs and results; persistence/conversion only after the product flow exists |
| Portfolio | Holdings, allocation detail |
| Assets/net worth | Household asset summaries |
| Debt/credit | Payoff, utilization, loan, statement detail |

### Motion & Accessibility

Tap feedback 80-150ms (material state layer); small reveal 150-200ms (`easeOut`); sheet/modal 250-300ms (`easeOut`); page 250-300ms (`easeInOut`); progress fill 300-400ms (`easeInOut`); emphasis ~600ms (`elasticOut`). Animate opacity/transform not layout size; don't animate numbers while read (settle <300ms); `AnimatedSwitcher` for state transitions; respect reduced motion; no hover-only affordances.

Accessibility: body contrast ≥4.5:1, secondary ≥3:1; targets ≥48x48; visible focus; icon-only buttons need labels/tooltips; color never sole meaning; no clipping with dynamic type; charts need labels/legends/summaries; form errors near the field; toasts never the only record of an important change.

### Flutter Implementation Rules

Shared UI primitives in `lib/shared/widgets/`; feature screens consume them, don't re-create card/button/empty-state/picker styles. Idea-backed detail/tool screens use `AikoDetailScaffold` + `aiko_data_widgets.dart`. Prefer `AikoScreenState` for loading/empty/error/offline/locked.

### Route & Idea Coverage

Supplemental routes by owner: `/notifications`, `/transaction-rules`, `/transaction-capture`, `/settings/chance-of-success`, `/reports/monthly`, `/export`, `/account-form`, `/profile`, `/connect-line`, `/portfolio/allocation`, `/portfolio/holding`, `/learning-hub`, `/travel-mode`.

Route rules: don't duplicate an existing feature screen; sticky bottom actions for filter/save/confirm/result screens; sample data realistic + scoped to preview/offline; real repositories remain the persisted source; Aiko guidance after the primary number/decision (except onboarding/chat); every supplemental route renders without a Firebase session.

### QA Checklist

Main task in first viewport; primary action obvious + reachable while scrolling; numbers before AI guidance + with context; lists compact/tappable; fields labeled with recovery-oriented validation; empty/loading/error/offline states exist or intentionally inherited; no nested cards/decorative shadows/oversized radii; raw colors limited to theme files or data-viz; no text clipping at small widths; dark contrast sufficient; Aiko only where useful; no main-route duplication.

Account-type-specific inputs: add each from fresh state (subform appears/validates/saves); edit each (values pre-populate, round-trip identical); toggle shared limit (field appears/disappears, card picker excludes self); delete parent card (child detail shows migration notice); offline add (persists locally, syncs on reconnect, no double-write).

---

## Testing

**No UI/widget tests.** Don't write `testWidgets`/`pumpWidget` tests for screens, widgets, rendering, or interaction. Test logic only — `*Service` function objects, `Money`/Decimal math, prediction, parsers, rules, repositories, providers, models. A widget already couples UI + logic; isolate and unit-test the logic underneath instead.

```bash
flutter test                       # money types, formatters, prediction, models, providers, rules,
                                   # feature gating, parsers
```

**Quality gates — run all before any release:**

```bash
npm --prefix firebase/functions test
npm run test:rules                 # requires the emulators
flutter build web
dart format --set-exit-if-changed lib test
flutter analyze lib test
flutter test
```

---

## Monetization & Security

| Plan | Includes |
| --- | --- |
| **Free** | Manual tracking, basic categories/budgets/charts, limited calculators, CSV export, basic Ask Aiko guidance |
| **Premium** | Unlimited accounts, advanced reports, AI recommendations, forecasting, OCR, CC optimization, portfolio analytics, tax reports, PDF/Excel export, multi-device sync |
| **Pro** | Double-entry accounting, balance sheets, reconciliation, business reports, invoices, multi-user, advanced tax, estate planning, full Monte Carlo, API access |

**Security:** Secure token storage, remote device logout, conflict resolution, granular privacy (AI use acknowledged at onboarding, local-only mode).

---

## Roadmap

Phases 1–6 ✅ (Foundation; Core Finance; Intelligence; Advanced Finance; Wealth; Platform). **Future:** Open Banking sync, advanced retirement, estate planning, automated AI advisor, Pro API access.

## Common Tasks

- **New feature module:** create `lib/features/<name>/` (4 layers); add routes; new collection → owner-scoped Firebase rules; offline → model + both codecs + SQLite migration; register app-wide providers; add model/repository-fallback/provider tests; use `Money`.
- **New calculator:** add file in `lib/features/calculators/`, register in the hub category list, and add persistence/conversion only when the product flow exists.
- **New generated insight surface:** add the product screen first, then define the generator, persistence model/table, provider, display states, source-data references, Security Rules, and tests.
- **New backend field:** extend its document codec, local SQLite migration, Security Rules, and round-trip/emulator coverage.

## Key Principles

1. Clarity first. 2. Data first, Aiko enhanced. 3. Decimal-safe money (never `double`). 4. Privacy by design (Security Rules everywhere, encrypted storage, AI acknowledged at onboarding). 5. Offline first. 6. Actionable insights. 7. Warm, non-judgmental tone. 8. Test before ship.

## Contributing

Use `Money` (never `double`); go through repositories (screens never touch Firebase/Brick/SQLite); update local models/codecs for offline; add Security Rules to every new collection; consume shared widgets/tokens; write unit tests for new models/providers; run the QA checklist + all quality gates; keep Aiko's voice warm and non-judgmental.

**License:** Private; not published to pub.dev. See `pubspec.yaml`.

## Task plan

See [`TASKS.md`](./TASKS.md) for the prioritized, phased list. Phase 0 is small/low-risk (data-loss / security); Phases 1–7 grow in scope. Don't skip phases.
