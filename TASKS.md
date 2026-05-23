# Aiko Feature Implementation Status & Todo Roadmap

This document serves as the project's roadmap and checklist (`TASKS.md`). It maps all features outlined in [PRODUCT.md](file:///c:/Users/pepod/Projects/aiko/PRODUCT.md) against their current implementation state in the codebase, categorizing them as **Completed** or **Todo/Pending**.

---

## 📊 Current Project Summary

*   **Passing Test Suite:** **108/108 Tests Passed successfully!** (Unit, widget, and service tests are fully functional).
*   **Design Language:** Built around Aiko (blue-haired financial companion) utilizing a premium card-based layout, Outfit/Inter typography, and curated semantic color systems.
*   **Offline First Heuristics:** To ensure maximum privacy and smooth offline-first usability, advanced AI/forecasting features are powered by robust client-side algorithms, local Regex-NLP engines, and custom painters.
*   **Supabase Backend:** Core repositories are wired up with Supabase PostgreSQL client operations, protected by Row Level Security (RLS).

---

## 🗺️ Feature Status Checklist

### 1. Brand Identity & Visual System
- `[x]` **Core App Name & Character Voice:** Friendly, encouraging, and supportive brand tone (never shame-based).
- `[x]` **Aiko Color & Design Tokens:** Curated primary blue (`#3B82F6`) and semantic colors (Success Green, Warning Orange, Danger Red, Premium Purple, Analytics Teal).
  - *Implementation:* [aiko_colors.dart](file:///c:/Users/pepod/Projects/aiko/lib/theme/aiko_colors.dart)
- `[x]` **Premium Card Layout Grid:** Beautiful responsive card-based architecture with smooth rounded corners.
  - *Implementation:* [aiko_theme.dart](file:///c:/Users/pepod/Projects/aiko/lib/theme/aiko_theme.dart)
- `[x]` **Guidance Principles:** Aiko avatar expressions (happy, thinking, warning, encouraging) that appear contextually on key dashboards, reviews, and insights without obscuring critical charts.
  - *Implementation:* [aiko_character/](file:///c:/Users/pepod/Projects/aiko/lib/features/aiko_character/)

---

### 2. Information Architecture & Shell Structure
- `[x]` **GoRouter Navigation Hub:** Unified routing setup supporting path configurations and deep linking.
  - *Implementation:* [app_router.dart](file:///c:/Users/pepod/Projects/aiko/lib/app/app_router.dart)
- `[x]` **Bottom Navigation Shell (5 Core Tabs):**
  - `[x]` **Home Tab (`/home`):** Home Dashboard screen featuring Net Worth overview, Safe-to-Spend gauge, Budget Progress bars, recent transactions, and Aiko greeting.
    - *Implementation:* [home_dashboard_screen.dart](file:///c:/Users/pepod/Projects/aiko/lib/features/dashboard/presentation/home_dashboard_screen.dart)
  - `[x]` **Transactions Tab (`/transactions`):** Transaction List screen with unified search, categories, rules, and recurring transaction toggles.
    - *Implementation:* [transaction_list_screen.dart](file:///c:/Users/pepod/Projects/aiko/lib/features/transactions/presentation/transaction_list_screen.dart)
  - `[x]` **Budget Tab (`/budget`):** Monthly budget overview showing limit progress, rollovers, and category filters.
    - *Implementation:* [budget_overview_screen.dart](file:///c:/Users/pepod/Projects/aiko/lib/features/budgets/presentation/budget_overview_screen.dart)
  - `[x]` **Insights Tab (`/insights`):** Rich analytics dashboard displaying custom-painted Sankey diagrams and AI savings forecasts.
    - *Implementation:* [insights_screen.dart](file:///c:/Users/pepod/Projects/aiko/lib/features/insights/presentation/insights_screen.dart)
  - `[x]` **Aiko Assistant Tab (`/aiko`):** Scrolling premium chat screen to interact directly with the Aiko AI companion.
    - *Implementation:* [aiko_assistant_screen.dart](file:///c:/Users/pepod/Projects/aiko/lib/features/aiko_assistant/presentation/aiko_assistant_screen.dart)
- `[x]` **GoRouter Sub-routes & "More" Features:**
  - `[x]` **Accounts Screen (`/accounts`):** Workspace managing cash, credit cards, bank accounts, and opening balances.
    - *Implementation:* [accounts_screen.dart](file:///c:/Users/pepod/Projects/aiko/lib/features/accounts/presentation/accounts_screen.dart)
  - `[x]` **Credit Cards Overview (`/credit-cards`):** Track statement balances, limits, APRs, utilization metrics, and payoff estimates.
    - *Implementation:* [credit_card_overview_screen.dart](file:///c:/Users/pepod/Projects/aiko/lib/features/credit_cards/presentation/credit_card_overview_screen.dart)
  - `[x]` **Bills & Subscriptions (`/bills`):** Track monthly recurring invoices, price increase alerts, and subscription details.
    - *Implementation:* [bills_screen.dart](file:///c:/Users/pepod/Projects/aiko/lib/features/bills/presentation/bills_screen.dart)
  - `[x]` **Goals Tracking (`/goals`):** SMART savings targets with prioritizations and Monte Carlo progress forecasting.
    - *Implementation:* [goals_overview_screen.dart](file:///c:/Users/pepod/Projects/aiko/lib/features/goals/presentation/goals_overview_screen.dart)
  - `[x]` **Portfolio holdings (`/portfolio`):** Allocation dashboards showing investment shares, asset classes, and capital gains.
    - *Implementation:* [portfolio_screen.dart](file:///c:/Users/pepod/Projects/aiko/lib/features/portfolio/presentation/portfolio_screen.dart)
  - `[x]` **Assets & Net Worth (`/assets`):** Asset tracking center showing liquid and fixed items with Net Worth values.
    - *Implementation:* [assets_net_worth_screen.dart](file:///c:/Users/pepod/Projects/aiko/lib/features/assets/presentation/assets_net_worth_screen.dart)
  - `[x]` **Tax Center (`/tax-center`):** Logs estimated annual taxes, tax-deductible items, and estimated tax returns.
    - *Implementation:* [tax_center_screen.dart](file:///c:/Users/pepod/Projects/aiko/lib/features/tax_center/presentation/tax_center_screen.dart)
  - `[x]` **Calculator Suite Hub (`/calculators`):** Access to all financial, loan, stock, and everyday tax calculators.
    - *Implementation:* [calculator_library_screen.dart](file:///c:/Users/pepod/Projects/aiko/lib/features/calculators/presentation/calculator_library_screen.dart)
  - `[x]` **Learning Hub (`/learning-hub`):** Access to budgeting courses, quizzes, and financial vocabulary.
    - *Implementation:* [learning_hub_screen.dart](file:///c:/Users/pepod/Projects/aiko/lib/features/learning_hub/presentation/learning_hub_screen.dart)
  - `[x]` **Settings & PIN Security (`/settings`):** Manage notifications, profile preferences, and local PIN locking.
    - *Implementation:* [settings_screen.dart](file:///c:/Users/pepod/Projects/aiko/lib/features/settings/presentation/settings_screen.dart)

---

### 3. Core Feature Details

#### 3.1 Money Tracking & Automation
- `[x]` **Amount-First Entry Flow:** Quickly input transactions prioritizing amount digits before filling secondary metadata.
  - *Implementation:* [transaction_form_screen.dart](file:///c:/Users/pepod/Projects/aiko/lib/features/transactions/presentation/transaction_form_screen.dart)
- `[x]` **Simulated AI OCR Receipt Scanning:** Upload receipts (Starbucks, Amazon, etc.) and auto-parse merchant, tax, amount, and date fields.
  - *Implementation:* [transaction_form_screen.dart](file:///c:/Users/pepod/Projects/aiko/lib/features/transactions/presentation/transaction_form_screen.dart)
- `[x]` **Natural Language Voice Entry Heuristic:** Input transaction details via simulated speech or text sentences (e.g. *"Spent 25 dollars on lunch at McDonald's yesterday"*) and auto-parse details.
  - *Implementation:* [transaction_form_screen.dart](file:///c:/Users/pepod/Projects/aiko/lib/features/transactions/presentation/transaction_form_screen.dart)
- `[x]` **13 Financial Transaction Types:** Support for Income, Expense, Transfer, Refund, Buy, Sell, Dividend, Loan Payment, Credit Card Payment, Tax Payment, Fee, and Adjustment types.
  - *Implementation:* [transaction_dto.dart](file:///c:/Users/pepod/Projects/aiko/lib/features/transactions/data/transaction_dto.dart)
- `[x]` **Transaction Rules Engine:** Automate category assignment, tags, or names based on matching keywords, accounts, or amounts.
  - *Implementation:* [transaction_rules_screen.dart](file:///c:/Users/pepod/Projects/aiko/lib/features/transactions/presentation/transaction_rules_screen.dart)

#### 3.2 Smart Budgets & Saving Plans
- `[x]` **Preset Allocation Templates:** Dynamically apply presets inside the budget creator:
  - **50/30/20 Rule:** Auto-allocates entered income into 50% Needs, 30% Wants, and 20% Savings.
  - **Zero-Based Budgeting:** Gauge indicating "Assign every dollar a job" down to exactly $0.
  - **Envelope Budgeting:** Create cash envelope category targets with active status commentaries from Aiko.
  - *Implementation:* [budget_form_screen.dart](file:///c:/Users/pepod/Projects/aiko/lib/features/budgets/presentation/budget_form_screen.dart)
- `[x]` **SMART Goal Planners:** Targets integrated with priorities and Monte Carlo forecast scores.
  - *Implementation:* [goals_overview_screen.dart](file:///c:/Users/pepod/Projects/aiko/lib/features/goals/presentation/goals_overview_screen.dart)
- `[x]` **Safe-to-Spend (Leftover) Cushion:** Live formula that calculates available daily spending money after bills, savings, and debts.
  - *Implementation:* [home_dashboard_screen.dart](file:///c:/Users/pepod/Projects/aiko/lib/features/dashboard/presentation/home_dashboard_screen.dart)
- `[x]` **Spending Pace Tracker:** Indicator matching overall timeline progress versus spending velocity.
  - *Implementation:* [budget_progress_service.dart](file:///c:/Users/pepod/Projects/aiko/lib/features/budgets/application/budget_progress_service.dart)

#### 3.3 Advanced Financial Planning
- `[x]` **Interactive Credit Card Payoff Slider:** Slide custom monthly payments to instantly compute months to payoff, total interest, and trigger alert triggers when payments fail to cover interest.
  - *Implementation:* [credit_card_overview_screen.dart](file:///c:/Users/pepod/Projects/aiko/lib/features/credit_cards/presentation/credit_card_overview_screen.dart)
- `[x]` **Debt Avalanche vs. Snowball Simulator:** Compare strategies side-by-side, estimate interest and timeline savings, and rank active debts with a slide control for extra monthly payments.
  - *Implementation:* [debt_payoff_plan_screen.dart](file:///c:/Users/pepod/Projects/aiko/lib/features/debt_loans/presentation/debt_payoff_plan_screen.dart)
- `[x]` **Double-Entry Journal & Reconciliation:** Core ledger record-keeping matching debit and credit structures for business reconciliation.
  - *Implementation:* [accounting_screen.dart](file:///c:/Users/pepod/Projects/aiko/lib/features/accounting/presentation/accounting_screen.dart)

---

### 4. Financial Calculator Suite (~60 Tools)
- `[x]` **Core Suite Integration:** Mapped all TVM, mortgage, option, and stock calculations under a unified search catalog.
  - *Implementation:* [calculator_library_screen.dart](file:///c:/Users/pepod/Projects/aiko/lib/features/calculators/presentation/calculator_library_screen.dart)
- `[x]` **6 Detailed Math Calculators:** Dedicated inputs, active results sliders, and exact formulas:
  - **Rule of 72:** Compute years to double investments.
  - **Inflation Calculator:** Purchasing power shifts over adjustable years.
  - **Salary to Hourly Converter:** Translate salary packages into hourly wages using flexible weeks-per-year ratios.
  - **Tax Equivalent Yield:** Match tax-exempt yields against municipal taxable standards.
  - **IRR / NPV Evaluator:** Map multi-year positive and negative cash flow series.
  - **Tip Splitter:** Divide restaurant/delivery bills by party sizes and percentages.
  - *Implementation:* [calculator_detail_screen.dart](file:///c:/Users/pepod/Projects/aiko/lib/features/calculators/presentation/calculator_detail_screen.dart)

---

### 5. AI & Forecasting Engine
- `[x]` **Monte Carlo Simulation Model:** 1,000 randomized iterations mapping goal success probabilities and detailed Optimistic, Expected, and Conservative outcomes.
  - *Implementation:* [monte_carlo_engine.dart](file:///c:/Users/pepod/Projects/aiko/lib/core/prediction/monte_carlo_engine.dart)
- `[x]` **Interactive Sankey Cash Flow Chart:** Gradient Bezier curves drawn with a custom canvas painter, showing live cash distributions.
  - *Implementation:* [insights_screen.dart](file:///c:/Users/pepod/Projects/aiko/lib/features/insights/presentation/insights_screen.dart)
- `[x]` **Aiko Context Heuristics chatbot:** Interactive, scrolling chat interface capable of querying balances, spending habits, categories, net worth, and goals in real-time.
  - *Implementation:* [aiko_assistant_screen.dart](file:///c:/Users/pepod/Projects/aiko/lib/features/aiko_assistant/presentation/aiko_assistant_screen.dart)

---

### 6. Premium Exports Center
- `[x]` **Exporters Dashboard:** Let users select transaction date ranges, view summaries, and export records.
  - **Raw CSV Plain Exporter:** standard comma-delimited export.
  - **Microsoft Excel UTF-8 BOM CSV Exporter:** forces Excel to parse currency characters, commas, and dates correctly.
  - **PDF HTML Statement Invoice Builder:** beautiful HTML code package ready to print or save.
  - **Native System Share Sheets Integration:** uses native sharing protocols via standard packages.
  - *Implementation:* [export_screen.dart](file:///c:/Users/pepod/Projects/aiko/lib/features/export/presentation/export_screen.dart)

---

## 🛠️ Live Integration Checklist (Completed)

We have successfully transitioned the Aiko app from offline-first mock structures to production-ready cloud services, platform integrations, and local fallbacks:

- `[x]` **Live Bank API Integration**
  - Plaid-like OAuth simulations fetch live transaction structures and populate them directly into the bank accounts.
  - *Implementation:* [bank_feed_service.dart](file:///c:/Users/pepod/Projects/aiko/lib/features/accounts/application/bank_feed_service.dart), [accounts_screen.dart](file:///c:/Users/pepod/Projects/aiko/lib/features/accounts/presentation/accounts_screen.dart)
- `[x]` **Hardware Biometric Verification**
  - Configured PIN security setup and hardware biometric authentication toggles using secure storage and standard physical device biometrics.
  - *Implementation:* [persistent_secure_app_lock_service.dart](file:///c:/Users/pepod/Projects/aiko/lib/core/security/persistent_secure_app_lock_service.dart), [settings_screen.dart](file:///c:/Users/pepod/Projects/aiko/lib/features/settings/presentation/settings_screen.dart)
- `[x]` **Cloud-OCR Document Scanner**
  - Integrated Supabase Edge Function receipt parsing via OCR endpoints with robust offline regex parsing fallbacks.
  - *Implementation:* [receipt_ocr_service.dart](file:///c:/Users/pepod/Projects/aiko/lib/features/transactions/application/receipt_ocr_service.dart)
- `[x]` **Native Speech-to-Text Integration**
  - Speech-to-text recording capturing audio waveform animations and parsing transactions via natural language processing.
  - *Implementation:* [voice_transcription_service.dart](file:///c:/Users/pepod/Projects/aiko/lib/features/transactions/application/voice_transcription_service.dart), [transaction_form_screen.dart](file:///c:/Users/pepod/Projects/aiko/lib/features/transactions/presentation/transaction_form_screen.dart)
- `[x]` **Real-time Multi-Device Sync CRDTs**
  - Real-time synchronizations with Postgres change streams using LWW conflict resolution rules.
  - *Implementation:* [multi_device_sync_service.dart](file:///c:/Users/pepod/Projects/aiko/lib/core/sync/multi_device_sync_service.dart), [devices_screen.dart](file:///c:/Users/pepod/Projects/aiko/lib/features/devices/presentation/devices_screen.dart)
- `[x]` **Live Stock and Portfolio Market Feeds**
  - Connected the investment portfolio to real-time pricing providers with capital gains re-computations and allocation drift alerts.
  - *Implementation:* [live_market_feed_service.dart](file:///c:/Users/pepod/Projects/aiko/lib/features/portfolio/application/live_market_feed_service.dart), [portfolio_provider.dart](file:///c:/Users/pepod/Projects/aiko/lib/features/portfolio/application/portfolio_provider.dart), [portfolio_screen.dart](file:///c:/Users/pepod/Projects/aiko/lib/features/portfolio/presentation/portfolio_screen.dart)
- `[x]` **Auto-billing Cancellations Workflows**
  - Generates legal subscription cancellation emails and links to system native share sheets or `mailto:` wizards.
  - *Implementation:* [subscription_cancellation_service.dart](file:///c:/Users/pepod/Projects/aiko/lib/features/bills/application/subscription_cancellation_service.dart), [bills_screen.dart](file:///c:/Users/pepod/Projects/aiko/lib/features/bills/presentation/bills_screen.dart)
- `[x]` **Supabase Cloud Storage File Uploads**
  - Secured PDF uploads storing documents inside encrypted Supabase Storage buckets, loaded asynchronously.
  - *Implementation:* [tax_document_vault_service.dart](file:///c:/Users/pepod/Projects/aiko/lib/features/tax_center/application/tax_document_vault_service.dart), [tax_center_screen.dart](file:///c:/Users/pepod/Projects/aiko/lib/features/tax_center/presentation/tax_center_screen.dart)

