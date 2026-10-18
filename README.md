# Aiko — Personal Finance Management App

**AI-powered personal finance, guided by Aiko** — a calm, blue-haired AI companion. Track · Budget · Save · Invest · Plan.

## Rules

- Brief; include risks, assumptions, validation. Recheck this file before repo work; update only for durable conventions.
- Keep this file compact yet readable — when editing, condense wording without dropping any instruction or detail.
- Agent workflow: work directly on `main` and execute inline. Do not create worktrees or feature branches, delegate to subagents, or ask about execution/branch disposition unless the user explicitly requests an exception.
- The user owns Git integration. Agents must not commit, push, merge, create pull requests, or offer branch-handoff options unless explicitly requested.
- Learning Hub definitions belong inline through `InlineGlossaryText`; agents must not restore a standalone Glossary section.
- One UI for web and mobile: window width picks the layout (`AikoBreakpoints`: bottom bar < 840px, sidebar ≥ 840px), never the platform. Add destinations/tools only to `aikoPrimaryDestinations`/`aikoNavigationItems` (`lib/app/aiko_navigation.dart`), which feed both layouts; open panels with `showAikoSheet` and route-less pages with `openAikoPage` or a route, never `showModalBottomSheet`/`MaterialPageRoute` (a guard test fails the build). Check UI changes at 390px and 1440px wide. See [Web and mobile](docs/design-system.md#web-and-mobile).
- English and Thai everywhere: every user-facing string goes through `context.l10n` with entries in both `lib/l10n/app_en.arb` and `app_th.arb`; enum labels come from `lib/l10n/domain_labels.dart` and built-in category names from `displayName(l10n)`. Never hard-code text, show `enum.name`, or show raw error text — the guard and ARB tests fail. See [Localization](docs/localization.md).
- Always keep docs current: any change to code, config, CI, schema, rules or behavior updates the affected `docs/` pages in the same change (map: [Keeping docs current](docs/README.md#keeping-docs-current)); fix stale docs you find, and run `npm run docs:check`.

---

## What Is Aiko?

Cross-platform (web + iOS + Android) personal finance app: Flutter + Firebase. **Aiko** (calm, anime-style, blue hair) gives friendly, non-judgmental money guidance. A data-first financial OS: 13 transaction types, category-owned budget limits (daily/weekly/monthly/yearly, alert thresholds, rollover) plus group envelopes, goal accounts (SMART target/date/priority, Monte Carlo probability), cash flow + Daily Spending reactions, credit card/loan/asset/liability accounts, portfolio + net worth, a 30-calculator library (Thai tax, Social Security and tax-saving fund rules built in), Ask Aiko chat, monthly report, learning hub (lessons with quizzes), CSV and printable-statement export, multi-currency Travel Mode. Where the code still falls short of this spec: [Known gaps](docs/features.md#known-gaps).

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
| Web & Mobile | Flutter & Dart (pubspec SDK `^3.11.5`; locked dependencies need Flutter ≥ 3.44 / Dart ≥ 3.12; CI pins Flutter 3.47.7) |
| State | Riverpod |
| Navigation | GoRouter |
| Backend | Firebase Auth, Firestore, Storage, Cloud Functions, Security Rules |
| Offline Store | Firestore SDK persistence when signed in; in-house SQLite record store (`aiko_local.sqlite`, IndexedDB on web) for guests and local-only builds |
| Sync | Firestore SDK offline write queue + shared collection listeners; `connectivity_plus` for the offline/sync banner |
| Attachments | Firebase Storage + Firestore metadata; persistent local byte cache + upload queue on all platforms |
| Web offline | Own service worker (`web/aiko_sw.js`) + bundled fonts |
| Money | `decimal` (no floating-point) |
| Charts | `fl_chart` |
| Security | `flutter_secure_storage` |
| IDs | `uuid` |
| Export | `csv`, `share_plus`, `path_provider` |
| Formatting | `intl` (locale-aware) |

---

## Getting Started

**Prerequisites:** Flutter stable ≥ 3.44 (Dart ≥ 3.12), Node 22+, Java 21+; Android Studio/Xcode for native builds. No hosted project is needed for emulator development. Full setup, configuration reference and troubleshooting: [Getting started](docs/getting-started.md).

```sh
flutter pub get
npm ci
npm --prefix firebase/functions ci
npm run functions:build
dart run sqflite_common_ffi_web:setup

# Build the shared Flutter app (+ precache, so it opens offline)
flutter build web --dart-define=FIREBASE_PROJECT_ID=demo-aiko \
  --dart-define=FIREBASE_EMULATOR_HOST=127.0.0.1
npm run web:precache

# Auth, Firestore, Storage, Functions, Hosting, emulator UI
npm run firebase:start
```

Open **http://localhost:8080**. Emulator UI: **http://127.0.0.1:4000**. Create an email/password account in the app, or **Continue without an account** (guest mode: data stays on the device, offline included, until sign-in claims it). The emulator exports data to `.firebase-data/` on graceful shutdown and imports it on the next run. These files contain local account/data state and stay gitignored. Use the same host/port to preserve browser storage. Build once before starting Hosting on a fresh clone. For live Flutter development use `flutter run -d chrome --web-port=8082` with the same defines (or `cp .env.example .env` and pass `--dart-define-from-file=.env`, as the VS Code launch configs do); it has no offline service worker.

**Mobile against the same backend:** run `flutter run -d <device>` with those defines; Android emulators use `FIREBASE_EMULATOR_HOST=10.0.2.2`. A physical phone needs the development machine's LAN address and emulator hosts explicitly bound to that interface. Share the same `demo-aiko` project and sign in with the same account. Google sign-in requires production Firebase/Google configuration; email/password works locally.

**Local-only mode:** omit Firebase defines. The local record store keeps finance data in SQLite on mobile and in browser IndexedDB through `sqflite_common_ffi_web`. The app opens directly to the dashboard. No cross-device synchronization or cloud functions run in this mode. Browser storage requires HTTPS or localhost and can be removed by clearing site data.

**Production configuration:** register web, Android and iOS apps in one Firebase project. Enable Email/Password and Google Auth; configure authorized web domains, Android signing SHA fingerprints, and the iOS reversed Google client-ID URL scheme. Supply each platform's `FIREBASE_PROJECT_ID`, `FIREBASE_API_KEY`, `FIREBASE_APP_ID`, `FIREBASE_MESSAGING_SENDER_ID`, `FIREBASE_STORAGE_BUCKET`, `FIREBASE_AUTH_DOMAIN`, and optional `FIREBASE_REGION` (keep `us-central1`, where Functions deploy). Leave `FIREBASE_EMULATOR_HOST` unset. Native Google login also uses `GOOGLE_WEB_CLIENT_ID` and `GOOGLE_IOS_CLIENT_ID`. These client configuration values are public; provider secrets and Admin credentials never belong in the Flutter build.

**Deployment:** GitHub Actions (`.github/workflows/ci.yml`) runs the quality gates on every push and publishes a Firebase Hosting preview channel for non-`main` branches. On `main`, after the gates pass, it deploys Firebase rules/indexes (plus Storage/Functions when enabled) and the live web app to Firebase Hosting; every web build runs `npm run test:web` and `npm run web:precache`. One-time Firebase and GitHub setup: [Deployment](docs/deployment.md). Test rules/functions locally first. See [Firebase migration and verification](docs/firebase.md) for data import, service configuration, and platform limits.

---

## Project Structure

```sh
lib/
├── main.dart     # Entry point (StartupGuard)
├── app/          # App wiring (router, bootstrap, providers, sync listeners)
├── core/         # Framework utilities, no UI: config, connectivity, firebase, formatting,
│                 #   money, network, notifications, offline (records, OfflineStore,
│                 #   sync state), prediction, storage (local stores, upload queue)
├── features/     # 16 feature modules (accounts, aiko_assistant, aiko_character, auth,
│                 #   calculators, categories, dashboard, export, investments, learning_hub,
│                 #   onboarding, overview, settings, transaction_capture, transactions,
│                 #   travel_mode)
├── shared/       # Cross-feature widgets (widgets/)
├── l10n/         # en/th .arb sources (AppLocalizations is generated), context.l10n, domain enum labels
└── theme/        # Design system (colors, typography, themes)

firebase/         # Firestore/Storage rules, Functions, emulator tests, legacy import tool
web/              # Flutter web entrypoint, bootstrap, service worker (aiko_sw.js), SQLite worker assets
tool/             # Emulator startup helpers, docs link check, web precache script + node tests
docs/             # How-it-works documentation; index: docs/README.md
.github/          # CI quality gates; Firebase Hosting and backend deploy workflows
landing/          # standalone Aiko landing page
screenshots/      # product/idea screenshots and visual references
assets/           # icons/ (app icon, aiko_*.svg marks), images/aiko/ (6 expressions), rive/ (character slot)
test/             # Unit tests
```

Each feature module is layered: `application/` (services, orchestration), `data/` (repositories, DTOs, sync adapters), `domain/` (immutable models, value objects), `presentation/` (screens, widgets, controllers).

---

## Navigation

GoRouter around an adaptive shell, 5 primary destinations: a bottom tab bar on phones (order below); on wide screens a sidebar with Overview first, then the Tools list and Settings/Profile, and a **New transaction** button.

1. **Accounts (`/accounts`)** — Cash, bank, e-wallet, credit card, loan, investment, asset, liability and goal accounts; assets/liabilities summary.
2. **Categories (`/categories`)** — 81 default categories in 13 groups + custom categories/groups; each category owns its budget.
3. **Overview (`/home`)** — Static dashboard, fixed panel set/order: Daily spending (with safe this week, net cash flow, left to save), Daily summary, Net earnings, Category budgets, Spending calendar, Cash flow mapping. App bar: Notifications and Settings; floating quick-add (sidebar button on wide screens); two panel columns on wide screens. Set/order defined by `_homeWidgets` in `home_dashboard_screen.dart`, **not** user-customizable.
4. **Transactions (`/transactions`)** — Month view, search, recurring previews; app bar opens Rules (→ Auto-capture) and Travel Mode; the month card opens the Monthly report.
5. **Aiko (`/aiko`)** — Ask Aiko chat (needs Firebase and an account); app-bar Profile button (`/profile`).

**Settings (`/settings`)** — via the Overview app-bar settings icon. Flat tools list: Chance of Success, Investments, Asset Allocation, Holding Detail, Learning Hub, Calculators, and Export. App preferences include Profile, Appearance and Language.

**Secondary routes:** `/notifications`, `/transaction-rules`, `/transaction-capture`, `/settings/chance-of-success`, `/reports/monthly`, `/export`, `/account-form`, `/profile`, `/connect-line`, `/portfolio`, `/portfolio/allocation`, `/portfolio/holding`, `/calculators`, `/learning-hub`, `/travel-mode`.

---

## Architecture

One Flutter implementation shares domain logic, routes, repositories, and Firebase data across web, iOS and Android. Backend SDKs stay behind repository/service boundaries.

### Feature Module Pattern

`application/` (services, workflows), `data/` (repositories, DTOs, sync adapters), `domain/` (immutable models), `presentation/` (screens, widgets, controllers).

- Screens compose UI + consume Riverpod providers; application services hold business logic + coordinate repositories.
- Repositories own persistence/sync — screens never call Firebase or SQLite directly.
- Domain models stay framework-light. Records (`lib/core/offline/records/`) store primitives only (a record's row is its Firestore document) and map to domain via `record_mappers.dart`.

### Offline-First & Sync

Signed-in finance data lives at `users/{uid}/{collection}/{id}` in Firestore. The Firebase SDK owns its persistent offline cache (on before any Firestore use; multi-tab on web), write queue and last-write-wins document conflicts; no custom finance outbox. `OfflineStore` delegates to it: signed-in writes return once handed to the SDK (never waiting for the server), multi-document operations (transfers with balances, account + adjustment, cascading deletes) are one atomic `RecordBatch` (`commit`), and reads come from the cache once a listener has delivered (`FirestoreSyncState`; otherwise one shared 2 s wait, and a 3 s server read only for an unconfirmed empty cache). `firebaseSyncProvider` owns one listener per collection and invalidates shared providers on inserts, updates and deletes, so views on every device refresh; late rejected writes surface a sync error. The shell's banner says when the device is offline (with the last sync time) or changes are still syncing (`syncStatusProvider`, `connectivity_plus`).

Guests (cloud builds after **Continue without an account**) and local-only builds keep records in `LocalRecordStore` (`aiko_local.sqlite`, IndexedDB on web): a `records` table holding each record's Firestore row as JSON. Each type has one `RecordCodec` in `lib/core/offline/records/`; a new field needs the record, codec, mapper and a round-trip test, no migration. There is no Brick package: an old `aiko_offline.sqlite` is imported once at startup, then deleted.

System templates remain the same 81 categories and 13 groups. Sign-in creates the profile and deterministic per-user UUIDv5 clones only when missing (cache first, server only for misses; offline as one queued batch). Existing profile preferences and budgets are never reset. Guest account/category/group/transaction/holding data, budgets on defaults, attachments and preferences are claimed on sign-in: category references are rekeyed, same-name custom categories and groups merge, and successfully queued local rows are removed to avoid repeated imports. Existing cloud exports can be imported with the create-only dry-run tool in `firebase/tools/`.

Appearance/profile data, language, Travel Mode, transaction rules, lesson progress and notification dismissals synchronize; list preferences merge item by item. OS capture permissions and native notification scheduling remain device-specific; a reminder follows its transaction when another device deletes or edits it. Browser receipt/image/PDF previews and export downloads use bytes instead of native filesystem APIs.

**Offline:** everything works offline on every platform (web after one online visit, through the service worker) except sign-in/up, Ask Aiko, OCR, live prices and rates, LINE and file uploads, which say they need a connection; uploads wait in a queue. A new device needs one online sync; on the web, tabs sharing the local record store see each other's changes only after a reload. See [Architecture → Offline behavior](docs/architecture.md#offline-behavior).

### Code Conventions

- **State:** Riverpod for all state; avoid `setState` outside trivial local UI. Top-level and cross-feature providers in `lib/app/providers.dart`; feature providers in-module (`application/`).
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

Saving never waits for the network. Bytes go to `LocalFileCache` (`aiko_files.sqlite`, IndexedDB-backed on web) and metadata to its device `attachments` table; signed in, an upload job is queued in `FileSyncQueue` (`file_jobs`). The queue runs at launch/sign-in, on resume, on reconnect (restarting an upload still waiting in Storage's retries), on new work and on a 30 s–15 min backoff; a sign-out cancels the running upload and the job waits for its owner; after 5 failed attempts an upload is marked failed (tap to retry). Uploads go to `users/{uid}/receipts/{id}/{fileName}`, and only then is the Firestore `attachments` document written. Transaction detail and edit screens list attachments; files open from the device copy, else download (offline: "needs a connection"). Avatars upload to `users/{uid}/avatars/{microseconds}.{ext}`, one object per save; the profile keeps its previous URL until the upload finishes, then the old object is deleted. Local cache paths are device-specific and fall back to cloud images on other devices.

The domain supports PDF, JPEG, PNG, WebP, HEIC, text/CSV/Markdown and Word files, up to 10 MiB. Images, PDFs and text have browser/native previews; HEIC and Word use an unsupported-preview fallback. Browsers have no scheduled notifications or SMS/notification capture (Android only); reminder times remain part of the shared transaction.

### Cost & Boundaries

Use the SDK cache and shared listeners, not a new listener per widget. Keep files in Storage and structured records in Firestore. Financial calculations stay in Dart/domain services. Cloud Functions own privileged deletion, LINE linking, AI and optional external providers; UI never accesses Admin credentials.

---

## Core Features

- **🏠 Dashboard** — static fixed-order panels (above) + quick-add. Not user-customizable.
- **💰 Money Tracking** — 13 transaction types (income, expense, transfer, refund, investment buy/sell, dividend, interest, loan payment, credit card payment, tax payment, fee, adjustment); transfers save linked `transferOut`/`transferIn` legs, edited and deleted together; opening balances and balance edits are signed adjustments, never income or spending. Receipts/attachments, recurring (Once/Daily/Weekly/Monthly/Annually, each with own end date or occurrence cap), reminders. Amount-first quick entry with cloud OCR and typed/dictated voice parsing. Rules auto-apply category and tags by merchant, keyword, amount, account, category or type. Android can auto-capture bank SMS and notifications (opt-in, on-device, works offline; Aiko's own notification listener, never booked twice). Not built yet: splits (modeled, not saved), duplicate detection.
- **📊 Budgeting (in Categories)** — each Category owns an optional budget: daily/weekly/monthly/yearly, rollover of unused budget into the next period, thresholds (default 50/75/90/100%). Groups can hold an envelope budget; every category carries a fixed 50/30/20 bucket (needs/wants/savings/…) used by cash-flow views. Zero-based budgeting isn't built. Safe-to-Spend: `Leftover = Income − Spent − Unspent budgets` for the month; weekly safe = `(Income − Spending) ÷ 4.33` ([Calculations](docs/calculations.md)). Daily Spending compares today's posted expenses with the daily safe amount and shows Aiko's green, orange, or red reaction; with nothing safe to spend it asks for this month's income, or stays calm while nothing is spent.
- **🎯 Goals (in Accounts)** — goal accounts (`Account.type == goal`) carry SMART target, date, priority. `currentBalance` is saved amount; Chance of Success reads the same row and projects the goal's own average monthly deposits.
- **📈 Insights & Predictions** — cash flow (month + 12-month trend) + Sankey by budget group, safe-to-spend, monthly report vs. the month before (any month), budget/bill/goal notifications (tap to open, dismiss until the next period), Monte Carlo goal probability. Not built yet: end-of-month forecasts, overrun prediction, net worth projection, retirement readiness.
- **🤖 Aiko AI Assistant** — streaming chat grounded in an on-device snapshot plus six read-only server tools; rule-based budget recommendations on category budgets; monthly report. Debt strategies come only from the chat model.
- **💳 Credit & Debt** — credit cards (limit or shared limit, statement/due day, APR, rewards, annual fee, minimum payment), loans (principal, rate, term, payment, next due date), upcoming-payment notifications, credit card payoff calculator. Not built yet: statement balances, utilization, snowball/avalanche simulation.
- **📱 Portfolio, Assets & Tax** — holdings in their own currencies with unrealized gain/loss and base-currency totals, allocation by asset class, rebalance alerts against fixed Stocks 70% / Bonds 30% targets, live prices via `marketFeed` (cloud only, signed in), dividend/interest/tax transactions, asset and liability accounts, receipt/document attachments. Not built yet: realized gains in the UI (a capital-gains service exists), allocation by currency/geography/risk, net worth trends, tax flagging, estimated tax reports.
- **🌍 Travel Mode** — trip with home/local currency and budget, live, saved, reference or manual exchange rate (never assumed 1.0), converter, foreign-fee log with merchants; accounts can use any currency. Exchange rates are cached on the device for offline totals and forms. Not built yet: trip reports.
- **📤 Export & 📚 Learning Hub** — CSV (plain or Excel-friendly, signed amounts, formula-safe) and a printable HTML statement with per-currency totals; four lessons with quizzes and saved progress, glossary terms inline.

## Calculator Suite (30)

All 30 have a form and result in English and Thai. Calculator scenario saving/comparison is not wired yet. Library: `calculator_library_screen.dart`; forms: `calculator_forms.dart` (rendered by `calculator_detail_screen.dart`); math: `CalculatorServices` and `thai_tax_rules.dart`. Details: [Features → Calculators](docs/features.md#calculators), formulas: [Calculations](docs/calculations.md#calculators).

- **Saving & investing:** Compound interest, Savings goal, ROI, Time value of money, IRR/NPV, Fixed deposit, Bond yield, Tax equivalent yield, Rule of 72.
- **Debt, home & cars:** Loan, Credit card payoff, Bi-weekly mortgage, Refinance savings, Rent vs. buy, Home affordability, Rental property cash flow, Car hire purchase vs. lease.
- **Retirement:** Tax-saving funds (RMF, Thai ESG), Retirement drawdown, Social Security pension (Section 33), Annuity payout.
- **Business, tax & everyday:** WACC, Black-Scholes, CAPM, Income tax and take-home pay, Capital gains tax, Salary to hourly, Currency converter, Inflation, Tip and percentage.
- **Specified but not in the library:** Amortization & comparison, APR, Retirement savings & income planner, Minimum payment, Balance transfer, Expected return, Holding period return, Effective rate, Margin/markup.

## Prediction & AI System

- Rule-based summaries: safe-to-spend, cash flow, budget progress, threshold/bill/goal notifications, display-only recurring projections. Not built yet: end-of-month balance forecast, overrun risk, moving-average trends, seasonality detection.
- Monte Carlo goal probability (1,000 seeded runs, 6% return, 12% volatility, the goal's average monthly net deposit over the last six months) with conservative/expected/optimistic outcomes (10th/50th/90th percentile). Engine in `lib/core/prediction/`, inputs in `GoalForecastService`.
- Ask Aiko streams guidance from the server-side chat function. Persist generated insight rows only when a real product screen and generator own them.
- **Disclaimer required:** *AI insights are estimates, not certified financial, investment, or tax advice.*

---

### Ask Aiko, LINE, and optional providers

`HttpChatEngine` streams `data: {"delta":"..."}` events from the `aikoChat` Firebase HTTPS function, ending with `{"done":true}` or a stable error code (`PROVIDER_DOWN`, `STREAM_FAILED`). A message that needs no tool costs one provider call; requests are time-bounded and cancelled when the app disconnects. The function verifies the Firebase ID token, rate limits the user, and owns the system prompt. It accepts the on-device financial snapshot and six read-only tools for account summaries, budget status, spending by category, cash flow, recent transactions and goal progress. Every tool receives the verified UID and reads only that user's collections; model input cannot choose another owner. Provider failures before or during streaming are reported without inventing an answer.

The function sends headers at once and an SSE `: ping` every 15 s; the app allows 15 s to connect, 60 s for a response and 45 s between chunks, and marks cut-off answers, so deploy Functions with or before the app. Server-only secrets: `AI_API_KEY`, `AI_MODEL`, `AI_BASE_URL` (OpenAI-compatible endpoint). Local values belong in `firebase/functions/.secret.local` (gitignored). Unconfigured cloud AI returns 503; builds without Firebase have no chat (the Aiko tab replies "Connect to Aiko cloud to chat."), and guests are asked to sign in (nothing is sent). API reference: [Backend](docs/backend.md). Production secrets use Firebase Secret Manager.

`lineWebhook` verifies the LINE HMAC; `redeemLinePairing` consumes a hashed, expiring code transactionally under Firebase Auth. Link records are server-only; the profile sees an `integrations/line` status document. Unlike the previous backend, no user refresh token is stored for LINE. Configure `LINE_CHANNEL_SECRET` and `LINE_CHANNEL_ACCESS_TOKEN`, then point LINE to `lineWebhook`. OCR (`ocrScanner`) and price refresh (`marketFeed`) use explicitly configured server providers (`OCR_API_URL`/`OCR_API_KEY`, `MARKET_API_URL`/`MARKET_API_KEY`); they report unavailable when unset.

## Account Deletion

Profile deletion needs a connection: the app checks the server, pauses the upload queue (letting a running upload finish) and lets pending writes upload, then calls the authenticated `deleteAccount` callable. It requires a sign-in from the last five minutes (otherwise the app asks you to sign in again), deletes the user's Firestore subtree, Storage objects and LINE mapping, then deletes the Firebase Auth identity. It is immediate and permanent; no grace period. Privileged server code always derives the UID from verified authentication.

## Database Schema

`users/{uid}` contains `profiles`, `accounts`, `transactions`, `transaction_splits` (allowed by rules, not written yet), `categories`, `category_groups`, `attachments`, `investment_holdings`, `preferences` (`{value}` or itemized `{items}`), and read-only `integrations`. Field reference: [Data model](docs/data-model.md). Profiles use the UID as document ID; other entities keep their existing IDs and snake_case fields. Money values are decimal strings. Budgets remain category fields, goals remain account fields, recurring/reminder metadata remains on transactions, and attachment metadata references Storage paths. Global server-only `line_links`, `line_pairings`, and `rate_limits` cannot be read by clients. All other unspecified paths are denied.

**Backend changes:** update `firebase/firestore.rules`, `firebase/storage.rules`, Functions and tests together. Run emulator tests and the function build; merging to `main` deploys them through CI once tests pass. `firebase/tools/import_legacy.cjs` imports existing exported users, records and files with stable IDs; dry run is the default. Historical SQL design notes under `docs/superpowers/` describe the replaced backend, not active deployment instructions.

---

## Design System

Source of truth for visuals/patterns/components. Don't add one-off colors/radii when a token exists. Code: `lib/theme/aiko_colors.dart`, `aiko_theme.dart`, `aiko_typography.dart`; spacing and radii are applied in component themes and widgets (no spacing token file yet). Code map: [Design system implementation](docs/design-system.md).

**Tokens — three layers:** Primitive (`AikoColors`, `AikoTypography`), Semantic (`ColorScheme`; no custom theme extensions yet), Component (`AikoTheme`, shared widgets).

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
| Placeholders | State what the feature will do + one action. No fake dashboards. Use `AikoScreenState`. |

### Components

- **`FinanceCard`** (objects/metrics/grouped panels): 8px radius, 16px default / 20px prominent padding, outline-variant border, no shadow, `titleMedium` title, `bodyMedium` body, 40px icon tile (8px radius, 12% accent opacity), stable `InkWell`. Three-tier hierarchy: primary number/title → metadata → one action/status. Never a wrapper around another card.
- **Buttons:** filled (primary), outlined (secondary), text (inline), icon. Min 48px, 8px radius, visible disabled.
- **Icon buttons:** 40–48px tile, 48px tap target — Primary blue circle/white, AI/premium purple, Destructive red.
- **Inputs/pickers:** visible labels, 54px min height, 8px radius, pale-blue fill, thin blue-gray border, leading search icon, primary focus border, danger error border, muted placeholder, helper/validation below. Pickers show selected value + context; bottom-sheet pickers use compact rows with checkmarks.
- **Lists:** compact `ListTile`, 48px tap target, single-line titles, aligned trailing, dividers/card borders not nested containers.
- **Chips/badges:** short labels; status color matches semantic meaning + text.
- **Navigation:** shell tabs Accounts/Categories/Overview/Transactions/Aiko (`aikoPrimaryDestinations`); wide screens: sidebar (icon rail < 1200px, labeled ≥ 1200px) with the same destinations + Tools, selected = 12% tint + 3px leading indicator; flush compact 60dp bar (1px top border, surface bg, no pill/shadow); active = 3dp top indicator in primary blue (purple for Aiko) with icon + label; Aiko's unselected label muted purple. Aiko tab opens Settings hub.
- **Sheets/dialogs:** bottom sheets for mobile create/edit (drag handle, safe area, scrollable, 20px top radius), shown as centered dialogs on wide screens via `showAikoSheet`; detail/form pages full-screen on phones, dialogs on wide screens via `openAikoPage` (an outside click or Escape doesn't close them); forms with unsaved input ask first (`AikoDiscardChangesGuard`); dialogs for destructive confirmation (name object + effect, red button).
- **Snack bars & status text:** `aikoSnackBar` on the neutral theme background, never a green/orange/red fill; words in a status color use `AikoStatusColors` (≥4.5:1).
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

Reusable SVGs in `assets/icons/` as `aiko_<name>.svg`, `viewBox="0 0 24 24"`, `currentColor`, stroke-based, single-color. Don't mix filled/duotone/outline in one group. Today only `aiko_aiko.svg` (avatar mark) and `aiko_title.svg` ship, and the UI uses Material Icons. Add an asset test (for example `test/shared/widgets/aiko_svg_assets_test.dart`) with each new brand SVG before the UI relies on it. Planned brand set (not drawn yet): `aiko_home`, `aiko_transactions`, `aiko_budget`, `aiko_aiko`, `aiko_account`, `aiko_bank`, `aiko_wallet`, `aiko_credit_card`, `aiko_category`, `aiko_receipt`, `aiko_search_filter`, `aiko_goal`, `aiko_cash_flow`, `aiko_debt`, `aiko_loan`, `aiko_portfolio`, `aiko_tax`, `aiko_calculator`, `aiko_travel`, `aiko_security`, `aiko_notification`.

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

Works at 390px and 1440px wide and in Thai; main task in first viewport; primary action obvious + reachable while scrolling; numbers before AI guidance + with context; lists compact/tappable; fields labeled with recovery-oriented validation; empty/loading/error/offline states exist or intentionally inherited; no nested cards/decorative shadows/oversized radii; raw colors limited to theme files or data-viz; no text clipping at small widths; dark contrast sufficient; Aiko only where useful; no main-route duplication.

Account-type-specific inputs: add each from fresh state (subform appears/validates/saves); edit each (values pre-populate, round-trip identical); toggle shared limit (field appears/disappears, card picker excludes self); delete parent card (child detail shows migration notice); offline add (persists locally, syncs on reconnect, no double-write).

---

## Testing

**No UI/widget tests.** Don't write `testWidgets`/`pumpWidget` tests for screens, widgets, rendering, or interaction. Test logic only — `*Service` function objects, `Money`/Decimal math, prediction, parsers, rules, repositories, providers, models. A widget already couples UI + logic; isolate and unit-test the logic underneath instead.

```bash
flutter test                       # money types, formatters, prediction, models, providers, rules,
                                   # codecs, stores, sync, parsers
npm run test:web                   # service worker + precache script (Node)
```

**Quality gates — run all before any release:**

```bash
npm --prefix firebase/functions test
npm run test:rules                 # requires running emulators; or wrap it in
                                   # npx firebase emulators:exec --project demo-aiko --only auth,firestore,storage,functions
flutter build web
npm run test:web
dart format --set-exit-if-changed lib test
flutter analyze lib test
flutter test
npm run docs:check
```

CI runs these on every push ([Testing](docs/testing.md)).

---

## Monetization & Security

Planned tiers. No plan gating exists in code yet; every feature is available to every user.

| Plan | Includes |
| --- | --- |
| **Free** | Manual tracking, basic categories/budgets/charts, limited calculators, CSV export, basic Ask Aiko guidance |
| **Premium** | Unlimited accounts, advanced reports, AI recommendations, forecasting, OCR, CC optimization, portfolio analytics, tax reports, PDF/Excel export, multi-device sync |
| **Pro** | Double-entry accounting, balance sheets, reconciliation, business reports, invoices, multi-user, advanced tax, estate planning, full Monte Carlo, API access |

**Security:** secure storage for device keys, owner-only Security Rules, server-side secrets, last-write-wins sync, local-only and guest modes, notification capture that broadcasts nothing. Not built yet: remote device logout, AI-use acknowledgement (the old onboarding consent flag was removed), PIN/biometric app lock. Details: [Security and privacy](docs/security.md).

---

## Roadmap

Phases 1–6 ✅ (Foundation; Core Finance; Intelligence; Advanced Finance; Wealth; Platform): core flows shipped; unfinished items are in [Known gaps](docs/features.md#known-gaps). **Future:** Open Banking sync, advanced retirement, estate planning, automated AI advisor, Pro API access.

## Common Tasks

- **New feature module:** create `lib/features/<name>/` (4 layers); add routes; new collection → owner-scoped Firebase rules; offline → record + codec + mapper + round-trip test; register app-wide providers; add model/repository-fallback/provider tests; use `Money`.
- **New calculator:** add a `_CalculatorItem` in `calculator_library_screen.dart` and its `CalculatorForm` in `calculator_forms.dart` (pure math in `CalculatorServices`, with tests); add persistence/conversion only when the product flow exists. See [Contributing → Adding a calculator](docs/contributing.md#adding-a-calculator).
- **New generated insight surface:** add the product screen first, then define the generator, persistence model/table, provider, display states, source-data references, Security Rules, and tests.
- **New backend field:** extend its record codec, Security Rules, and round-trip/emulator coverage.

## Key Principles

1. Clarity first. 2. Data first, Aiko enhanced. 3. Decimal-safe money (never `double`). 4. Privacy by design (Security Rules everywhere, secrets server-side, local-only and guest modes; planned: encrypted local storage, AI use acknowledged at onboarding). 5. Offline first. 6. Actionable insights. 7. Warm, non-judgmental tone. 8. Test before ship.

## Contributing

Use `Money` (never `double`); go through repositories (screens never touch Firebase/SQLite); update records/codecs for offline; batch related writes; add Security Rules to every new collection; consume shared widgets/tokens; write unit tests for new models/providers; run the QA checklist + all quality gates; keep Aiko's voice warm and non-judgmental. Step-by-step recipes: [Contributing](docs/contributing.md).

**License:** Private; not published to pub.dev. See `pubspec.yaml`.

## Task plan

There is no `TASKS.md`; open work is tracked in [Features → Known gaps](docs/features.md#known-gaps). Fix small, low-risk data-loss and security gaps first, then grow scope.
