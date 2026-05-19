# Data Model: Aiko Product Expansion Roadmap

## Modeling Principles

- Every user-owned entity includes ownership, timestamps, lifecycle state, and RLS coverage.
- Advanced finance outputs store source data references and assumptions, not just final numbers.
- Provider-backed entities record data freshness and source where relevant.
- Premium plan state controls feature access but never blocks user-owned data export, account deletion, privacy controls, or critical warnings.

## Entities

### Aiko Character Profile

- `user_id`
- `visibility_mode`: full, reduced, hidden
- `tone_preference`: supportive, concise, educational
- `allowed_contexts`: onboarding, home, insights, alerts, learning, calculators
- `expression_preferences`
- `updated_at`

### Import Job

- `id`
- `user_id`
- `source_type`: csv, excel, ofx, qif, statement, pasted_table, receipt_ocr, email_receipt
- `status`: draft, previewed, validated, saved, rolled_back, failed
- `mapping_summary`
- `validation_issue_count`
- `duplicate_candidate_count`
- `created_at`

### Export Package

- `id`
- `user_id`
- `scope`: transactions, reports, tax, portfolio, scenarios, full_backup
- `format`: csv, pdf, excel, json, image, backup
- `sensitivity_level`
- `status`: requested, generating, ready, expired, failed
- `created_at`
- `expires_at`

### Backup Snapshot

- `id`
- `user_id`
- `status`: creating, ready, restoring, restored, failed
- `encrypted`: true or false
- `included_scopes`
- `failure_reason`
- `created_at`

### Bill Or Subscription

- `id`
- `user_id`
- `merchant`
- `amount`
- `currency`
- `billing_cycle`
- `next_due_date`
- `annualized_cost`
- `category_id`
- `status`: active, paused, canceled, unknown
- `cancellation_status`

### Credit Card Profile

- `id`
- `user_id`
- `account_id`
- `statement_balance`
- `current_balance`
- `credit_limit`
- `minimum_payment`
- `payment_due_date`
- `apr`
- `rewards_summary`
- `annual_fee`

### Debt Or Loan Plan

- `id`
- `user_id`
- `liability_id`
- `strategy`: snowball, avalanche, custom
- `monthly_payment`
- `extra_payment`
- `projected_payoff_date`
- `projected_interest_savings`
- `status`

### Asset

- `id`
- `user_id`
- `name`
- `asset_class`
- `value`
- `currency`
- `liquidity_level`
- `risk_level`
- `include_in_net_worth`

### Investment Holding

- `id`
- `user_id`
- `symbol_or_name`
- `asset_class`
- `quantity`
- `average_cost`
- `current_value`
- `currency`
- `gain_loss`
- `dividend_income`
- `source_data_age`

### Tax Record

- `id`
- `user_id`
- `tax_year`
- `income_type`
- `amount`
- `deduction_type`
- `document_id`
- `country`
- `estimate_disclaimer_acknowledged`

### Accounting Record

- `id`
- `user_id`
- `business_profile_id`
- `record_type`: chart_account, journal_entry, invoice, receivable, payable, reimbursement, reconciliation
- `amount`
- `currency`
- `status`
- `linked_transaction_id`

### Course Lesson

- `id`
- `topic`
- `level`
- `title`
- `completion_status`
- `quiz_score`
- `recommended_reason`

### Device Session

- `id`
- `user_id`
- `device_name`
- `last_seen_at`
- `sync_status`
- `conflict_count`
- `remote_signed_out_at`

### Trip

- `id`
- `user_id`
- `name`
- `destination`
- `start_date`
- `end_date`
- `home_currency`
- `local_currency`
- `budget`
- `foreign_fee_total`

### Optimization Suggestion

- `id`
- `user_id`
- `type`
- `title`
- `source_data_summary`
- `expected_impact`
- `confidence`
- `assumptions`
- `status`: active, dismissed, applied, tuned
- `disclaimer_type`

### Subscription Plan

- `id`
- `user_id`
- `tier`: free, premium, pro
- `status`
- `included_capabilities`
- `limits`
- `trial_ends_at`

## State Transitions

- **Import Job**: draft -> previewed -> validated -> saved; any state -> failed; saved -> rolled_back.
- **Export Package**: requested -> generating -> ready -> expired; requested/generating -> failed.
- **Backup Snapshot**: creating -> ready -> restoring -> restored; any state -> failed.
- **Bill Or Subscription**: active -> paused -> active; active -> canceled.
- **Optimization Suggestion**: active -> dismissed, applied, or tuned.
- **Device Session**: active -> remote_signed_out; active -> conflict_pending -> resolved.

## Derived Values

- **Annualized subscription cost**: recurring amount normalized to yearly amount.
- **Credit utilization**: current balance divided by credit limit.
- **Debt payoff date**: projected payoff based on strategy, balance, interest, payment, and extra payment.
- **Portfolio allocation**: holding value divided by total portfolio value.
- **Net worth**: assets minus liabilities, converted to base currency.
- **Financial health score**: weighted score from cash flow, budget adherence, debt, savings, net worth, risk, and data completeness.
