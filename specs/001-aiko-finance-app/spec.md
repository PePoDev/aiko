# Feature Specification: Aiko Personal Finance App

**Feature Branch**: `001-aiko-finance-app`

**Created**: 2026-05-18

**Status**: Draft

**Input**: User description: "Build Aiko, a blue-themed AI-powered personal finance management mobile app with a cute anime-style AI girl assistant, covering money tracking, budgeting, goals, insights, reports, calculators, privacy, and a focused MVP path."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Start Securely With Aiko (Priority: P1)

A new user can create an account, meet Aiko, choose their financial focus, set base currency and country, add a first financial account, and enable app security so they can safely begin tracking money.

**Why this priority**: The app cannot deliver financial value until users trust the experience, complete onboarding, and create the first account that anchors all later activity.

**Independent Test**: Can be fully tested by completing onboarding from a fresh install through first account creation and verifying that the user lands on a personalized home dashboard with security enabled or explicitly skipped.

**Acceptance Scenarios**:

1. **Given** a first-time user, **When** they open Aiko, **Then** they see Aiko branding, a clear value proposition, and a guided onboarding path.
2. **Given** a user in onboarding, **When** they choose their financial focus and base currency, **Then** those preferences are saved and reflected in later screens.
3. **Given** a user has added a first account, **When** onboarding completes, **Then** the home dashboard shows the account balance, Aiko welcome message, and next best action.
4. **Given** a user reaches security setup, **When** they enable PIN or biometric lock, **Then** protected financial screens require the selected lock before access.

---

### User Story 2 - Track Everyday Money Movement (Priority: P1)

An everyday budgeter can manually add, edit, classify, search, and review income, expenses, transfers, refunds, and finance-related transactions with categories, accounts, notes, tags, merchants, and optional attachments.

**Why this priority**: Accurate transaction data is the foundation for budgets, insights, reports, pace, leftover, goals, and Aiko recommendations.

**Independent Test**: Can be fully tested by creating accounts and categories, entering multiple transaction types, editing one transaction, filtering the list, and confirming totals update across transaction and dashboard views.

**Acceptance Scenarios**:

1. **Given** a user with at least one account, **When** they add an expense with amount, date, account, category, and merchant, **Then** the transaction appears in the list and the account balance updates.
2. **Given** a user has repeated a prior purchase, **When** they use duplicate or smart defaults, **Then** the new transaction pre-fills relevant fields and can be saved with minimal input.
3. **Given** transactions exist across categories and dates, **When** the user searches or filters by category, account, merchant, tag, type, or date, **Then** only matching transactions are shown and totals reflect the filtered set.
4. **Given** a transaction is split across categories, **When** the user saves the split, **Then** category totals reflect each split amount while the account balance reflects the full transaction amount once.

---

### User Story 3 - Understand Today Through The Home Dashboard (Priority: P1)

A user can open Home and immediately understand net worth, cash available, monthly spending, budget status, pace, leftover or safe-to-spend amount, upcoming bills, goal progress, recent transactions, and Aiko's most useful suggestion.

**Why this priority**: The dashboard is the daily control center and must turn financial data into simple, calm, actionable guidance.

**Independent Test**: Can be fully tested by loading a user with accounts, transactions, budgets, goals, and bills, then verifying each dashboard widget displays the correct status and provides a path to the relevant detail screen.

**Acceptance Scenarios**:

1. **Given** a user has income, bills, budgets, goals, and spending this month, **When** they open Home, **Then** they see safe-to-spend, pace, budget progress, goal progress, and Aiko's summary for the current period.
2. **Given** a user is approaching a budget threshold, **When** they open Home, **Then** Aiko shows a supportive warning with a suggested daily limit or adjustment.
3. **Given** a user has no transactions yet, **When** they open Home, **Then** they see an empty state that explains the next action and offers quick add.
4. **Given** a user customizes dashboard widgets, **When** they hide, show, or reorder widgets, **Then** the dashboard reflects the selected layout on future visits.

---

### User Story 4 - Plan Budgets, Goals, And Savings (Priority: P2)

A user can create monthly budgets, financial goals, saving plans, and alerts, then use pace, leftover, and Aiko recommendations to stay on track without feeling judged.

**Why this priority**: Planning features convert transaction tracking into behavior change, savings growth, and measurable financial progress.

**Independent Test**: Can be fully tested by creating category budgets and a savings goal, adding spending and contributions, and verifying progress, warnings, forecasts, and recommendations update.

**Acceptance Scenarios**:

1. **Given** a user has spending categories, **When** they create monthly category budgets, **Then** budget cards show used amount, remaining amount, percent used, and threshold status.
2. **Given** a user creates a goal with target amount and target date, **When** the goal is saved, **Then** Aiko shows the required contribution, current progress, and forecasted completion status.
3. **Given** a user is spending faster than expected, **When** pace is calculated, **Then** Aiko explains the risk and suggests a daily spending limit to stay within budget.
4. **Given** income, fixed bills, debt payments, goal contributions, and current spending exist, **When** leftover is calculated, **Then** the user sees a safe-to-spend amount for the selected period.

---

### User Story 5 - Review Insights, Reports, And Exports (Priority: P2)

A user can review spending insights, monthly reports, Aiko Review, and exportable data so they understand patterns and can keep records outside the app.

**Why this priority**: Insights and reporting are central to the product promise of clarity and better decisions, and exports support user ownership of financial data.

**Independent Test**: Can be fully tested by adding representative transactions and budgets, generating the monthly review, viewing charts, and exporting filtered transactions or a report.

**Acceptance Scenarios**:

1. **Given** a user has at least one month of transactions, **When** they open Insights, **Then** they see category trends, income versus expense, spending changes, and Aiko insights.
2. **Given** a monthly period has ended or enough data exists, **When** the user opens Aiko Review, **Then** they see budget performance, goal progress, cash flow summary, and action items for next month.
3. **Given** a user requests an export, **When** they choose a supported format and scope, **Then** the export includes the selected data and clearly indicates the date range and filters.
4. **Given** an insight references sensitive financial behavior, **When** the user expands it, **Then** the app shows why the suggestion appeared and which data category supported it.

---

### User Story 6 - Use Aiko And Calculators For Decisions (Priority: P3)

A user can ask Aiko natural-language finance questions, receive explainable guidance, run core calculators, save scenarios, and convert results into budgets, goals, loan plans, or investment scenarios.

**Why this priority**: Aiko and calculators differentiate the product, but they depend on core financial data and planning features to be most useful.

**Independent Test**: Can be fully tested by asking Aiko common finance questions, running each MVP calculator, saving a result, and converting one result into an actionable plan.

**Acceptance Scenarios**:

1. **Given** a user asks how much they can safely spend this week, **When** sufficient income, bill, budget, and spending data exists, **Then** Aiko answers with a safe-to-spend amount, explanation, and relevant disclaimer.
2. **Given** a user asks a question that requires unavailable data, **When** Aiko cannot calculate a reliable answer, **Then** Aiko explains what data is missing and offers a next step.
3. **Given** a user opens the calculator library, **When** they search or browse categories, **Then** they can find compound interest, loan, credit card payoff, savings goal, ROI, and currency conversion calculators.
4. **Given** a calculator result is saved, **When** the user chooses to convert it, **Then** the app creates a draft goal, budget, debt plan, or scenario for review before saving.

### Edge Cases

- A user has no accounts, transactions, budgets, or goals yet.
- A user records transactions in a currency different from their base currency.
- A transaction amount is zero, negative where not allowed, unusually large, or duplicates an existing transaction.
- A budget has no linked category, an archived category, or spending that already exceeds the limit.
- A goal target date has passed, target amount is already reached, or required contribution is impossible within current leftover.
- Account balances become negative, stale, hidden, archived, or inconsistent after edits.
- A recurring bill or subscription falls on a weekend, holiday, leap day, or missing calendar day.
- Aiko cannot produce a confident recommendation because data is insufficient, contradictory, outdated, or user consent is disabled.
- Export contains sensitive data and must be clearly scoped before the user confirms.
- App access is attempted after session timeout, device change, or failed lock attempts.
- Accessibility settings increase text size or screen reader mode is enabled.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The product MUST present Aiko as the app name and in-app AI financial companion with blue-centered branding, friendly finance-focused tone, and optional character visibility controls.
- **FR-002**: The product MUST support light and dark themes that preserve readable financial data, accessible contrast, and blue primary actions.
- **FR-003**: Users MUST be able to sign up, sign in, sign out, manage their profile, select base currency and country, and delete or export their data.
- **FR-004**: Users MUST be able to protect the app with PIN and supported device biometric lock, including session timeout and recovery behavior.
- **FR-005**: Onboarding MUST introduce Aiko, collect financial focus, base currency, country, first account, category template, first budget or goal, AI consent, and security preference.
- **FR-006**: Users MUST be able to create and manage manual accounts for cash, bank, e-wallet, credit card, loan, investment, asset, and other tracked balances.
- **FR-007**: Users MUST be able to create, edit, delete, split, duplicate, search, filter, and classify transactions across income, expense, transfer, refund, investment, dividend, interest, loan payment, credit card payment, tax payment, fee, and adjustment types.
- **FR-008**: Transaction entry MUST be amount-first and support date, account, category, note, tags, merchant, location when available, receipt or document attachment when enabled, and recurrence when enabled.
- **FR-009**: Users MUST be able to manage categories and subcategories with names, groups, icons, colors, budget links, archive behavior, merge behavior, and type restrictions.
- **FR-010**: Users MUST be able to create transaction rules based on merchant, keyword, amount, account, or other transaction attributes, preview their impact, set priority, and bulk-apply them to past transactions.
- **FR-011**: Users MUST be able to create monthly category budgets for the first release, with later support for weekly, yearly, custom-period, rollover, envelope, zero-based, shared, and template-based budgets.
- **FR-012**: Budgets MUST show used amount, remaining amount, percentage used, period status, threshold alerts at configurable levels, and Aiko recommendations based on past behavior.
- **FR-013**: Users MUST be able to create financial goals with name, purpose, target amount, target date, linked account, priority, current amount, required contribution, progress forecast, and Aiko coaching.
- **FR-014**: The product MUST provide saving plans that break goals into weekly or monthly contribution targets, milestones, forecasted completion dates, and progress messages.
- **FR-015**: The product MUST calculate spending pace for the current period and show whether spending is faster, slower, or on track compared with budget and historical behavior.
- **FR-016**: The product MUST calculate leftover or safe-to-spend using income, fixed bills, required expenses, debt payments, goal contributions, and current spending.
- **FR-017**: The Home dashboard MUST include Aiko welcome, net worth, total cash, monthly spending, monthly income, budget status, pace, leftover, upcoming bills, credit card due dates, goal progress, Aiko suggestions, recent transactions, quick add, and calculator shortcuts where data exists.
- **FR-018**: Users MUST be able to customize the dashboard by showing, hiding, reordering, and selecting compact or expanded widgets.
- **FR-019**: The product MUST provide bottom navigation for Home, Transactions, Budget, Insights, and Aiko, with additional finance modules accessible through a More or Settings area.
- **FR-020**: The product MUST provide spending charts, income versus expense charts, budget progress, goal progress, net worth trend, and first-release monthly reports.
- **FR-021**: Aiko Insights MUST provide descriptive, diagnostic, predictive, and prescriptive recommendations with title, explanation, recommendation, confidence indicator, source data summary, dismiss action, and feedback action.
- **FR-022**: Aiko Review MUST summarize a selected month with budget performance, goal progress, spending habits, cash flow, net worth change when available, debt progress when available, and next-month action items.
- **FR-023**: Ask Aiko MUST answer user questions about their own finances only when the user has granted AI consent and relevant data exists; otherwise it MUST explain limitations and ask for the missing data or permission.
- **FR-024**: The product MUST include clear financial, investment, tax, and AI disclaimers wherever estimates or guidance could be mistaken for certified advice.
- **FR-025**: The calculator library MUST include compound interest, loan, credit card payoff, savings goal, ROI, and currency conversion calculators in the first release.
- **FR-026**: Calculator results MUST be saveable as scenarios and convertible into draft goals, budgets, debt plans, or investment scenarios for user review.
- **FR-027**: Users MUST be able to export transactions and reports in first-release supported formats, including at minimum CSV for transactions.
- **FR-028**: The product MUST support bill and subscription tracking as a near-term extension, including renewal dates, reminders, annualized cost, and cancellation suggestions.
- **FR-029**: The product MUST support credit card management as a later module, including balances, due dates, limits, utilization, rewards, APR, reminders, and payoff recommendations.
- **FR-030**: The product MUST support debt, loan, portfolio, asset allocation, net worth, tax, accounting, travel, multi-device sync, and estate planning as planned modules without blocking the first-release MVP.
- **FR-031**: User-facing behavior MUST define loading, empty, error, offline, permission-denied, and success states for all primary screens.
- **FR-032**: User-facing behavior MUST define accessibility expectations for labels, focus order, touch targets, contrast, screen reader support, and dynamic text.
- **FR-033**: Performance-sensitive behavior MUST define user-facing response expectations for dashboard, transaction list, calculator input, quick add, scrolling, and chart interactions.
- **FR-034**: The product MUST protect sensitive financial data with clear privacy controls, AI consent settings, protected stored data, remote sign-out, device management, and a no-selling-personal-financial-data policy.
- **FR-035**: Notifications MUST support bill due, credit card due, budget threshold, goal milestone, low balance, unusual spending, subscription renewal, tax deadline, portfolio drift, and Aiko Review ready alerts as their source modules become available.

### Key Entities *(include if feature involves data)*

- **User**: Person using Aiko; includes profile, base currency, country, timezone, theme, AI consent, security preferences, and app settings.
- **Account**: Financial container such as cash, bank, credit card, loan, investment, e-wallet, asset, or liability account; relates to transactions and balances.
- **Transaction**: A money movement or adjustment with type, amount, date, account, category, merchant, notes, tags, attachments, recurrence, and tax flag.
- **Category**: User-visible classification for transactions, including hierarchy, group, icon, color, type, budget eligibility, archive status, and rule links.
- **Transaction Rule**: Automation rule that applies category, account, tag, recurring, or split treatment based on transaction conditions and priority.
- **Budget**: Planned spending or allocation for a category, account, or period, with amount, threshold alerts, rollover status when available, and progress.
- **Goal**: Financial target such as emergency fund, debt payoff, investment, vacation, education, home, car, wedding, retirement, or custom purpose.
- **Saving Plan**: Contribution schedule and milestones linked to a goal, including required contribution and forecasted completion.
- **Bill or Subscription**: Recurring payment obligation with merchant, amount, billing cycle, next due date, category, reminder, and cancellation status.
- **Credit Card**: Account extension for limits, statement balance, due date, APR, utilization, rewards, annual fee, and payoff status.
- **Asset**: Owned value item such as cash, deposit, investment, real estate, commodity, vehicle, business asset, collectible, or other asset.
- **Liability**: Debt obligation such as loan, credit card balance, mortgage, or other payable, including balance, rate, due date, and payment schedule.
- **Investment Holding**: Portfolio item with symbol or name, asset class, quantity, cost, current value, gains or losses, dividends, and fees.
- **Tax Record**: Tax-related income, deduction, capital gain, document, or estimate for a selected tax year.
- **Saved Calculator Scenario**: Saved calculator inputs, outputs, notes, date, and optional link to a goal, budget, loan plan, or investment scenario.
- **Aiko Insight**: AI or rule-generated recommendation with type, title, explanation, recommendation, confidence, source data summary, feedback, and dismissal status.
- **Report**: Generated financial summary for a selected scope, period, and format, including monthly reports and Aiko Review.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: At least 80% of first-time users can complete onboarding, create a first account, and reach Home in under 5 minutes during usability testing.
- **SC-002**: At least 90% of users can add a basic expense transaction in under 30 seconds after onboarding.
- **SC-003**: At least 90% of transaction searches or filters return the expected visible results in under 2 seconds for users with up to 10,000 transactions.
- **SC-004**: At least 85% of users can understand their safe-to-spend amount, budget status, and next recommended action from Home without opening another screen.
- **SC-005**: At least 80% of users can create a monthly budget and a savings goal without help after entering their first transactions.
- **SC-006**: Budget threshold alerts and pace warnings are shown before or at the configured threshold in 99% of eligible cases.
- **SC-007**: Aiko Insights include a source explanation and user feedback or dismiss option in 100% of generated recommendations.
- **SC-008**: Monthly Aiko Review can be generated for a month with transaction data in under 10 seconds from the user's perspective.
- **SC-009**: Users can export selected transactions to CSV with correct date range, currency, amount, account, category, merchant, and notes in 100% of tested export scenarios.
- **SC-010**: The six first-release calculators produce results matching independently verified sample cases in 100% of calculator acceptance tests.
- **SC-011**: Primary navigation, quick add, dashboard updates, and calculator input complete in under 1 second for 95% of standard test actions, and list or chart scrolling has no visible pause longer than 1 second during standard test data scenarios.
- **SC-012**: 100% of primary flows remain usable with screen reader labels, logical focus order, accessible contrast, and increased text size.
- **SC-013**: 100% of sensitive AI, tax, investment, and financial estimate screens display appropriate disclaimers and consent-dependent behavior.
- **SC-014**: In beta feedback, at least 75% of users describe Aiko's tone as clear, supportive, and non-judgmental.
- **SC-015**: Within 30 days of first use, active users record at least one budget review, goal update, report view, calculator use, or Aiko interaction in at least 60% of accounts.

## Assumptions

- The first release is an MVP centered on onboarding, authentication, security, manual accounts, manual transactions, categories, basic rules, monthly budgets, goals, saving plans, Home dashboard, pace, leftover, spending charts, monthly reports, basic Aiko insights, CSV export, and six core calculators.
- Advanced portfolio analytics, double-entry accounting, advanced tax engine, estate planning, full retirement modeling, full bank sync, automated advisor behavior, and complex simulation are roadmap modules, not blockers for the first releasable app.
- Users may add data manually at first; import, receipt capture, bank connectivity, and automated integrations can be added progressively.
- Aiko's guidance is educational and decision-support oriented; it does not replace certified financial, tax, legal, or investment advice.
- AI features require explicit user consent before using sensitive financial data and must remain explainable, dismissible, and tunable.
- Base currency is required for the first release; multi-currency and travel workflows may start with manual exchange rates before later automated updates.
- The product supports both iOS and Android user expectations, including platform-appropriate security prompts and notification permissions.
- Dashboard widgets use the product's blue design language, with green, orange, red, purple, and teal reserved for semantic status or advanced feature emphasis.
- Users can reduce or hide Aiko character visuals if they prefer a more professional finance interface.
- Free, Premium, and Pro monetization tiers are product packaging goals; first-release access limits can be finalized during planning.
