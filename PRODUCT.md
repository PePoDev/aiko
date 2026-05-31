---
app_name: Aiko
product_type: AI-powered personal finance management mobile app
brand_character: Aiko, a cute anime-style AI girl with blue hair
primary_brand_color: Blue
platforms:
  - iOS
  - Android
---

# Aiko — Product Design & Reference Specification

## 1. Brand Identity & Visual System
*   **App Name:** Aiko (financial companion avatar: blue-haired, supportive, smart, calm, non-judgmental).
*   **Brand Voice:** Warm, clear, positive reinforcement, solution-oriented (never shame-based).
*   **Primary Color:** Blue (`#3B82F6`) representing trust and stability.
*   **Color System:**
    *   *Primary:* Blue (`#3B82F6` | Deep: `#1D4ED8` | Soft: `#93C5FD` | Pale: `#EFF6FF`).
    *   *Semantic:* Success Green (savings, income), Warning Orange (bills, limits), Danger Red (overspending), Purple (Premium/AI), Teal (analytics, portfolio).
*   **Design Style:** Premium fintech UI combined with a clean, card-based grid layout, modern typography (Outfit/Inter), smooth gradients, and interactive micro-animations.
*   **Character Principle:** *Data first, Aiko enhanced.* The character guides onboarding, dashboard greetings, monthly reviews, and insights without obscuring critical data or charts.

---

## 2. Information Architecture & App Structure
The app uses GoRouter for routing and is structured around a bottom navigation shell with 5 primary tabs:

1.  **Home (`/`)**: Customizable dashboard with widgets (Aiko greeting, Net Worth, Safe-to-Spend, Budget Progress, Recent Transactions).
2.  **Transactions (`/transactions`)**: Unified search, filters, recurring entries, and auto-categorization rules.
3.  **Budget (`/budget`)**: Envelope, zero-based, or 50/30/20 budget periods with alerts and rollover.
4.  **Insights (`/insights`)**: Spending analysis, Sankey cash flow, forecasts, and Aiko monthly reviews.
5.  **Aiko Assistant (`/aiko`)**: Direct chat UI (`/aiko-assistant`), optimization engine (`/aiko-optimize`), and personalized course hub.

### Sub-routes & "More" Menu:
*   `/accounts` - Bank/Cash/Wallet accounts
*   `/credit-cards` - Credit card limit & payment tracking
*   `/bills` - Recurring bills & subscription cancellations
*   `/goals` - SMART savings & debt payoff progress
*   `/portfolio` - Investment holdings & asset allocation
*   `/assets` - Physical asset tracking & Net Worth
*   `/tax-center` - Tax deduction logs & reports
*   `/calculators` - Built-in financial calculator hub
*   `/learning-hub` - Financial education courses & quizzes
*   `/settings` - Profile, Security (PIN/Biometric), Sync settings

---

## 3. Core Feature Details

### 3.1 Money Tracking & Automation
*   **Quick Entry:** Amount-first flow, receipt scanning (OCR), and voice input.
*   **Transaction Types:** Income, Expense, Transfer, Refund, Investment (Buy/Sell/Dividend), Loan Payment, Credit Card Payment, Tax Payment, Fee, Adjustment.
*   **Transaction Rules:** Automate categories, tags, splits, or names based on merchant keywords, accounts, or amounts.

### 3.2 Smart Budgets & Saving Plans
*   **Budgeting Modes:** Category-level limits, rollover budgets, envelope budgeting, and 50/30/20 allocation templates.
*   **Goal Tracking (SMART):** Specific targets with priority ranking, automated monthly contribution calculations, and success probability scoring.
*   **Safe-to-Spend (Leftover):** Real-time spending safety cushion: `Leftover = Income - Fixed Bills - Reserves - Debt - Goals - Current Spending`.
*   **Pace:** Real-time indicator comparing current spending velocity against budget limits.

### 3.3 Advanced Financial Planning
*   **Credit Cards:** Tracking statement balances, APR, rewards, due dates, and credit utilization.
*   **Debt Payoff Plan:** Debt Snowball or Avalanche strategies, simulating extra payments and interest savings.
*   **Bills & Subscriptions:** Auto-detect recurring services, price increases, unused subscriptions, and guide cancellations.
*   **Portfolio & Net Worth:** Physical assets, manual/imported holdings, current valuations, rebalancing triggers, and risk profiles.
*   **Tax Center:** Tax-deductible expense flagging, capital gains, document storage, and estimated tax reports.

---

## 4. Financial Calculator Suite (~60 Tools)
Saved calculations store as `SavedCalculatorScenario` and can be converted into active budgets or goals.

*   **Finance & Investment:** Time Value of Money (TVM), Compound Interest, ROI, IRR/NPV, Savings Goal, Certificate of Deposit (CD), Bond, Tax Equivalent Yield, Rule of 72.
*   **Loan & Mortgage:** Loan Amortization & Comparison, Refinance, APR, Rent vs. Buy, Home Affordability, bi-weekly payments, Rental Property.
*   **Retirement:** Retirement Savings & Income Planner, Traditional vs. Roth IRAs, Required Minimum Distributions (RMD), Social Security Estimator, Annuity.
*   **Credit Card & Auto:** CC Payoff & Minimum Payment, Balance Transfer, Auto Loan vs. Lease.
*   **Stock & Portfolio:** Weighted Average Cost of Capital (WACC), Black-Scholes Options, Expected Return, CAPM, Holding Period Return, Capital Gains.
*   **Everyday & Tax:** Salary to Hourly, Paycheck Tax, Inflation, Effective Rate, Margin/Markup, Tip & Percentage.

---

## 5. Schema Blueprint (Database Models)

| Entity | Fields |
| :--- | :--- |
| **User** | `id` (UUID), `name`, `email`, `base_currency`, `country`, `timezone`, `preferred_theme`, `aiko_personality_setting`, `created_at` |
| **Account** | `id`, `user_id`, `name`, `type` (cash, bank, card, loan, etc), `currency`, `opening_balance`, `current_balance`, `is_active` |
| **Transaction** | `id`, `user_id`, `account_id`, `type`, `amount`, `currency`, `exchange_rate`, `category_id`, `date`, `merchant`, `note`, `tags`, `is_recurring`, `tax_flag` |
| **Category** | `id`, `user_id`, `name`, `parent_id`, `type`, `icon`, `color`, `budget_enabled` |
| **TransactionRule**| `id`, `user_id`, `rule_name`, `condition_type`, `condition_value`, `target_category_id`, `target_account_id`, `tags_to_apply`, `priority`, `is_active` |
| **Budget** | `id`, `user_id`, `category_id`, `amount`, `period` (weekly, monthly, custom), `rollover_enabled`, `alert_thresholds` |
| **Goal** | `id`, `user_id`, `name`, `target_amount`, `current_amount`, `target_date`, `linked_account_id`, `priority`, `success_probability` |
| **CreditCard** | `id`, `user_id`, `account_id`, `credit_limit`, `statement_day`, `due_day`, `apr`, `rewards_type` |
| **Asset** | `id`, `user_id`, `name`, `asset_class`, `value`, `currency`, `liquidity_level`, `risk_level` |
| **Liability** | `id`, `user_id`, `name`, `type`, `balance`, `interest_rate`, `monthly_payment`, `due_date` |
| **InvestmentHolding**| `id`, `user_id`, `symbol`, `asset_class`, `quantity`, `average_cost`, `current_price`, `currency`, `market_value` |
| **TaxRecord** | `id`, `user_id`, `tax_year`, `income_type`, `amount`, `deduction_type`, `document_id` |
| **Subscription** | `id`, `user_id`, `merchant`, `amount`, `billing_cycle`, `next_billing_date`, `category_id`, `cancellation_status` |
| **SavedScenario** | `id`, `user_id`, `calculator_type`, `input_json`, `result_json`, `notes`, `created_at` |
| **AikoInsight** | `id`, `user_id`, `insight_type`, `title`, `description`, `recommendation`, `confidence_score`, `source_data`, `dismissed_at`, `created_at` |

---

## 6. AI & Forecasting Engine
*   **Predictive Modeling:** Cash flow forecasting, end-of-month balance prediction, and savings goal progress. Uses simple moving average for trends, seasonality adjustments, and Monte Carlo simulations for retirement/success probability under three scenarios (optimistic, expected, conservative).
*   **Aiko Insights System:** AI evaluates transaction telemetry to generate recommendations in four dimensions:
    *   *Descriptive:* "You spent $450 on dining out this month."
    *   *Diagnostic:* "Dining out increased by 20% due to restaurant visits on weekends."
    *   *Predictive:* "At this pace, you will exceed your dining budget in 5 days."
    *   *Prescriptive:* "Limit flexible weekend spending to $15/day to stay on track."
*   **Safety & Disclaimers:** Aiko operates as an informative dashboard and advisor. Explicit disclaimers state: *AI insights are estimates, not certified financial, investment, or tax advice.*

---

## 7. Monetization & Security Specs
*   **Security Architecture:** PIN and Biometrics (Face ID/Touch ID) local access, secure token storage, remote device logout, cloud sync conflict resolution, and granular data privacy options (opt-in AI parsing, local-only mode).
*   **Feature Gate Gating System:**
    *   **Free Tier:** Manual tracking, basic budgeting, default categories, limited calculators, CSV export, basic AI insights.
    *   **Premium Tier:** Unlimited accounts, receipt OCR, PDF/Excel export, subscription cancellation suggestions, portfolio analytics, tax estimator, advanced reports, full sync.
    *   **Pro Tier:** Multi-user access, advanced accounting (double-entry, balance sheets, reconciliation), invoices, full Monte Carlo planning.

---

## 8. Product Milestones
*   **Core Release Foundation:** Blue design system & Aiko onboarding, basic accounts/transactions tracking, transaction rules, monthly budgets, goals/savings plans, basic dashboards with Pace/Leftover, CSV export, and 6 core calculators (Compound Interest, Loan, CC Payoff, Savings Goal, ROI, Currency).
*   **Phased Development:**
    *   *Phase 1-2:* Basic tracking, dashboards, budgeting, and recurring rules.
    *   *Phase 3-4:* Aiko Insights, forecasting, chat, credit cards, debt payoff, and net worth tracking.
    *   *Phase 5-6:* Advanced accounting & tax tools, receipt OCR, cloud sync, travel multi-currency mode, and localization.
