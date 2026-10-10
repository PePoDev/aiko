# Features

What each feature module does, where to find it, and how it behaves today. Modules live in `lib/features/<name>/`, layered as `domain/`, `data/`, `application/` and `presentation/` (a module only has the layers it needs). Formulas are in [Calculations](calculations.md); persisted fields are in [Data model](data-model.md).

| Module | Entry point | Summary |
| --- | --- | --- |
| [auth](#auth) | `/`, `/auth` | Welcome carousel, email/password and Google sign-in |
| [dashboard](#dashboard-overview) | `/home` tab | Fixed Overview panels, notifications, quick add |
| [accounts](#accounts-and-goals) | `/accounts` tab | Accounts of 10 types, including goal accounts |
| [categories](#categories-and-budgets) | `/categories` tab | 81 default and custom categories, groups, per-category budgets |
| [transactions](#transactions) | `/transactions` tab | List, search, form, rules, attachments, recurring, reminders |
| [transaction_capture](#auto-capture-android) | Transaction rules → Auto-capture | Android SMS and notification capture |
| [aiko_assistant](#ask-aiko) | `/aiko` tab | Streaming AI chat over your own data |
| [aiko_character](#aiko-character) | Used by other screens | Rive character with PNG fallback |
| [overview](#reports-and-planning) | Detail routes | Notifications, Chance of Success, Monthly report, allocation, holding detail |
| [investments](#investments) | Settings → Investments | Holdings, allocation, rebalance alerts, live prices |
| [calculators](#calculators) | Settings → Calculators | Calculator library |
| [learning_hub](#learning-hub) | Settings → Learning Hub | Lessons, quizzes, inline glossary |
| [export](#export) | Settings → Export | CSV and HTML statement export |
| [travel_mode](#travel-mode) | Transactions app bar | Trip budget, exchange rate, foreign fees |
| [settings](#settings-and-profile) | Overview → Settings, Aiko → Profile | Preferences, profile, LINE, account deletion |
| [onboarding](#onboarding) | Startup | Seeds default accounts in local-only mode |

## Auth

`lib/features/auth/`

- **Welcome** (`/`): three-slide carousel ("Track it all in one place", "Insights that make sense", "Reach your goals"); Skip and Get started open `/auth`.
- **Login** (`/auth`): email/password sign-in and sign-up, "Forgot password?" (Firebase reset email), "Continue with Google". Google uses a pop-up on the web and `google_sign_in` on mobile.
- After any sign-in, `AuthRepository._finish` creates missing defaults, claims anonymous local data and marks the device as known ([Architecture](architecture.md#sign-in-and-anonymous-data)).
- In local-only builds these screens are skipped; the app opens on `/home`.

## Dashboard (Overview)

`lib/features/dashboard/`, screen `HomeDashboardScreen`. The panel set and order are fixed in `_homeWidgets` and are not user-customizable:

1. **Daily spending**: today's expenses against a daily safe amount (weekly safe-to-spend ÷ 7), with Aiko's comfortable, caution or exceeded reaction ([Calculations](calculations.md#daily-spending-reaction)).
2. **Daily summary**
3. **Net earnings**
4. **Category budgets**
5. **Spending calendar**
6. **Cash flow mapping**

The app bar opens **Notifications** (`/notifications`) and **Settings** (`/settings`). The floating **+** button (sidebar **New transaction** on wide screens) opens the transaction form. On wide screens the panels sit in two columns ([Web and mobile](design-system.md#web-and-mobile)). Notifications are computed live from your data (budget thresholds, upcoming bills, goal milestones); there is no notifications collection.

## Accounts and goals

`lib/features/accounts/`

- Types: cash, bank, e-wallet, credit card, loan, investment, asset, liability, goal, other. Each type has its own detail form (`account_form/`), validated by `AccountValidator`.
- Credit cards can **share another card's limit**. Deleting the parent card turns sharing off on its children.
- The **Account summary** splits assets and liabilities. Each account's detail sheet shows type details and related transactions.
- **Goals** are accounts with `type = goal`: target amount, target date and priority; `currentBalance` is the saved amount. Chance of Success and the forecast read the same record.
- Balances move with transactions and are reconciled from them on load ([Calculations](calculations.md#account-balances)).

## Categories and budgets

`lib/features/categories/`

- 81 default categories in 13 groups, cloned per user at sign-in, plus custom categories. Custom categories are archived rather than deleted. Default clones can't be renamed or deleted, but their budgets are editable.
- Each category can own one **budget**: amount, period (daily/weekly/monthly/yearly), rollover, alert thresholds (default 50/75/90/100%). Groups can carry a group budget.
- Category groups are user-editable; deleting a custom group moves its categories to "Ungrouped". Default groups can't be deleted.
- `CategoryBudgetProgressService` computes spend against the budget for the current period and a warm recommendation ("Keep this category under 120 THB/day to stay on track.").

## Transactions

`lib/features/transactions/`

- **List** (`TransactionListScreen`): month ranges (`TransactionMonthRangeService`), search, recurring previews (`RecurringProjection`). App bar buttons open Search, Rules and Travel Mode; tapping the month summary card opens the Monthly report.
- **Form** (`TransactionFormScreen`, pushed): amount-first entry; all 15 types; transfers create a `transferOut` and a `transferIn` leg; category, merchant, note, tags; recurring schedules (once/daily/weekly/monthly/annually with an end date or occurrence cap); reminder time; attachments.
  - **Currency conversion**: when the amount's currency differs from the account's, `ExchangeRateService` fetches a rate from `open.er-api.com` (no key, falls back to a manual rate).
  - **Receipt OCR**: `ReceiptOcrService` sends the image to the `ocrScanner` function and parses the text into a draft.
  - **Voice entry**: a "Voice Entry Assistant" dialog takes a sentence in English or Thai ("spent 25 at Amazon yesterday", "ซื้อกาแฟ 65 บาท ที่ร้านสตาร์บัคส์ เมื่อวาน"); `VoiceTransactionParser` turns it into a draft. There is no speech-recognition plugin, so dictation relies on the keyboard's microphone.
- **Rules** (`TransactionRulesScreen`): match on merchant, keyword, amount, account, category or type with contains/equals/starts with/ends with. Rules apply in ascending priority: the first match sets the category, and every match adds its tags. Rules are stored as a synced preference.
- **Attachments**: up to 10 MiB each; image, PDF and text previews in-app; HEIC and Word show a fallback. Bytes are cached on the device first and upload when possible.
- **Reminders**: `TransactionReminderService` schedules local notifications on Android/iOS. Repeating reminders follow the recurring cadence. The web stores the reminder time only.

## Auto-capture (Android)

`lib/features/transaction_capture/`, screen `/transaction-capture` (from Transaction rules).

Opt-in. With SMS and/or notification access granted, incoming bank messages are written to an on-device inbox. On app start and resume, `CapturedMessageProcessor` parses each message (`BankMessageParser`, English and Thai keywords), runs it through your rules, and creates a transaction on the chosen capture account. iOS and the web have no equivalent.

## Ask Aiko

`lib/features/aiko_assistant/`, the `/aiko` tab.

- Streams answers from the `aikoChat` function ([Backend](backend.md#aikochat)). Each request carries an on-device financial snapshot; the server can also run read-only tools over your data.
- Prompt suggestions show on an empty chat; replies render lightweight Markdown (`AikoMarkdownText`), and the trailing disclaimer is shown separately.
- Errors are explicit and retryable where it makes sense: expired sign-in, rate limit ("Slow down a bit"), provider down.
- Requires Firebase. In local-only builds the chat replies "Connect to Aiko cloud to chat."
- The Profile button in the app bar opens `/profile`.

## Aiko character

`lib/features/aiko_character/`. `AikoCharacter` plays `aiko.riv` from `assets/rive/` (artboard `Aiko`, state machine `AikoState`, view model `mood`/`active`/`motionEnabled`) and respects reduced motion. Until the Rive runtime is ready it shows the matching PNG from `assets/images/aiko/` (welcome, thinking, happy, warning, celebrating, encouraging). `AikoRiveRuntime` (`application/aiko_rive_runtime.dart`) starts Rive in the background and only when `aiko.riv` is bundled; on the web that is a WebAssembly download from a CDN, so startup never waits on it and a failed download keeps the PNGs. `AikoAvatar` renders the SVG mark.

## Reports and planning

`lib/features/overview/` (screens in `finance_detail_screens.dart`, services in `application/`):

| Screen | Route | Shows |
| --- | --- | --- |
| Notifications | `/notifications` | Budget, bill and goal notifications |
| Chance of Success | `/settings/chance-of-success` | Monte Carlo probability for each goal (or the goal passed in) |
| Monthly report | `/reports/monthly` (Transactions month card) | This month's income, spending and category breakdown |
| Asset Allocation | `/portfolio/allocation` | Allocation by asset class |
| Holding Detail | `/portfolio/holding` | One holding's performance |

Services: `BudgetInsightsService` (safe-to-spend), `CashFlowService` (overview and Sankey), `GoalForecastService` (Monte Carlo), `MonthlyReportService`.

## Investments

`lib/features/investments/`, `/portfolio`.

Add, search and remove holdings (asset class, symbol, quantity, average cost, current price). The summary shows value, total gain/loss, holding count and allocation status. `AllocationService` computes allocation, drift-based **rebalance alerts** (against fixed targets of Stocks 70% / Bonds 30% defined in `InvestmentsScreen`) and **capital-gains estimates** (`capitalGainsOnSale`, tested but not shown in the UI yet). "Refresh prices" calls `marketFeed` for each holding; failures keep the old price.

## Calculators

`lib/features/calculators/`, `/calculators`.

The library lists 30 calculators by category and searches by name in either language; each has a stable English id (`_CalculatorItem.id`) that picks its form in `calculatorForm` (`calculator_forms.dart`). `CalculatorDetailScreen` renders any form: number fields (money fields show the currency symbol), choices that show or hide fields (for example *Solve for* in Time value of money), hints under fields, and a result with a headline value, supporting rows and a short explanation. Fields start with Thai-scale example values, so Calculate works straight away.

| Group | Calculators |
| --- | --- |
| Saving and investing | Compound interest, Savings goal, ROI, Time value of money (future value, present value or monthly saving), IRR / NPV, Fixed deposit (simple interest, 15% withholding tax), Bond yield (yield from price or price from yield), Tax equivalent yield, Rule of 72 |
| Debt and cars | Loan, Credit card payoff, Car hire purchase vs. lease (Thai flat-rate hire purchase, its effective rate, and the net cost against leasing) |
| Home and property | Bi-weekly mortgage, Refinance savings (with break-even month), Rent vs. buy, Home affordability (debt-to-income limit, 40–50% at Thai banks), Rental property cash flow (cap rate, gross yield) |
| Retirement | Tax-saving funds (RMF or Thai ESG against the same saving without the deduction), Retirement drawdown (how long savings last, with inflation), Social Security pension (Section 33), Annuity payout |
| Business and markets | WACC, Black-Scholes options, CAPM |
| Tax and income | Income tax and take-home pay, Capital gains tax, Salary to hourly |
| Everyday | Currency converter, Inflation, Tip and percentage |

The calculators built on Thai rules (income tax, capital gains tax, tax-saving funds, Social Security pension) always work in baht; the others use the profile's base currency. Their rules are in `thai_tax_rules.dart` ([Calculations](calculations.md#calculators)). Calculations use `double`; results are estimates, not stored money. Scenarios aren't saved.

## Learning Hub

`lib/features/learning_hub/`, `/learning-hub`. Four lessons (budgeting without guilt, emergency fund starter plan, credit utilization basics, rebalancing your portfolio) with quizzes. Definitions appear inline through `InlineGlossaryText` tooltips. By project rule, there is no standalone glossary section.

## Export

`lib/features/export/`, `/export`. Pick a range (this month, last month, all time) and a format:

- **CSV** and **Excel**: a UTF-8 CSV (Date, Merchant, Category, Type, Amount, Note) shared via the share sheet or downloaded on the web. Excel gets a byte-order mark so Thai opens correctly.
- **PDF**: an HTML statement with income, expense and net totals, shared as `aiko_statement_<timestamp>.html` for printing to PDF.

Headers, transaction types, category names and the statement text use the app language; uncategorized rows say so (in that language). Merchant and category text is HTML-escaped in the statement.

## Travel Mode

`lib/features/travel_mode/`, `/travel-mode` (Transactions app bar). Create a trip (name, home and local currency, budget), refresh the exchange rate from `open.er-api.com` or set it manually, convert amounts, and log foreign fees. The trip is stored as the synced preference `travel_mode_v1`. "Reset Travel Mode" ends the trip.

## Settings and profile

`lib/features/settings/`

- **Settings** (`/settings`, from the Overview app bar): Appearance (system/light/dark), Language (system/English/Thai; the whole app, built-in category names, exports and Ask Aiko follow it — [Localization](localization.md)), and the tools list from `aikoNavigationItems`: Chance of Success, Investments, Asset Allocation, Holding Detail, Learning Hub, Calculators, Export. Local-only builds show a "Local-only mode" notice.
- **Profile** (`/profile`, from the Aiko tab): personal information, avatar (camera or gallery, uploaded to Storage), user ID, connected apps (Google link, LINE), change password, log out, and **Delete account** (Danger Zone).
- **Connect LINE** (`/connect-line`): enter the 6-character code the LINE bot sends ([Backend](backend.md#line)).

## Onboarding

`lib/features/onboarding/application/complete_onboarding.dart`. There is no onboarding UI. In local-only mode, startup seeds a **Cash** and a **Bank Account** in the profile's base currency, skipping any that already exist by name and type. Signed-in users get defaults from `ensureProfileAndDefaultsExist` instead.

## Known gaps

Current behavior that differs from what the UI or the README suggests. Fix the code, then update this list.

| Area | Gap |
| --- | --- |
| Split transactions | `TransactionSplit` and its validation exist, but no screen creates splits and the codec does not persist them. |
| Duplicate transactions | No duplicate detection. `TransactionRepository.duplicate` copies a transaction but nothing calls it. |
| Budget rollover | `rolloverUnused` / `budget_rollover` is stored and editable, but no budget, notification or safe-to-spend calculation applies it. |
| Change password | The Profile row only shows a "Password flow opened." snackbar. Password reset works from Login ("Forgot password?"). |
| Account deletion | Requires a sign-in within 5 minutes; older sessions get a generic "Unable to delete account right now." with no prompt to sign in again. |
| App lock | `SecurityStatus` has `pinEnabled`/`biometricEnabled` and matching strings, but no PIN or biometric lock is implemented. |
| Aiko character | `aiko.riv` is not in `assets/rive/` yet; the PNG fallback is always used until it is added. |
| Ask Aiko offline | No on-device answers; local-only builds cannot chat. |
| Multi-currency totals | Dashboard net worth and cash add raw amounts across currencies under the first currency found; transactions in a currency other than their account's don't change its balance. |
| AI net worth | `aiko_account_summary` negates `loan`/`liability`/`creditCard` balances, but the app already stores debts as negative balances, so Ask Aiko can overstate net worth. |
| Travel Mode rate | Starts at 1.0 until refreshed or set manually. |
| Rebalance targets | Fixed at Stocks 70% / Bonds 30%; the stored `target_allocation_percent` has no input. |
| Reminders | Repeating native reminders ignore the series end date and occurrence cap. |
| "PDF" export | Produces an HTML statement, not a PDF file. |
