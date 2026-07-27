# Aiko — Personal Finance Management App

**AI-powered personal finance, guided by Aiko** — a calm, blue-haired AI companion. Track · Budget · Save · Invest · Plan.

## Rules

- Brief; include risks, assumptions, validation. Recheck this file before repo work; update only for durable conventions.
- Keep this file compact yet readable — when editing, condense wording without dropping any instruction or detail.
- Agent workflow: work directly on `main` and execute inline. Do not create worktrees or feature branches, delegate to subagents, or ask about execution/branch disposition unless the user explicitly requests an exception.

---

## What Is Aiko?

Cross-platform (iOS + Android) personal finance app: Flutter + Supabase. **Aiko** (calm, anime-style, blue hair) gives friendly, non-judgmental money guidance. A data-first financial OS: 13 transaction types, category-owned budget limits (envelope / zero-based / 50-30-20, monthly/weekly/yearly/daily, rollover), goal accounts (SMART target/date/priority, Monte Carlo probability), cash flow + Daily Spending reactions, credit/debt/loan payoff, portfolio + net worth, tax organization, ~60 calculators, AI guidance, Ask Aiko chat, monthly Review, learning hub, multi-currency Travel Mode.

This is a single repo for the Aiko product surface: Flutter app, landing page, Supabase/infra, docs, visual references, and tests. Do not remove `landing/`, `screenshots/`, or `docker/` as "unused" unless their workflows are replaced.

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
| Mobile | Flutter & Dart (SDK ^3.11.5) |
| State | Riverpod |
| Navigation | GoRouter |
| Backend | Supabase (Auth, Postgres, Storage, RLS) |
| Offline Store | Brick + SQLite (`sqflite`) |
| Sync | Brick request queue → Supabase after local writes |
| Attachments | Supabase Storage (per-user bucket) + Postgres metadata; currently validated uploads are PDF/JPEG/PNG |
| Money | `decimal` (no floating-point) |
| Charts | `fl_chart` |
| Security | `flutter_secure_storage` |
| IDs | `uuid` |
| Export | `csv`, `share_plus`, `path_provider` |
| Formatting | `intl` (locale-aware) |

---

## Getting Started

**Prerequisites:** Flutter (stable, ^3.11.5), a Supabase project, Supabase CLI, Android Studio / Xcode emulators.

```bash
git clone <repository-url> && cd aiko
flutter pub get
dart run build_runner build        # regenerate Brick adapters + SQLite migrations after offline model changes

cp .env.example .env                # set SUPABASE_URL and SUPABASE_ANON_KEY (anon key only — never service-role)

supabase login
supabase link --project-ref <your-project-ref>
supabase db push                    # all tables + RLS
# Optional dev-only seed: psql <db-url> -f supabase/seed.sql

flutter run -d <android|ios> \
  --dart-define=SUPABASE_URL=https://your-project-ref.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<your-anon-key>
```

> **⚠️ Security:** Never put a service-role key in the app, `.env`, dart-defines, or any client-visible config. Without `SUPABASE_URL`/`SUPABASE_ANON_KEY` the app runs local-only (SQLite via Brick); cloud sync starts once Supabase is configured and the user is authed.

### Self-hosted Supabase

`docker/` is required local infrastructure for self-hosted Supabase. It contains the official `supabase/supabase` Docker stack plus `docker-compose.aiko.yml`, which mounts `supabase/functions/aiko-chat` into the edge runtime. Keep this directory unless the self-hosted workflow is replaced.

```bash
cp docker/.env.example docker/.env
cd docker
sh utils/generate-keys.sh --update-env
sh utils/add-new-auth-keys.sh --update-env
docker compose up -d
```

`docker/.env` is gitignored and holds local dashboard credentials plus generated keys; never commit it. Store `AI_*` / `LINE_*` secrets there for local self-hosted edge runtime use.

API + Studio run at `http://localhost:8000`. Apply migrations to the local stack:

```bash
PGSSLMODE=disable supabase db push --yes --include-all \
  --db-url "postgresql://postgres.aiko:<POSTGRES_PASSWORD>@localhost:5432/postgres"
```

Run the app against self-hosted Supabase with `--dart-define=SUPABASE_URL=http://localhost:8000` (Android emulator: `http://10.0.2.2:8000`) and the generated `ANON_KEY`.

### Google Sign-In (native)

Login uses the **native** Google account picker (`google_sign_in` → ID token → Supabase `signInWithIdToken`), not a browser redirect. Account **linking** (Profile → Connect Google) still uses the OAuth redirect flow via the `aiko://login-callback` deep link.

1. **Google Cloud → Credentials**, create OAuth client IDs:
   - **Web application** → its client ID is `GOOGLE_WEB_CLIENT_ID` (passed as `serverClientId`; also set as the Client ID on Supabase's Google provider).
   - **Android** → package name + your signing SHA-1. Not referenced in code; matched by Play Services at runtime.
   - **iOS** → its client ID is `GOOGLE_IOS_CLIENT_ID`.
2. **Supabase → Auth → Providers → Google:** enable it, paste the Web client ID + secret, and turn on **Manual linking** (required by `linkGoogle`).
3. **iOS only:** in `ios/Runner/Info.plist`, replace the `com.googleusercontent.apps.YOUR_IOS_CLIENT_ID` URL scheme with the *reversed* iOS client ID.
4. Run with the client-id dart-defines (web id required; iOS id required on iOS):

```bash
flutter run -d <android|ios> \
  --dart-define=SUPABASE_URL=https://your-project-ref.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<your-anon-key> \
  --dart-define=GOOGLE_WEB_CLIENT_ID=<web-client-id>.apps.googleusercontent.com \
  --dart-define=GOOGLE_IOS_CLIENT_ID=<ios-client-id>.apps.googleusercontent.com
```

---

## Project Structure

```sh
lib/
├── brick/        # Brick offline models, adapters, SQLite schema, mappers
├── main.dart     # Entry point
├── app/          # App wiring (router, bootstrap, providers)
├── core/         # Framework utilities, no UI: config, errors, formatting, monetization,
│                 #   money, notifications, offline, prediction, security, storage, supabase, sync
├── features/     # 16 feature modules (accounts, aiko_assistant, aiko_character, auth,
│                 #   calculators, categories, dashboard, export, investments, learning_hub,
│                 #   onboarding, overview, settings, transaction_capture, transactions,
│                 #   travel_mode)
├── shared/       # Cross-feature widgets, state, test data
├── l10n/         # .arb sources; AppLocalizations is generated by Flutter
└── theme/        # Design system (colors, typography, spacing, themes)

supabase/         # migrations/ (Postgres + RLS + functions), seed.sql, storage/
docker/           # self-hosted Supabase stack and Aiko edge-runtime compose overlay
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

Optimizes for low backend cost, strong offline, fast UX, low lock-in: remote is standard Postgres behind repository interfaces (Supabase → self-hosted → custom Postgres without UI changes).

### Feature Module Pattern

`application/` (services, workflows), `data/` (repositories, DTOs, sync adapters), `domain/` (immutable models), `presentation/` (screens, widgets, controllers).

- Screens compose UI + consume Riverpod providers; application services hold business logic + coordinate repositories.
- Repositories own persistence/sync — screens never call Supabase, Brick, or SQLite directly.
- Domain models stay framework-light. Brick models (`lib/brick/models/`) store primitives only, map to domain via `lib/brick/offline_model_mappers.dart`.

### Offline-First & Sync

Core finance data reads/writes locally first via [Brick](https://github.com/GetDutchie/brick) (SQLite local, Supabase Postgres remote). Brick handles mapping, cache, the Supabase provider, the sync queue, local query subscriptions — no hand-rolled outbox/retry/mappers.

- **Optimistic local writes:** profiles/accounts/categories/transactions/category budgets/goal accounts persist to SQLite immediately, UI updates at once. With Supabase + auth, Brick queues writes and syncs in background; when unavailable, repositories return local data or safe empty/default states — never backend errors in normal flows. Prefer `tryClient()` + offline fallback over `AikoSupabase.requireSession()` in user-facing repositories.
- **⚠️ Known gap (offline, no Supabase config):** `accountsProvider`, `transactionsProvider`, `categoriesProvider`, `dashboardSummaryProvider`, `dashboardDueItemsProvider` (`lib/app/providers.dart`) call repositories without try/catch. If the offline store or `OfflineUserContext` throws (fresh install, secure-storage channel unavailable), the error reaches `AikoScreenState.error` → "X is unavailable". Fix: wrap each provider body in try/catch returning an empty list / default summary.
- **Brick `details_json` round-trip (regen-safe):** `OfflineAccount.detailsJson` is a local VARCHAR and a Supabase `jsonb` column `details`. Supabase round-trip via `accountDetailsFromSupabase`/`accountDetailsToSupabase` (`account.model.dart`, `@Supabase(fromGenerator/toGenerator)`); local read tolerates legacy NULL via `accountDetailsFromSqlite` (`@Sqlite(fromGenerator)`). Safe to re-run `build_runner`. Coverage: `test/brick/account_details_json_test.dart`.
- After editing `lib/brick/models/`, run `dart run build_runner build` and commit generated adapters/schema/migrations.
- **System (default) categories:** Supabase keeps 81 category and 13 group templates as immutable global rows (`user_id = NULL`) with fixed stable UUIDs. Account setup creates deterministic per-user UUIDv5 clones with `template_id` pointing to those templates; transactions and budgets reference the user clones, which Brick stores normally but the UI keeps read-only. Anonymous local data may use template IDs temporarily; sign-in rekeys groups, categories, and transaction references to the authenticated user's clone IDs before sync.
- Use Supabase for Auth, Postgres, RLS, structured finance data, attachment storage. By default avoid Realtime/Edge Functions (unless server logic needed) and large blobs in Postgres.

### Code Conventions

- **State:** Riverpod for all state; avoid `setState` outside trivial local UI. Top-level providers in `lib/app/providers.dart`; feature providers in-module; shared state in `lib/shared/state/`.
- **Provider caching:** long-lived list/summary providers call `ref.keepAlive()` *after* a successful load, so switching tabs reuses cached data (no full-screen skeleton flash). A failed load isn't cached and retries. Trade-off: cached screens don't auto-refresh on revisit — screens that go stale own a `RefreshIndicator` calling `ref.refresh(<provider>.future)` (see `_refresh` in `home_dashboard_screen.dart`). Panels watching a notifier update live after writes; `dashboardSummaryProvider`-derived numbers wait for pull-to-refresh.
- **Routing:** all routes in `lib/app/app_router.dart`. Kebab-case paths. Idea-inspired screens belong to the existing feature owner — add subroutes/menus/inline tools, never duplicate a main screen. Accounts/Categories are primary nav tabs — don't add them as Planning/Menu cards.
- **Money:** never `double`. Use `Money` (`lib/core/money/money.dart`, wraps `Decimal`); format via `lib/core/formatting/money_formatter.dart`. Base currency in profile; multi-currency for travel/portfolio.
- **Naming:** files `snake_case.dart`, classes `PascalCase`, vars/functions `camelCase`, routes `/kebab-case`, DB `snake_case`.
- **`super.key` (T-705):** every widget constructor taking `Key?` forwards it as `super.key`.
- **Notifier / Service / Controller (T-601):** `*Notifier` (reactive Riverpod state, owns in-memory snapshot, `ref.keepAlive()`); `*Service` (pure/near-pure function object, no Riverpod/refs, `const` ctor, unit-testable); `*Controller` (orchestrates Notifier + Service + UI side effects, owns stream/retry/message derivation); `*Repository` in `data/` (wraps a Brick `OfflineStore`, never touches `ref`/`BuildContext`).

### Sync Fields & Conflict Resolution

Most user-owned finance tables carry `id`, `user_id`, timestamps, and `version integer not null default 1`; small metadata tables such as `attachments`, `transaction_splits`, and LINE pairing tables intentionally use narrower shapes. Deletes are **hard deletes** (`OfflineStore.delete` removes local row + queues remote `DELETE`; SQLite-only offline). No `deleted_at` tombstone. **Known gap:** a row deleted while signed out in cloud mode is removed locally but its remote `DELETE` isn't queued (no session), so it won't propagate on next sign-in.

Conflicts: transactions/categories/category budgets — latest `updated_at` wins; important records — compare `version`; summaries — recalculated, never merged; balances — calculated/snapshot; attachments — local file/Storage object plus metadata via Postgres.

### Summaries

Dashboards/reports calculate summaries from local data and repository projections. No remote summary tables are part of the squashed initial schema yet.

### Receipt & Attachment Strategy

Attachments live in **Supabase Storage** under a per-user RLS-protected path — never Postgres `bytea`; only metadata goes to Postgres. Capture supports camera/gallery/file picker. Receipt OCR, when enabled, runs against the selected image bytes before metadata is saved. The domain currently validates PDF/JPEG/PNG attachment uploads.

**No data loss:** the receipt/document file is recorded locally before metadata upload; the `attachments` row stores metadata and the Storage path. Failed remote writes return the local attachment object so the transaction flow can continue offline. Deletes hard-delete the row + Storage object. Local files act as a persistent cache and should be reclaimed only under LRU pressure.

`attachments`: `id`, `user_id`, `storage_bucket`, `storage_path`, `file_name`, `content_type`, `size_bytes`, `linked_entity_type`, `linked_entity_id`, `is_sensitive`, `export_policy`. Storage behind `RemoteAttachmentStorage` (`upload`/`delete`/`getDownloadUrl`); `SupabaseAttachmentStorage` uploads + serves signed URLs — backend swappable without UI changes.

### Cost & Lock-in

Keep cost low: reads from local SQLite, dashboards from local summary tables, batched writes, compressed attachments. Avoid: loading all transactions from Supabase per screen, Realtime every session, image bytes in `bytea`, Edge Functions for simple CRUD, direct Supabase calls from UI. Low lock-in via standard Postgres schema, repository interfaces, Dart business logic, file storage behind `RemoteAttachmentStorage`.

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

## Ask Aiko Chat Backend (`aiko-chat` Edge Function)

Supabase Edge Function (`supabase/functions/aiko-chat/`) — an SSE proxy streaming Chat Completions from **one configured OpenAI-compatible provider**. Provider key stays server-side.

**Request flow:** (1) validate caller's Supabase JWT (`Authorization: Bearer <jwt>`); (2) build message list (last 20) behind a fixed system prompt defining Aiko's persona, forcing the disclaimer on numeric/recommendation answers, injecting `baseCurrency`; (3) run Layer 2 tool calls; (4) stream the answer (`stream: true`), re-emitting each token as `data: {"delta":"..."}\n\n`, closing with `data: {"done":true}\n\n`. Client: `HttpChatEngine` (`chat_engine.dart`) calls `${SUPABASE_URL}/functions/v1/aiko-chat`.

**Failure handling:** a failure before any token reaches the client (network error, non-2xx, 60s timeout, or an immediate stream break) ends the stream `data: {"error":"...","code":"PROVIDER_DOWN"}\n\n`. Once tokens flow, a mid-stream error is a final `error` event (can't safely restart).

**How Aiko reads your data** (model only sees RLS-scoped data; key never leaves server):

- **Layer 1 — on-device snapshot (always on).** Client assembles a compact `AikoFinancialContext` (net worth, accounts, this-month income/spending, budget pace, goals, recent transactions) from local Brick, sends it in the body; the function folds it into the system prompt. Aggregates only, capped, never the full ledger.
- **Layer 2 — server-side tools (always on).** Model may first call a fixed allow-list of **read-only** Postgres RPCs (`aiko_*` functions in the squashed initial migration), each `SECURITY INVOKER` under the caller's JWT (RLS scopes results). Never runs model-supplied SQL, never uses service-role.

**Configuration** (Supabase secrets — never in app/`.env`). One provider, set via three secrets; if any is missing the chat endpoint returns `MISSING_PROVIDER_KEY` (and the LINE path replies with a fallback message).

```sh
supabase secrets set AI_API_KEY=sk-...
supabase secrets set AI_MODEL=deepseek-v4-flash
supabase secrets set AI_BASE_URL=https://api.deepseek.com/v1   # OpenAI-compatible base; the function appends /chat/completions
```

`SUPABASE_URL` / `SUPABASE_ANON_KEY` injected by runtime. Any OpenAI-compatible endpoint works — e.g. `https://api.openai.com/v1`, `https://generativelanguage.googleapis.com/v1beta/openai`. To switch providers, change the three secrets and redeploy; no code change.

**LINE bot (merged in):** the LINE webhook lives in this same function — a `POST` with `x-line-signature` routes to the LINE handler, which verifies LINE's HMAC, looks up the linked user (service-role, server-side only), refreshes that user's token, runs the **same chat pipeline in-process**, and replies via the LINE reply API. Linking happens in-app (Profile → Connect LINE) via a pairing code (`line_pairings` / `line_links`, `redeem_line_pairing` RPC). Extra secrets: `LINE_CHANNEL_SECRET`, `LINE_CHANNEL_ACCESS_TOKEN` (`SUPABASE_SERVICE_ROLE_KEY` injected, used only here). Point the LINE Webhook URL at `…/functions/v1/aiko-chat`.

**Deploy & local dev** — deploy with `--no-verify-jwt` (LINE calls carry a LINE signature, not a Supabase JWT; safe because the app path validates the JWT in code via `getUser` and the LINE path verifies its own signature):

```sh
supabase functions deploy aiko-chat --no-verify-jwt
supabase functions serve aiko-chat --env-file ./supabase/functions/.env.local
```

**Errors** (before stream = JSON with `code`; after = `data: {"error":"..."}` then close):

| Status | `code` | Meaning |
| --- | --- | --- |
| 400 | `BAD_REQUEST` | `messages` missing/malformed |
| 400 | `BAD_JSON` | Body not valid JSON |
| 401 | `NO_TOKEN` | Missing `Authorization` |
| 401 | `BAD_TOKEN` | JWT rejected |
| 405 | `METHOD_NOT_ALLOWED` | Non-POST |
| 500 | `MISCONFIGURED` | Missing Supabase env |
| 500 | `MISSING_PROVIDER_KEY` | `AI_API_KEY`, `AI_MODEL`, or `AI_BASE_URL` not set |
| 502 | `PROVIDER_DOWN` | Provider unreachable / failed before any token |
| 502 | `PROVIDER_ERROR` | Upstream non-OK before stream |

---

## Account Deletion

"Delete account" (Profile) deletes **immediately and permanently** — no grace period. `AuthRepository.deleteAccount` calls the `delete_account` Postgres RPC under the user's JWT, then signs out.

`delete_account()` (in the squashed initial migration) is a `SECURITY DEFINER` function: it runs as its definer so it can reach `auth.users`. It derives the caller from `auth.uid()` (never a parameter), deletes the `profiles` row (cascades all finance data via `on delete cascade`), then deletes the `auth.users` login. Schema quirk: `profiles.id` is *not* FK'd to `auth.users`, so the profile row must be deleted explicitly. `execute` is granted to `authenticated` only.

No Edge Function, no `pg_cron`, no service-role key, no email — the privilege lives in the function, not the client. (Replaces the old 3-day grace scheme: `delete-account` / `purge-deleted-accounts` functions and the hourly purge cron.)

After editing the migration: `supabase db push`.

---

## Database Schema

10 core tables, all under RLS:

`profiles`, `accounts`, `transactions`, `transaction_splits`, `categories`, `category_groups`, `attachments`, `investment_holdings`, `line_links`, `line_pairings`.

`categories` has 81 global system rows (`user_id = NULL`, `is_default = true`) plus user rows. All tables enforce `user_id = auth.uid()` via RLS, **except** `categories`: SELECT allows `user_id IS NULL OR user_id = auth.uid()`; INSERT/UPDATE/DELETE scoped to `auth.uid()`.

### Entity Fields

| Entity | Fields |
| :--- | :--- |
| **Profile** | `id`, `display_name`, `email`, `base_currency`, `country`, `timezone`, `preferred_theme`, `onboarding_status`, `security_status`, profile metadata |
| **Account** | `id`, `user_id`, `name`, `type`, `currency`, `current_balance`, `institution`, `details`, goal fields, `include_in_net_worth`, `is_active` |
| **Transaction** | `id`, `user_id`, `account_id`, `type`, `amount`, `currency`, `exchange_rate_to_base`, `category_id`, `date`, `merchant`, `note`, `tags`, recurrence fields, `tax_flag`, `status` |
| **TransactionSplit** | `id`, `user_id`, `transaction_id`, `category_id`, `amount`, `note`, `tax_flag` |
| **Category** | `id`, `user_id`, `name`, `parent_id`, `type`, `group_id`, `icon`, `color`, `budget_*`, `alert_thresholds`, `is_default`, `is_active` |
| **CategoryGroup** | `id`, `user_id`, `name`, `icon`, `color`, `sort_order`, optional group budget fields |
| **Attachment** | `id`, `user_id`, `storage_bucket`, `storage_path`, `file_name`, `content_type`, `size_bytes`, linked entity fields, `is_sensitive`, `export_policy` |
| **InvestmentHolding** | `id`, `user_id`, `symbol`, `asset_class`, `quantity`, `average_cost`, `current_price`, `currency`, `market_value`, `target_allocation_percent` |
| **LineLink** | `id`, `user_id`, `line_user_id`, `refresh_token`, `display_name`, timestamps |
| **LinePairing** | `line_user_id`, `code`, `expires_at`, `created_at` |

**Backend rules:** migrations in `supabase/migrations/` (never edit existing — create new); RLS on every table; never expose service-role client-side; `seed.sql` dev/demo only; push via `supabase link --project-ref <ref>` then `supabase db push`.

**Always ship backend changes:** after editing an Edge Function, `supabase functions deploy <name>` (`--no-verify-jwt` for `aiko-chat`). After a migration, `supabase db push`.

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

Route rules: don't duplicate an existing feature screen; sticky bottom actions for filter/save/confirm/result screens; sample data realistic + scoped to preview/offline; real repositories remain the persisted source; Aiko guidance after the primary number/decision (except onboarding/chat); every supplemental route renders without a Supabase session.

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
dart run build_runner build        # required after Brick model changes
dart format --set-exit-if-changed .
flutter analyze
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

- **New feature module:** create `lib/features/<name>/` (4 layers); add routes; new table → migration with RLS by `auth.uid()`; offline → Brick model + `build_runner`; register app-wide providers; add model/repository-fallback/provider tests; use `Money`.
- **New calculator:** add file in `lib/features/calculators/`, register in the hub category list, and add persistence/conversion only when the product flow exists.
- **New generated insight surface:** add the product screen first, then define the generator, persistence model/table, provider, display states, source-data references, RLS, and tests.
- **New migration:** `supabase migration new <name>`, edit SQL, `supabase db push`.

## Key Principles

1. Clarity first. 2. Data first, Aiko enhanced. 3. Decimal-safe money (never `double`). 4. Privacy by design (RLS everywhere, encrypted storage, AI acknowledged at onboarding). 5. Offline first. 6. Actionable insights. 7. Warm, non-judgmental tone. 8. Test before ship.

## Contributing

Use `Money` (never `double`); go through repositories (screens never touch Supabase/Brick/SQLite); add Brick models + regenerate adapters for offline; add RLS to every new table; consume shared widgets/tokens; write unit tests for new models/providers; run the QA checklist + all quality gates; keep Aiko's voice warm and non-judgmental.

**License:** Private; not published to pub.dev. See `pubspec.yaml`.

## Task plan

See [`TASKS.md`](./TASKS.md) for the prioritized, phased list. Phase 0 is small/low-risk (data-loss / security); Phases 1–7 grow in scope. Don't skip phases.
