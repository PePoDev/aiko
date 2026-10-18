# Features

What each feature module does, where to find it, and how it behaves today. Modules live in `lib/features/<name>/`, layered as `domain/`, `data/`, `application/` and `presentation/` (a module only has the layers it needs). Formulas are in [Calculations](calculations.md); persisted fields are in [Data model](data-model.md).

| Module | Entry point | Summary |
| --- | --- | --- |
| [auth](#auth) | `/`, `/auth` | Welcome carousel, email/password and Google sign-in, use without an account |
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
| [learning_hub](#learning-hub) | Settings → Learning Hub | Lessons, quizzes, saved progress, inline glossary |
| [export](#export) | Settings → Export | CSV and HTML statement export |
| [travel_mode](#travel-mode) | Transactions app bar | Trip budget, exchange rate, foreign fees |
| [settings](#settings-and-profile) | Overview → Settings; Profile from Settings, the Aiko tab or the sidebar | Preferences, profile, LINE, account deletion |
| [onboarding](#onboarding) | Startup, sign-up | Seeds default Cash and Bank accounts |

## Auth

`lib/features/auth/`

- **Welcome** (`/`): three-slide carousel ("Track it all in one place", "Insights that make sense", "Reach your goals"); Skip and Get started open `/auth`, and every slide offers **Continue without an account**.
- **Login** (`/auth`): email/password sign-in and sign-up, "Forgot password?" (Firebase reset email), "Continue with Google", and **Continue without an account**. Google uses a pop-up on the web and `google_sign_in` on mobile. Offline, sign-in and sign-up say "You need a connection to sign in. You can keep using Aiko without an account.", and a password reset says it needs a connection.
- **Without an account** (guest, cloud builds): the app opens on `/home` from then on, everything is kept on this device and works offline, and Profile and Settings offer **Sign in to back up and sync**. Ask Aiko, receipt reading and live prices ask the guest to sign in.
- After any sign-in, `AuthRepository._finish` creates missing defaults, moves in what was made on this device without an account (records, budgets on defaults, attachments, rules, lesson progress, dismissals, language and trip) and marks the device as known ([Architecture](architecture.md#guest-mode-and-sign-in)). A guest who signs up keeps their profile and accounts; one who signs in to an existing account leaves their unused Cash and Bank behind. Any other new account (sign-up, or a first Google sign-in) gets the default accounts ([Onboarding](#onboarding)).
- **Log out** (Profile) opens `/auth`, after a warning when changes or files haven't uploaded yet. When the session ends elsewhere (token revoked, account deleted on another device), the app leaves the signed-in screens for `/auth`, or `/` on a device that has never signed in ([Architecture](architecture.md#signing-out-and-switching-users)).
- In local-only builds these screens are skipped; the app opens on `/home`.

## Dashboard (Overview)

`lib/features/dashboard/`, screen `HomeDashboardScreen`. The panel set and order are fixed in `_homeWidgets` and are not user-customizable:

1. **Daily spending**: today's expenses against a daily safe amount (weekly safe-to-spend ÷ 7), with Aiko's reaction: comfortable, caution, exceeded, nothing spent yet, or "log your income" when there is no income this month ([Calculations](calculations.md#daily-spending-reaction)).
2. **Daily summary**: income and expenses per day for the last 7 or 30 days, ending today.
3. **Net earnings**
4. **Category budgets**
5. **Spending calendar**
6. **Cash flow mapping**: a Sankey of this month's income flowing into each budget group's spending (needs, wants, savings, …) plus what's left over; an empty state when there is nothing to map.

Amounts in other currencies are converted with live rates, or offline with the rates saved on the device and a "Rates as of {date}." note; pull to refresh fetches them again. The app bar opens **Notifications** (`/notifications`) and **Settings** (`/settings`). The floating **+** button (sidebar **New transaction** on wide screens) opens the transaction form. On wide screens the panels sit in two columns ([Web and mobile](design-system.md#web-and-mobile)).

**Notifications** are computed live from your data (budget thresholds, upcoming bills, active goals' milestones); there is no notifications collection. Tapping one opens what it's about: Categories for a budget, Accounts for a bill, the goal's account for a goal. The close button dismisses it until the same event comes round in a new period (each id carries its budget period, due date or milestone); dismissals are the synced preference `dismissed_notifications_v2`, one item per notification, so dismissals on two devices merge ([Data model](data-model.md#preferences)).

## Accounts and goals

`lib/features/accounts/`

- Types: cash, bank, e-wallet, credit card, loan, investment, asset, liability, goal, other. Each type has its own detail form (`account_form/`), validated by `AccountValidator`.
- Credit cards can **share another card's limit**. Deleting the parent card turns sharing off on its children. Loans default their next due date to a month from today.
- The **Account summary** shows net worth, assets and liabilities in the base currency, using the same accounts as the Overview ([Calculations](calculations.md#sign-convention-and-the-accounts-summary)). Each account's detail sheet shows type details and its 20 most recent transactions.
- **Goals** are accounts with `type = goal`: target amount, target date and priority; `currentBalance` is the saved amount (the form shows it as "Saved so far"). Chance of Success and the forecast read the same record.
- **Opening balance and balance edits**: a new account's starting balance is saved as a signed `adjustment` transaction, and editing the balance later adds an adjustment for the difference, so neither counts as income or spending. An account's currency can't change once it has transactions.
- **Delete** removes the account and every transaction recorded on it in one write (the confirmation says how many), cancels their reminders and deletes their attachments.
- Balances move with transactions and are reconciled from them on load ([Calculations](calculations.md#account-balances)).

## Categories and budgets

`lib/features/categories/`

- 81 default categories in 13 groups, cloned per user at sign-in, plus custom categories. Custom categories are archived rather than deleted, so transactions that use one still show its name (lists, detail and exports read `allCategoriesProvider`). Default clones can't be renamed or deleted, but their budgets are editable.
- Each category can own one **budget**: amount, period (daily/weekly/monthly/yearly), rollover, alert thresholds (default 50/75/90/100%). Groups can carry a group budget.
- Category groups are user-editable; deleting a custom group moves its categories to "Ungrouped". Default groups can't be deleted.
- `CategoryBudgetProgressService` computes spend against the budget for the current period.

## Transactions

`lib/features/transactions/`

- **List** (`TransactionListScreen`): month ranges (`TransactionMonthRangeService`), search, recurring previews (`RecurringProjection`, each occurrence computed from the series' first date and its day-of-week, day-of-month or month setting). App bar buttons open Search, Rules and Travel Mode. The month card shows income, spending and **Net**, leaving out transfers and adjustments; tapping it opens the Monthly report for that month (`/reports/monthly?month=YYYY-MM`). Day and month totals show two decimals.
- **Form** (`TransactionFormScreen`, pushed): amount-first entry (the amount accepts thousands commas, "1,250.50"); all 15 types; category, merchant, note, tags; recurring schedules (once/daily/weekly/monthly/annually with an end date or occurrence cap); reminder time; attachments. Picking a date or time doesn't turn a reminder on. Save is disabled while a save is running, and a failed save keeps the form open. Closing with unsaved input asks "Discard changes?".
  - **Transfers** are saved as a linked pair, a `transferOut` leg on the source account and a `transferIn` leg on the destination, sharing a `transfer_group_id`. Editing either leg edits the pair, and deleting one deletes both. A cross-currency pair keeps its stored amounts (amount, currency and accounts are locked when editing). Transfers can't be recurring. An existing entry can't switch between transfer and non-transfer. Legs saved before linking are edited and deleted one at a time.
  - **Adjustments** (opening balances and balance corrections) are created and changed from the account form, not here.
  - **Currency conversion**: when the amount's currency differs from the account's, the rate field starts empty, never at 1.00. It takes a live rate from `open.er-api.com` (no key; rates fetched this session are reused for an hour), else the rates saved on the device, crossed through any saved base, with a note giving their date, else it stays empty and required with a note saying why (no connection, or no live rate for the pair). A pair change never keeps the previous pair's rate. **Refresh live rate** always says what happened (updated, offline, using the saved rate, failed), and a failed refresh keeps the rate shown. The field keeps the rate's full precision (the card shows 4 decimals, or 4 significant digits below 1), and the amount is saved in the account's currency rounded to 2 decimals, as the "Saves as ≈" preview shows. While a needed rate is still being fetched, Save says "Getting the exchange rate. Please save again in a moment." A transfer converts each leg into its own account's currency under the same rules, with a second rate for the destination when it differs. Auto-captured bank messages use the capture account's currency.
  - **Receipt OCR**: `ReceiptOcrService` sends the image (base64) to the `ocrScanner` function (45 s timeout) and parses the text into a draft: merchant, total and date. Dates are read day first; a date that isn't plausible is ignored and the form keeps today ([Localization](localization.md#data-entered-in-the-users-language)). Offline it says Aiko couldn't read the receipt, local-only builds say reading receipts needs Aiko cloud, and a guest's photo isn't sent (sign in to have receipts read). The photo is attached either way: it is kept in the device cache (so it survives a web reload), scaled to at most 2560 px and checked against the 10 MB limit.
  - **Voice entry**: a "Voice Entry Assistant" dialog takes a sentence in English or Thai ("spent 25 at Amazon yesterday", "ซื้อกาแฟ 65 บาท ที่ร้านสตาร์บัคส์ เมื่อวาน"); `VoiceTransactionParser` turns it into a draft. The merchant keeps the casing you typed and stops at date words and connectives ("Starbucks for coffee" → Starbucks); a name after "at"/"from" wins over one after "on"/"for". There is no speech-recognition plugin, so dictation relies on the keyboard's microphone.
- **Rules** (`TransactionRulesScreen`): match on merchant, keyword, amount, account, category or type with contains/equals/starts with/ends with. Accounts, categories and types are chosen from pickers; tap a rule to edit it; delete asks first. Rules apply in ascending priority: the first match sets the category, and every match adds its tags. Rules are stored as a synced preference, one item per rule, so rules edited on two devices offline both survive.
- **Delete** (transaction detail) confirms with a red button; deleting a transfer leg deletes its partner too, and the transaction's attachments are deleted with it.
- **Attachments**: up to 10 MiB each; image, PDF and text previews in-app; HEIC and Word show a fallback. Size, type and unreadable-file errors show when you attach. The detail screen lists a transaction's attachments (a transfer's are on its outflow leg), and the edit form shows them and can remove them on Save. Saving never waits for an upload ([Architecture → Files](architecture.md#files)): signed in, a file still waiting shows "Saved on this device. Uploads when you're online.", and one whose upload failed for good "This file couldn't be uploaded. Tap to try again." Opening a file uses the device copy, else downloads it; offline and not on the device it says a connection is needed. If a new attachment can't be kept at Save, a message says so as the form closes ("Saved, but 1 attachment couldn't be kept…").
- **Reminders**: `TransactionReminderService` schedules local notifications on Android/iOS. Repeating reminders follow the recurring cadence: an open-ended series uses one native repeating notification; a series with an end date or occurrence limit books its next 12 occurrences one by one, topped up at each launch, and stops at the bound. Signing out (or the session ending elsewhere) cancels every reminder, and deleting an account cancels its transactions' reminders. A transaction deleted or edited on another device cancels or re-books the reminder booked on this one. The web stores the reminder time only.

## Auto-capture (Android)

`lib/features/transaction_capture/`, screen `/transaction-capture` (from Transaction rules).

Opt-in, on the device only, and needs no network. iOS and the web have no equivalent.

- **Notifications** come through Aiko's own `NotificationListenerService` (`CaptureNotificationListener` in `android/app`), which the system binds once Aiko is turned on under Notification access (**Grant** opens that screen, and the capture screen updates when you come back). It passes only the posting app, the notification's key, title and text to Dart inside Aiko's process; nothing is broadcast, so other apps can't read or fake notifications through Aiko. Aiko's own notifications are skipped. Notifications are captured only while Aiko's process is alive (open or in the background).
- **SMS** reach `CaptureSmsReceiver`, which wraps `another_telephony`'s receiver. It is declared disabled and switched on by `TransactionCaptureService.start()` and off by `stop()` (through `CaptureBridge`), so no SMS wakes Aiko while capture is off. With the app in front the listener gets the SMS; otherwise `captureSmsBackgroundHandler` runs in a background isolate, also when Aiko isn't running, checks that capture is on and only writes the SMS to the inbox. SMS are dated by their service-centre timestamp (ignored when it is in the future or more than a week old), so a late SMS keeps its date.

Only messages `BankMessageParser` recognizes as payments are written to the on-device inbox (`capture_inbox/`, one file per message). `CapturedMessageProcessor` books it on app start and resume, and about 3 s after a message that arrives with the app open: each message is parsed (English and Thai keywords), runs through your rules, and becomes a transaction on the chosen capture account. One run books all its messages in one write with one balance update; if that save fails, they stay queued for the next start or resume. Start and resume share one run. A message is never booked twice: its transaction id is derived from its message id (UUID v5), and a run first marks queued messages that are already booked, so a crash between saving and dequeuing is safe. An SMS and a notification for the same payment (same type and amount within 5 minutes) book once, and so does the same notification updated within 5 minutes or its text posted again as another notification within 1 minute. Beyond that, two alike messages are two payments; two identical SMS stay two transactions. Turning capture on discards anything queued while it was off.

How `BankMessageParser` reads a message:

- OTP and verification-code messages are ignored, even when they quote an amount.
- Dates, times, masked account or card numbers and reference numbers are blanked first, so they are never read as the amount. The amount is the number next to a currency marker (THB, ฿, บาท, USD, …) or a movement keyword, skipping balances; zero is never an amount.
- The direction comes from the income or expense keyword nearest the amount; on a tie, income wins.
- A message that can't be parsed, would book zero or a negative amount, or whose draft is invalid is dropped, so one bad message can't block the ones after it.

## Ask Aiko

`lib/features/aiko_assistant/`, the `/aiko` tab.

- Streams answers from the `aikoChat` function ([Backend](backend.md#aikochat)). Each request carries an on-device financial snapshot; the server can also run read-only tools over your data.
- Prompt suggestions (only questions Aiko can answer from your data) show on an empty chat; replies render lightweight Markdown (`AikoMarkdownText`), and the trailing disclaimer is shown separately. Messages are capped at 300 characters; a counter appears near the limit.
- Errors are explicit: expired sign-in, no access, rate limit ("Slow down a bit"), provider down, offline ("You seem to be offline…"), too slow ("Aiko is taking too long to answer…") and cut off. **Retry** shows only when sending again can help, so not for sign-in, access or local-only errors (`ChatFailure.isRetryable`). A failed reply leaves no empty bubble; an answer that stops early keeps its text, marked "(Answer cut off)", with Retry.
- Time limits (`HttpChatEngine`): 15 s to connect (Android/iOS), 60 s for the function to respond, 45 s between chunks. The function sends its headers at once and a keep-alive every 15 s while it works ([Backend → aikoChat](backend.md#aikochat)).
- The transcript is cleared when the signed-in user changes.
- Requires Firebase and an account. In local-only builds the chat replies "Connect to Aiko cloud to chat."; guests see "Sign in to chat with Aiko. Nothing you ask is sent until you do." with Log In.
- The Profile button in the app bar opens `/profile`.

## Aiko character

`lib/features/aiko_character/`. `AikoCharacter` plays `aiko.riv` from `assets/rive/` (artboard `Aiko`, state machine `AikoState`, view model `mood`/`active`/`motionEnabled`) and respects reduced motion. Until the Rive runtime is ready it shows the matching PNG from `assets/images/aiko/` (welcome, thinking, happy, warning, celebrating, encouraging). `AikoRiveRuntime` (`application/aiko_rive_runtime.dart`) starts Rive in the background and only when `aiko.riv` is bundled; on the web that is a WebAssembly download from a CDN, so startup never waits on it and a failed download keeps the PNGs. If a PNG can't load, `AikoArtFallback` (a drawn circle with an icon, no assets) takes its place. `AikoAvatar` renders the SVG mark.

## Reports and planning

`lib/features/overview/` (screens in `finance_detail_screens.dart`, services in `application/`):

| Screen | Route | Shows |
| --- | --- | --- |
| Notifications | `/notifications` | Budget, bill and goal notifications; tap to open, × to dismiss |
| Chance of Success | `/settings/chance-of-success` | Monte Carlo probability for one active goal, picked from a list (the goal passed in, else the top-priority goal). A goal without a target amount or date, or past its date, shows what's missing instead ([Calculations](calculations.md#chance-of-success-monte-carlo)) |
| Monthly report | `/reports/monthly?month=YYYY-MM` (Transactions month card) | That month's income, spending and category breakdown against the month before (this month without `month`) |
| Asset Allocation | `/portfolio/allocation` | Allocation by asset class in the base currency (holdings in other currencies converted with `fxRatesProvider`). Holdings with no rate are left out and named, for example "BND (USD)"; when all are, the total shows "—" and the chart is hidden |
| Holding Detail | `/portfolio/holding?id=<holding id>` | One holding's performance, with a picker for the others (the largest holding without `id`) |

Services: `CashFlowService` (Sankey), `GoalForecastService` (Monte Carlo), `MonthlyReportService`.

## Investments

`lib/features/investments/`, `/portfolio`.

Holdings have an asset class, symbol, quantity, average cost, current price and their own currency. Add one with the **+** button, tap a card to open its Holding Detail (`/portfolio/holding?id=…`), and edit or remove it from the card's menu. Search filters the list.

The summary shows value, total gain/loss, holding count and allocation status in the base currency: holdings in other currencies are converted with `fxRatesProvider`, and holdings with no rate are left out and their currencies named (`valueHoldingsIn`), and saved rates add "Rates as of {date}."; pull to refresh fetches rates again. `AllocationService` computes allocation, drift-based **rebalance alerts** (against fixed targets of Stocks 70% / Bonds 30% defined in `InvestmentsScreen`) and **capital-gains estimates** (`capitalGainsOnSale`, tested but not shown in the UI yet).

**Refresh prices** needs the cloud backend and an account; guests get "Sign in to refresh live prices" with Log In, and nothing is called. It calls `marketFeed` once per symbol and currency (35 s timeout each), stays under the function's limit of 30 calls a minute (`MarketQuoteLimiter`; the rest wait for a later refresh), saves only prices that changed (unrounded), and reports how many were updated, failed or deferred. A failed quote keeps the old price, and a symbol the provider can't price doesn't stop the others. A connection failure stops the refresh, gives its call back to the budget and says you're offline. After a refresh with at least one quote, the summary shows "Prices last updated {time}." (kept on the device per user).

## Calculators

`lib/features/calculators/`, `/calculators`.

The library lists 30 calculators by category and searches by name in either language; each has a stable English id (`_CalculatorItem.id`) that picks its form in `calculatorForm` (`calculator_forms.dart`). `CalculatorDetailScreen` renders any form: number fields (money fields show the currency symbol), choices that show or hide fields (for example *Solve for* in Time value of money), hints under fields, and a result with a headline value, supporting rows and a short explanation. Fields start with Thai-scale example values, so Calculate works straight away. The result scrolls into view, and it clears when an input changes.

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

`lib/features/learning_hub/`, `/learning-hub`. Four lessons (budgeting without guilt, emergency fund starter plan, credit utilization basics, rebalancing your portfolio), each opening as a lesson page (`LessonScreen`) with a quiz page (`LessonQuizScreen`). Opening a lesson marks it read; answering its whole quiz correctly marks it completed. Progress only moves forward and is stored as the synced preference `learning_progress_v2` (`LessonProgressStore`), one item per level reached, so progress made on two devices merges. Definitions appear inline through `InlineGlossaryText` tooltips. By project rule, there is no standalone glossary section.

## Export

`lib/features/export/`, `/export`. Pick a range (this month, last month, all time) and a format:

- **CSV** and **CSV (opens in Excel)**: a UTF-8 CSV with Date, Merchant, Category, Account, Type, Amount, Currency and Note, shared via the share sheet or downloaded on the web. Amounts are signed: money in (`FinanceTransaction.isInflow`) is positive, money out negative. Text cells that start with `=`, `+`, `-`, `@`, a tab or a carriage return get a leading apostrophe so spreadsheets don't run them as formulas. The Excel variant adds a byte-order mark so Thai opens correctly.
- **HTML statement (print to PDF)**: each transaction in its own currency, with income, expense and net totals per currency, shared as `aiko_statement_<timestamp>.html`. You print it to PDF from the browser or the app it opens in.

Builders live in `export_builder.dart`. Headers, transaction types, category names and the statement text use the app language; uncategorized rows say so (in that language), and deleted custom categories keep their names. Merchant and category text is HTML-escaped in the statement.

## Travel Mode

`lib/features/travel_mode/`, `/travel-mode` (Transactions app bar). Create a trip (name, home and local currency, which must differ, and a budget). The starting rate is a live quote from `open.er-api.com`, else the rates saved on the device, else a built-in reference rate (12 pairs and their inverses); with none of those the sheet asks you to type the rate, and it never assumes 1.0. "Bon voyage" shows only once the trip is saved, with a note when a saved or reference rate was used; a failed save is reported and nothing changes. The rate can be refreshed on demand or typed in a number field (saved when you finish editing). Convert amounts and log foreign fees, each with an optional merchant. The trip is stored as the synced preference `travel_mode_v1`. "Reset Travel Mode" ends the trip.

## Settings and profile

`lib/features/settings/`

- **Settings** (`/settings`, from the Overview app bar): Profile, Appearance (system/light/dark), Language (system/English/Thai; the whole app, built-in category names, exports and Ask Aiko follow it — [Localization](localization.md)), and the tools list from `aikoNavigationItems`: Chance of Success, Investments, Asset Allocation, Holding Detail, Learning Hub, Calculators, Export. Local-only builds show a "Local-only mode" notice; guests get **Sign in to back up and sync**.
- **Profile** (`/profile`, from Settings, the Aiko tab, or the sidebar in every mode): personal information (fields can be cleared), photo (camera or gallery), base currency, and when signed in: email, user ID, connected apps (Google link, LINE), change password, log out and **Delete account** (Danger Zone). Local-only builds show only personal information, photo and base currency; guests also get **Backup & sync** to sign in. Changes, including a new or removed photo, apply on Save, which stores only the fields you changed. A new photo is kept on the device and uploads in the background (other devices show the previous photo until then); a removed photo is cleared at once and deleted from Storage later. Closing with unsaved changes asks first.
  - **Change password** (password accounts only) emails a reset link. Linking Google and the reset email need a connection and say so offline.
  - **Connected apps → LINE** remembers the last status seen on the device and uses it offline; with none known it says "Can't check LINE while offline. Tap to check again." It checks again by itself when the device is back online, and never offers "Connect LINE" while loading or offline.
  - **Log out** opens `/auth`. When changes or files are still waiting to upload, it first asks: they upload the next time this account signs in on this device (**Log out anyway** or Cancel).
  - **Delete account** opens Welcome. It needs a connection ("Deleting your account needs a connection…") and lets queued changes and files upload first; if the last sign-in is older than 5 minutes it says to sign in again first ([Backend](backend.md#deleteaccount)).
- **Connect LINE** (`/connect-line`): enter the 6-character code the LINE bot sends ([Backend](backend.md#line)). Errors name the cause: empty, invalid or expired code, LINE already linked to another user, too many attempts, signed out, offline (15 s timeout).

## Onboarding

`lib/features/onboarding/application/complete_onboarding.dart`. There is no onboarding UI. `completeOnboarding` seeds a **Cash** and a **Bank Account** in the profile's base currency, skipping any that already exist by name and type (in either language). It runs at startup in local-only mode, when someone continues without an account, and after a sign-up or first Google sign-in that brought in no guest records, once per user on each device (`DefaultAccountsSeedMarker`), so default accounts you delete or rename stay that way. Signed-in users' profile and categories come from `ensureProfileAndDefaultsExist` ([Architecture](architecture.md#guest-mode-and-sign-in)).

## Known gaps

Current behavior that differs from what the UI or the README suggests. Fix the code, then update this list.

| Area | Gap |
| --- | --- |
| Split transactions | `TransactionSplit` and its validation exist, but no screen creates splits and the codec does not persist them. |
| Duplicate transactions | No duplicate detection or copy action. |
| App lock | `SecurityStatus` has `pinEnabled`/`biometricEnabled` and matching strings, but no PIN or biometric lock is implemented. |
| Aiko character | `aiko.riv` is not in `assets/rive/` yet; the PNG fallback is always used until it is added. |
| Ask Aiko offline | No on-device answers; local-only builds and guests cannot chat. |
| Web first visit | The web app opens offline only after one online visit, when the service worker caches it ([Architecture → Web offline loading](architecture.md#web-offline-loading)). |
| New device | A signed-in user's data appears on a new device, or after a reinstall, only after one online sync. |
| Local data across tabs | On the web, two tabs used by a guest or a local-only build don't see each other's changes until reloaded. |
| Notification capture | Bank notifications are captured only while Aiko's process is alive; none are queued after Android stops it. |
| Older app versions | Rules, dismissals and lesson progress changed on a version that still writes the `_v1` preferences don't reach versions that write `_v2`, and back, until every device updates. |
| Guest rules after sign-in | When a guest signs in to an existing account, rules that name the guest's unused Cash or Bank account (left behind) never match. |
| Rebalance targets | Fixed at Stocks 70% / Bonds 30%; the stored `target_allocation_percent` has no input. |
| PDF export | No PDF file is generated; you print the HTML statement to PDF yourself. |
| Auto-capture marketing texts | A marketing message that has a movement word and an amount (for example a cashback offer on purchases over a set amount) may still be booked as a transaction. |
| Functions region | Functions deploy to the default region, `us-central1`. `FIREBASE_REGION` only tells the app where to call them, so it must stay `us-central1` ([Backend](backend.md#functions)). |
