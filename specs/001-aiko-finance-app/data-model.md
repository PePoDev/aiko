# Data Model: Aiko Personal Finance App

## Modeling Principles

- Every user-owned entity has an owner identity and row-level access policy.
- Monetary values include amount, currency, and exchange-rate context when applicable.
- Soft delete or archive user finance records where historical reports depend on them.
- Calculator inputs/results and AI source summaries are stored as structured values because their schemas vary by calculator or insight type.
- Advanced modules can reuse the same base entities without blocking the first-release MVP.

## Entities

### Profile

Represents the application profile associated with an authenticated user.

**Fields**:
- `id`: profile identity matching the authenticated user.
- `display_name`: user-visible name.
- `email`: account email, read from auth where possible.
- `base_currency`: ISO 4217 currency code used for reports.
- `country`: country for localization, tax disclaimers, and default formatting.
- `timezone`: reporting and reminder timezone.
- `preferred_theme`: system, light, or dark.
- `aiko_character_visibility`: full, compact, or hidden.
- `aiko_personality_setting`: tone preference within approved brand voice.
- `ai_consent_enabled`: whether Aiko can use sensitive finance data.
- `onboarding_status`: not_started, in_progress, completed.
- `security_status`: not_configured, pin_enabled, biometric_enabled, locked_out.
- `created_at`, `updated_at`.

**Relationships**:
- Owns accounts, categories, budgets, goals, transactions, rules, insights, reports, dashboard settings, calculator scenarios, and notification preferences.

**Validation**:
- `base_currency` is required before onboarding completes.
- AI features that analyze sensitive data require `ai_consent_enabled`.
- Security state must be configured or explicitly skipped before onboarding completes.

### Account

Represents a financial container such as cash, bank, e-wallet, credit card, loan, investment, asset, or liability account.

**Fields**:
- `id`, `user_id`.
- `name`.
- `type`: cash, bank, e_wallet, credit_card, loan, investment, asset, liability, other.
- `currency`.
- `opening_balance`.
- `current_balance`.
- `institution`.
- `include_in_net_worth`.
- `is_active`.
- `created_at`, `updated_at`, `archived_at`.

**Relationships**:
- Has many transactions.
- May have one credit card detail record.
- May be linked to goals, budgets, bills, subscriptions, assets, or liabilities.

**Validation**:
- Name, type, currency, and opening balance are required.
- Archived accounts remain visible in historical reports but cannot be selected for new transactions unless restored.

### Category

Represents a user-visible classification for transactions and budgets.

**Fields**:
- `id`, `user_id`.
- `name`.
- `parent_id`.
- `type`: income, expense, transfer, finance, tax, investment, adjustment.
- `group`: needs, wants, savings, debt, investment, tax, business, custom.
- `icon`.
- `color`.
- `budget_enabled`.
- `is_default`.
- `is_active`.
- `created_at`, `updated_at`, `archived_at`.

**Relationships**:
- Parent category can have subcategories.
- Used by transactions, budgets, transaction rules, bills, and subscriptions.

**Validation**:
- Category names are unique within the same parent and user.
- A category cannot be deleted when used by historical transactions; it must be archived or merged.

### Transaction

Represents a posted or draft money movement.

**Fields**:
- `id`, `user_id`.
- `account_id`.
- `type`: income, expense, transfer, refund, investment_buy, investment_sell, dividend, interest, loan_payment, credit_card_payment, tax_payment, fee, adjustment.
- `amount`.
- `currency`.
- `exchange_rate_to_base`.
- `category_id`.
- `date`.
- `merchant`.
- `note`.
- `tags`.
- `attachment_ids`.
- `location_label`.
- `is_recurring`.
- `tax_flag`.
- `status`: draft, posted, voided, archived.
- `created_at`, `updated_at`.

**Relationships**:
- Belongs to an account and category.
- Has zero or more splits.
- May link to a recurring template, bill, subscription, goal contribution, loan payment, or credit card payment.

**Validation**:
- Posted transactions require account, type, amount, currency, and date.
- Amount must be positive unless the type explicitly allows signed adjustments.
- Transfers and credit card payments require paired account movement or a transfer link.
- Split totals must equal the parent transaction amount.

### Transaction Split

Represents category allocation within one transaction.

**Fields**:
- `id`, `transaction_id`, `user_id`.
- `category_id`.
- `amount`.
- `note`.
- `tax_flag`.

**Relationships**:
- Belongs to one transaction and one category.

**Validation**:
- Split amount is positive.
- Sum of splits equals parent transaction amount.

### Transaction Rule

Represents automation for categorization, tagging, naming, recurrence, or splits.

**Fields**:
- `id`, `user_id`.
- `rule_name`.
- `condition_type`: merchant, keyword, amount, account, category, transaction_type.
- `condition_operator`: contains, equals, starts_with, ends_with, greater_than, less_than, between.
- `condition_value`.
- `target_category_id`.
- `target_account_id`.
- `tags_to_apply`.
- `split_template`.
- `mark_recurring`.
- `priority`.
- `is_active`.
- `created_at`, `updated_at`.

**Relationships**:
- May reference target category and account.
- Applies to transactions through preview and bulk apply workflows.

**Validation**:
- Active rules require at least one condition and one target action.
- Priority must be unique or deterministic within a user scope.
- Bulk apply requires preview confirmation.

### Budget

Represents planned spending or allocation for a category/account/period.

**Fields**:
- `id`, `user_id`.
- `name`.
- `category_id`.
- `account_id`.
- `amount`.
- `currency`.
- `period`: monthly for MVP; weekly, yearly, custom later.
- `period_start`, `period_end`.
- `rollover_enabled`.
- `alert_thresholds`.
- `status`: active, paused, archived.
- `created_at`, `updated_at`.

**Relationships**:
- Links to category and optionally account.
- Reads matching transactions to calculate progress.

**Validation**:
- MVP budgets require category, amount, currency, and monthly period.
- Alert thresholds must be between 1 and 100 percent.
- Archived budgets remain available for reports.

### Goal

Represents a financial target.

**Fields**:
- `id`, `user_id`.
- `name`.
- `purpose`: emergency_fund, debt_payoff, investment, vacation, education, home, car, wedding, retirement, custom.
- `target_amount`.
- `current_amount`.
- `currency`.
- `target_date`.
- `linked_account_id`.
- `priority`.
- `success_probability`.
- `status`: active, paused, completed, archived.
- `created_at`, `updated_at`, `completed_at`.

**Relationships**:
- May have one saving plan.
- May link to account, transactions, calculator scenario, or Aiko insight.

**Validation**:
- Target amount must be greater than zero.
- Current amount cannot be negative.
- Required contribution must be recalculated when target date, amount, or current amount changes.

### Saving Plan

Represents the contribution schedule for a goal.

**Fields**:
- `id`, `user_id`, `goal_id`.
- `frequency`: weekly, monthly.
- `required_contribution`.
- `suggested_contribution`.
- `forecasted_completion_date`.
- `milestones`.
- `status`: active, paused, completed.
- `created_at`, `updated_at`.

**Relationships**:
- Belongs to one goal.

**Validation**:
- Active saving plan requires an active goal.
- Forecast must reflect current amount, target amount, contribution frequency, and date.

### Dashboard Widget Preference

Represents personalized Home widget configuration.

**Fields**:
- `id`, `user_id`.
- `widget_key`.
- `is_visible`.
- `position`.
- `size`: compact, expanded.
- `dashboard_mode`: personal, business, family, travel.
- `created_at`, `updated_at`.

**Validation**:
- Widget keys must be recognized by the app.
- Positions are unique within a dashboard mode.

### Bill Or Subscription

Represents a recurring financial obligation or subscription.

**Fields**:
- `id`, `user_id`.
- `merchant`.
- `amount`.
- `currency`.
- `billing_cycle`.
- `next_billing_date`.
- `category_id`.
- `account_id`.
- `reminder_enabled`.
- `cancellation_status`: not_reviewed, keep, cancel_planned, cancelled.
- `status`: active, paused, cancelled, archived.
- `created_at`, `updated_at`.

**Relationships**:
- May generate recurring transactions.
- May produce Aiko cancellation or bill-lowering insights.

**Validation**:
- Active subscriptions require merchant, amount, cycle, next billing date, and category.

### Credit Card Detail

Represents credit-card-specific data for an account.

**Fields**:
- `id`, `user_id`, `account_id`.
- `credit_limit`.
- `statement_balance`.
- `current_balance`.
- `statement_day`.
- `due_day`.
- `minimum_payment`.
- `apr`.
- `rewards_type`.
- `annual_fee`.
- `status`: active, closed, archived.

**Relationships**:
- Belongs to one account of type credit_card.
- Reads transactions for card-specific reports.

**Validation**:
- Credit limit must be non-negative.
- Due day and statement day must be valid calendar days.

### Asset

Represents owned value included in net worth and allocation.

**Fields**:
- `id`, `user_id`.
- `name`.
- `asset_class`: cash, bank_deposit, stock, etf, mutual_fund, bond, crypto, real_estate, commodity, retirement, business, vehicle, collectible, other.
- `value`.
- `currency`.
- `liquidity_level`.
- `risk_level`.
- `linked_account_id`.
- `created_at`, `updated_at`, `archived_at`.

**Validation**:
- Value must be non-negative.
- Asset class and currency are required.

### Liability

Represents a debt obligation.

**Fields**:
- `id`, `user_id`.
- `name`.
- `type`: loan, mortgage, credit_card, tax, other.
- `balance`.
- `currency`.
- `interest_rate`.
- `monthly_payment`.
- `due_date`.
- `linked_account_id`.
- `status`: active, paid_off, archived.

**Validation**:
- Balance must be non-negative.
- Interest rate cannot be negative.

### Investment Holding

Represents a portfolio holding for future portfolio screens.

**Fields**:
- `id`, `user_id`.
- `symbol`.
- `name`.
- `asset_class`.
- `quantity`.
- `average_cost`.
- `current_price`.
- `currency`.
- `market_value`.
- `dividend_income`.
- `fees`.
- `created_at`, `updated_at`.

**Validation**:
- Quantity and prices cannot be negative.
- Market value is derived or validated from quantity and current price.

### Tax Record

Represents tax-related income, deductions, documents, or estimates.

**Fields**:
- `id`, `user_id`.
- `tax_year`.
- `income_type`.
- `amount`.
- `currency`.
- `deduction_type`.
- `document_id`.
- `source_transaction_id`.
- `estimate_disclaimer_accepted`.
- `created_at`, `updated_at`.

**Validation**:
- Tax year is required.
- Tax values are estimates and require visible disclaimer behavior.

### Attachment

Represents a receipt, document, or image stored outside relational rows.

**Fields**:
- `id`, `user_id`.
- `storage_bucket`.
- `storage_path`.
- `file_name`.
- `content_type`.
- `size_bytes`.
- `linked_entity_type`.
- `linked_entity_id`.
- `created_at`.

**Validation**:
- Storage path must be user-scoped.
- File type and size must pass policy limits.

### Saved Calculator Scenario

Represents saved calculator inputs and outputs.

**Fields**:
- `id`, `user_id`.
- `calculator_type`: compound_interest, loan, credit_card_payoff, savings_goal, roi, currency_converter.
- `input_json`.
- `result_json`.
- `notes`.
- `converted_entity_type`.
- `converted_entity_id`.
- `created_at`, `updated_at`.

**Validation**:
- Input and result schema must match calculator type.
- Saved results require enough metadata to reproduce the displayed result.

### Aiko Insight

Represents an explainable recommendation or warning.

**Fields**:
- `id`, `user_id`.
- `insight_type`: descriptive, diagnostic, predictive, prescriptive.
- `title`.
- `description`.
- `recommendation`.
- `confidence_score`.
- `source_data_summary`.
- `related_entity_type`.
- `related_entity_id`.
- `status`: new, viewed, applied, dismissed, muted.
- `feedback`: helpful, not_helpful, irrelevant.
- `created_at`, `viewed_at`, `dismissed_at`.

**Validation**:
- Insight must include source summary and dismiss action.
- Sensitive insights require AI consent and relevant disclaimer.

### Report

Represents a generated financial summary or export.

**Fields**:
- `id`, `user_id`.
- `report_type`: monthly, annual, cash_flow, budget, tax, portfolio, net_worth, credit_card, debt, aiko_review.
- `period_start`, `period_end`.
- `filters`.
- `summary_json`.
- `export_format`.
- `status`: draft, generated, exported, failed.
- `created_at`, `updated_at`.

**Validation**:
- Reports require period and selected scope.
- Exported reports must include filter/date metadata.

## State Transitions

### Onboarding

`not_started -> focus_selected -> currency_selected -> first_account_added -> budget_or_goal_created -> security_configured_or_skipped -> completed`

### Transaction

`draft -> posted -> edited -> posted`  
`posted -> voided`  
`posted -> archived`

### Budget

`active -> threshold_50 -> threshold_75 -> threshold_90 -> threshold_100_or_over`  
`active -> paused -> active`  
`active -> archived`

### Goal

`active -> paused -> active`  
`active -> completed`  
`active -> archived`

### Aiko Insight

`new -> viewed -> applied`  
`new -> viewed -> dismissed`  
`new -> muted`

### Bill Or Subscription

`active -> due_soon -> paid`  
`active -> cancel_planned -> cancelled`  
`active -> archived`

## Derived Values

- **Net worth**: assets minus liabilities, converted to base currency.
- **Current account balance**: opening balance plus posted transactions adjusted by account type.
- **Budget used**: sum of matching posted transactions within budget period.
- **Pace**: month-to-date spending compared with expected period progress and historical behavior.
- **Leftover / safe-to-spend**: income minus fixed bills, required expenses, debt payments, goal contributions, and current spending.
- **Required goal contribution**: remaining target divided by remaining contribution periods.
- **Credit utilization**: current balance divided by credit limit.
- **Aiko insight confidence**: derived from source completeness, recency, and rule/model confidence.
