# Calculations

Every number Aiko shows, the code that computes it, and the exact rule. Services are pure function objects in `application/` folders with unit tests in `test/features/`. Change the formula and its test together, and update this page.

General rules:

- Money math uses `Decimal` through `Money`. Ratios, percentages, the Monte Carlo engine, investment percentages and calculators use `double`; their results are estimates or display values, never stored balances.
- A "month" runs from the first day 00:00 to the last day 23:59:59.999 in the device's local time.
- Most views take the currency of the first record they find and add amounts without converting currencies ([Known gaps](features.md#known-gaps)).

## Account balances

`FinanceTransaction.applyToAccountBalance` / `reverseFromAccountBalance` (`lib/features/transactions/domain/transaction.dart`):

```text
inflow  (income, transferIn, refund, dividend,
         interest, investmentSell):   balance + amount
adjustment (signed amount):           balance + amount
outflow (every other type):           balance - amount
currency ≠ account currency:          balance unchanged
```

`TransactionType.isInflow` holds the inflow list; `FinanceTransaction.signedAmount` is the change a row makes (positive in, negative out). The transaction list's Net and the CSV export use the same sign.

- **Save** (`TransactionsNotifier.saveTransactions`): for each row (both legs of a transfer), reverse the previous version from its old account, then apply the new version to its account, and save only the accounts whose balance changed.
- **Delete**: reverse the transaction from its account; a linked transfer leg takes its partner with it.
- **Opening balance and balance edits**: a new account's balance is saved as an `adjustment` row; editing the balance adds an adjustment for the difference between the new balance and what the account's rows add up to (`balanceFromTransactions`). Opening balances saved as income or expense by older versions are rewritten once as signed adjustments on load (`legacyOpeningBalanceFixes`), which leaves the balance unchanged.
- **Reconcile on load** (`TransactionsNotifier.build`): for every account with at least one transaction, recompute the balance from zero by applying all its transactions in one pass; save it if it differs. Accounts with no transactions keep their stored balance.

### Sign convention and the Accounts summary

Balances are signed: money you have is positive, money you owe (a used credit card, a loan) is negative, because expenses subtract from the balance. The **Accounts** screen summary (`summarizeAccounts` in `lib/features/accounts/application/account_balances.dart`) takes each balance from the ledger (`currentAccountBalances`) and counts the same accounts as the Overview's net worth: active, not goals, included in net worth (`countsTowardNetWorth`). Only accounts in the base currency count; others are skipped, not converted. Positive balances are assets and the absolute value of negative balances are liabilities, so assets − liabilities = net worth.

## Dashboard summary

`buildDashboardSummary` (`lib/features/dashboard/application/dashboard_summary_builder.dart`, through `dashboardSummaryProvider`), current calendar month (the whole last day included), active accounts only, in the profile's **base currency**:

| Figure | Rule |
| --- | --- |
| Net worth | Sum of signed `current_balance` over active non-goal accounts with `include_in_net_worth` |
| Total cash | Sum over active `cash` and `bank` accounts |
| Monthly income | Sum of `income` transactions this month, voided and archived ones excluded |
| Monthly spending | Sum of `expense` transactions this month, voided and archived ones excluded |
| Today's spending | Posted expenses dated today |
| Safe to spend (weekly) | `max(0, (income − spending) ÷ 4.33)`, rounded to 2 decimals |

Amounts in other currencies are converted with `CurrencyConverter`, using rates quoted against the base currency from `fxRatesProvider`: live from `open.er-api.com`, or the copy saved on the device, which adds a "Rates as of {date}." note; read only when another currency is present ([Architecture → Exchange rates](architecture.md#exchange-rates)). Without any rate, those amounts are left out and the Daily spending card names the currencies it couldn't count. Ask Aiko's on-device snapshot converts with the rates already loaded (or the saved copy) and never waits on the network.

## Daily spending reaction

`_DailySpendingPanel` (`lib/features/dashboard/presentation/home_dashboard_screen.dart`) and `DailySpendingReaction` (`lib/features/dashboard/domain/daily_spending_reaction.dart`):

```text
used       = today's posted expenses, in the base currency
daily safe = weekly safe to spend ÷ 7
ratio      = used ÷ daily safe   (0 when daily safe ≤ 0)
```

`assessDailySpending` picks the reaction:

| Situation | Reaction | Color |
| --- | --- | --- |
| Daily safe > 0, ratio < 0.75 | comfortable | green |
| Daily safe > 0, ratio 0.75 – < 1 | caution | orange |
| Daily safe > 0, ratio ≥ 1 | exceeded | red |
| Daily safe ≤ 0, no income this month | needsIncome (asks you to log income) | blue |
| Daily safe ≤ 0, something spent today | exceeded | red |
| Daily safe ≤ 0, nothing spent today | idle | teal |

The panel also shows the month's net cash flow (income − spending) and "left to save" (net cash flow − weekly safe to spend).

## Safe-to-spend breakdown

`BudgetInsightsService.safeToSpend` (`lib/features/overview/application/budget_insights_service.dart`), current month:

```text
reserved  = Σ over budgeted categories of what's left of their budget in its current period (with rollover)
leftover  = income − spent − reserved
daysRemaining = days left in the month, including today
```

## Category budget progress

`CategoryBudgetProgressService` (`lib/features/categories/application/category_budget_progress_service.dart`) sums expenses in the category over its period:

| Period | Window (`budgetPeriodWindow`, start inclusive, end exclusive) |
| --- | --- |
| daily | today 00:00 to tomorrow 00:00 |
| weekly | Monday 00:00 to the next Monday 00:00 |
| monthly | the 1st to the 1st of next month |
| yearly | 1 January to 1 January |

**Rollover**: with `rolloverUnused`, what was left of the previous period's limit is added to this period's limit (one period back; overspending doesn't reduce the next limit). Nothing carries into the category's first period: the period of its `created_at`, or, when that is empty, of its first transaction. Default category clones usually have no `created_at`, so they use the first-transaction rule.

The recommendation is "Keep this category under `remaining ÷ daysLeft` `<currency>`/day to stay on track", or a gentle over-budget message. The Categories screen, budget **notifications**, safe-to-spend, Ask Aiko's snapshot and the Overview's Category budgets card all use this progress, each budget in its own period. Notifications fire at the highest crossed threshold (default 50/75/90/100%): warnings below 100% and danger at 100% or more. The Category budgets card charts the month's spending, so it compares only monthly budgets.

## Cash flow

`CashFlowService` (`lib/features/overview/application/cash_flow_service.dart`):

| Set | Transaction types |
| --- | --- |
| Inflow | `income`, `refund`, `dividend`, `interest`, `investmentSell` |
| Outflow | `expense`, `investmentBuy`, `loanPayment`, `creditCardPayment`, `taxPayment`, `fee` |

Transfers between your own accounts and balance adjustments are in neither set.

- **Overview**: this month's `income` and `expense` totals and their difference, plus a 12-month trend of net = inflow − outflow per month.
- **Sankey**: this month's inflow total, and outflow grouped by each category's 50/30/20 bucket (`needs`, `wants`, `savings`, `debt`, …; uncategorized → `custom`).

## Monthly report

`MonthlyReportService` (`lib/features/overview/application/monthly_report_service.dart`) compares a month (this month, or the one in `/reports/monthly?month=YYYY-MM`) with the month before:

- income, expenses, net cash flow, saved (`max(0, net)`), savings rate (net ÷ income);
- percentage change for income, expenses and net against the month before (shown green when good news, red when bad);
- spending by category, top 5 slices with the rest folded into "Other".

## Upcoming bills

`buildDashboardDueItems` (`lib/features/dashboard/domain/dashboard_due_item.dart`): for each active credit card with a positive amount due, the next occurrence of its due day (today included), clamped to the month's length. Items due within 30 days are listed.

The amount due (`creditCardAmountDue`) reads the signed balance, so a used card owes −balance:

```text
minimum payment set:  min(minimum payment, owed)   (the minimum when nothing is owed)
no minimum payment:   owed = −balance              (nothing when the balance is 0 or positive)
```

Days until due count calendar dates, not hours. Bill **notifications** fire for items due within 7 days: warning at 2 days or less, info otherwise.

## Goals

`Account.goalRemaining` = `max(0, target − saved)`; `goalProgress` = `saved ÷ target`, clamped to 0–1. Goal notifications fire for active goals at ≥ 50% ("is N% funded") and ≥ 100% ("fully funded").

### Chance of Success (Monte Carlo)

`GoalForecastService` (`lib/features/overview/application/goal_forecast_service.dart`) feeds `MonteCarloEngine` (`lib/core/prediction/monte_carlo_engine.dart`). A goal is forecast only with a positive target amount and a target date that hasn't passed; otherwise `blockerFor` returns why (`GoalForecastBlocker`) and the screen shows an empty state naming what's missing. Inputs:

| Input | Value |
| --- | --- |
| Months | Calendar months from today to the target date (minimum 1) |
| Monthly contribution | The goal account's average monthly net deposit (deposits − withdrawals, as they move its balance) over the current month and the 5 before it, or from the month of its first transaction when that is later. Voided, archived and other-currency rows are ignored; a negative average counts as 0 |
| Expected annual return | 6% |
| Annual volatility | 12% |
| Iterations | 1,000 |
| Random seed | 42 (`MonteCarloEngine.run`), so the same inputs always give the same odds |

Each run compounds monthly: `balance = balance × (1 + r) + contribution`, with `r ~ Normal(6%/12, 12%/√12)` drawn by Box–Muller. Results:

- **Probability**: share of runs ending at or above the target. A goal already at or above its target is 100% without simulating.
- **Conservative / expected / optimistic**: the 10th, 50th and 90th percentile final balances.

The forecast is cached per goal ID (`goalForecastProvider`), so the 1,000 runs aren't repeated on every rebuild.

## Investments

`AllocationService` (`lib/features/investments/application/allocation_service.dart`):

| Output | Rule |
| --- | --- |
| Allocation | Market value per asset class ÷ total market value × 100, largest first. Holdings are first converted to the base currency (`valueHoldingsIn`); holdings with no rate are left out |
| Holding drift | `|actual % − target %| > 5` (default tolerance) |
| Rebalance alert | Per target asset class, drift beyond the tolerance, with signed drift |
| Capital gains on sale | proceeds = sale price × quantity; cost basis = average cost × quantity; gain = proceeds − cost basis. The quantity must be within the holding. |

## Calculators

Formulas live in `CalculatorServices` (`lib/features/calculators/application/calculator_services.dart`); Thai tax and social security rules in `ThaiIncomeTax` and `ThaiSocialSecurity` (`thai_tax_rules.dart`). They are plain `double` estimates. Rates are fractions (5% → 0.05); loans and savings compound monthly unless noted.

| Calculator | Formula |
| --- | --- |
| Compound interest, Time value of money (future value) | Each month: (value + contribution) × (1 + rate/12) |
| Time value of money (present value) | FV ÷ (1 + rate/12)^(12 × years) |
| Time value of money (monthly saving) | FV × r ÷ ((1 + r)^n − 1), saving at the end of each month |
| Loan, Annuity payout | Payment = P × r(1 + r)^n ÷ ((1 + r)^n − 1); P ÷ n at 0% |
| IRR / NPV | NPV = Σ CFₜ ÷ (1 + rate)^t; IRR by bisection between −99% and 1,000%, none when the flows don't change sign |
| Fixed deposit | Simple interest P × rate × months/12, less the withholding tax (15% in Thailand) |
| Bond yield | Price = Σ coupon ÷ (1 + y/k)^t + face ÷ (1 + y/k)^n with k coupons a year; yield to maturity by bisection |
| Bi-weekly mortgage | Half the monthly payment every two weeks at rate/26 until paid off |
| Refinance savings | Payments left on the current loan − (new payments + costs); break-even = costs ÷ monthly saving, rounded up |
| Rent vs. buy | Buying: down payment + loan payments + yearly ownership costs (share of the growing home value) − equity (home value − loan balance). Renting: rent rising yearly − what the down payment would have earned |
| Home affordability | Payment limit = income × debt ratio − other debts; loan = present value of that payment over the term; price = loan + down payment |
| Rental property cash flow | Rent × (1 − vacancy) − costs − loan payment; cap rate = yearly net operating income ÷ price; gross yield = yearly rent ÷ price |
| Car hire purchase vs. lease | Interest = financed × flat rate × years; installment = (financed + interest) ÷ months; effective rate = the reducing-balance rate with that installment; buying = down payment + installments − resale value; leasing = lease payment × months |
| WACC | E/V × cost of equity + D/V × cost of debt × (1 − tax) |
| CAPM | Risk-free + β × (market − risk-free) |
| Black-Scholes | European call and put with continuous dividend yield; normal CDF by Abramowitz–Stegun 7.1.26 |
| Retirement drawdown | Withdraw monthly, raise the withdrawal by inflation every 12 months, grow the rest at (1 + return)^(1/12) − 1; stops at 100 years |

### Thai rules

Amounts in baht per tax year. Update `thai_tax_rules.dart` and its tests when the law changes.

- **Personal income tax**: 0% to 150,000, then 5% to 300,000, 10% to 500,000, 15% to 750,000, 20% to 1,000,000, 25% to 2,000,000, 30% to 5,000,000 and 35% above. Employment income deducts 50% as expenses (at most 100,000) and the 60,000 personal allowance; *Income tax* also deducts 12 months of social security and the other deductions entered, and spreads the year's tax (bonus included) over 12 months of salary. The top bracket is the rate on the next baht.
- **Capital gains tax**: gains on shares sold on the Stock Exchange of Thailand and on Thai mutual fund units are exempt for individuals. Other gains (for example foreign shares, taxable when brought into Thailand) are taxed as tax(other net income + gain) − tax(other net income).
- **Tax-saving funds**: the deduction is the purchase up to 30% of income, at most 500,000 for RMF (shared with other retirement savings) or 300,000 for Thai ESG (the terms for purchases through 2026; they are due to tighten from 2027, so update the cap then). The yearly saving is tax(net income) − tax(net income − deduction). The fund and the reinvested refunds grow at the same return; the comparison is the same purchases without the deduction.
- **Social Security pension (Section 33)**: wages count up to the ceiling (17,500 from 2026, 15,000 before; the default, editable). *Income tax* starts social security at 875 (5% of 17,500). From 180 months of contributions: a monthly pension of 20% of the average wage of the last 60 months, plus 1.5% for each full 12 months beyond 180. Below 180 months: a lump sum of 3% of the wage per month (the worker's old-age share), or 6% from 12 months (with the employer's), before the fund's returns.

## Cloud AI tools

Server-side tools compute with `decimal.js` and return decimal strings ([Backend](backend.md#aikochat)):

- `aiko_account_summary`: net worth per currency: the sum of signed balances (debts are already negative) of active non-goal accounts included in net worth.
- `aiko_budget_status`: spend per budgeted category in the budget's currency over a date range.
- `aiko_spending_by_category`: expenses per category and currency, highest first, top 50.
- `aiko_cashflow_summary`: income, expense and net per currency.
- `aiko_recent_transactions`: newest first, 1–50 rows.
- `aiko_goal_progress`: current/target and fraction complete per goal.
