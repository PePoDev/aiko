# Calculations

Every number Aiko shows, the code that computes it, and the exact rule. Services are pure function objects in `application/` folders with unit tests in `test/features/`. Change the formula and its test together, and update this page.

General rules:

- Money math uses `Decimal` through `Money`. Ratios, percentages, the Monte Carlo engine, investment percentages and calculators use `double`; their results are estimates or display values, never stored balances.
- A "month" runs from the first day 00:00 to the last day 23:59:59.999 in the device's local time.
- Most views take the currency of the first record they find and add amounts without converting currencies ([Known gaps](features.md#known-gaps)).

## Account balances

`FinanceTransaction.applyToAccountBalance` / `reverseFromAccountBalance` (`lib/features/transactions/domain/transaction.dart`):

```text
inflow  (income, transferIn):  balance + amount
outflow (every other type):    balance - amount
currency ≠ account currency:   balance unchanged
```

- **Save** (`TransactionsNotifier.saveTransaction`): reverse the previous version from its old account, then apply the new version to its account, and save only the accounts whose balance changed.
- **Delete**: reverse the transaction from its account.
- **Reconcile on load** (`TransactionsNotifier.build`): for every account with at least one transaction, recompute the balance from zero by applying all its transactions; save it if it differs. Accounts with no transactions keep their manual balance.

### Sign convention and the Accounts summary

Balances are signed: money you have is positive, money you owe (a used credit card, a loan) is negative, because expenses subtract from the balance. The **Accounts** screen summary (`_computeAssetsLiabilities` in `accounts_screen.dart`) uses net-worth accounts in the base currency only. It counts positive balances as assets and the absolute value of negative balances as liabilities, so assets − liabilities = net worth.

## Dashboard summary

`dashboardSummaryProvider` (`lib/app/providers.dart`), current calendar month, active accounts only:

| Figure | Rule |
| --- | --- |
| Net worth | Sum of signed `current_balance` over active non-goal accounts with `include_in_net_worth`, all currencies added together |
| Total cash | Sum over active `cash` and `bank` accounts |
| Monthly income | Sum of `income` transactions this month |
| Monthly spending | Sum of `expense` transactions this month |
| Safe to spend (weekly) | `max(0, (income − spending) ÷ 4.33)`, rounded to 2 decimals |

## Daily spending reaction

`_DailySpendingPanel` (`lib/features/dashboard/presentation/home_dashboard_screen.dart`) and `DailySpendingReaction` (`lib/features/dashboard/domain/daily_spending_reaction.dart`):

```text
used       = today's posted expenses (in the first currency found today)
daily safe = weekly safe to spend ÷ 7
ratio      = used ÷ daily safe   (0 when daily safe ≤ 0)
```

| Ratio | Reaction | Color |
| --- | --- | --- |
| < 0.75 | comfortable | green |
| 0.75 – < 1 | caution | orange |
| ≥ 1 | exceeded | red |

The panel also shows the month's net cash flow (income − spending) and "left to save" (net cash flow − weekly safe to spend).

## Safe-to-spend breakdown

`BudgetInsightsService.safeToSpend` (`lib/features/overview/application/budget_insights_service.dart`), current month:

```text
reserved  = Σ over budgeted categories of max(0, limit − this month's spend in that category)
leftover  = income − spent − reserved
daysRemaining = days left in the month, including today
```

## Category budget progress

`CategoryBudgetProgressService` (`lib/features/categories/application/category_budget_progress_service.dart`) sums expenses in the category over its period:

| Period | Window |
| --- | --- |
| daily | today 00:00 – 23:59:59 |
| weekly | Monday – Sunday of the current week |
| monthly | calendar month |
| yearly | calendar year |

The recommendation is "Keep this category under `remaining ÷ daysLeft` `<currency>`/day to stay on track", or a gentle over-budget message. Budget **notifications** use this month's posted expenses against the category limit and fire at the highest crossed threshold (default 50/75/90/100%). They are warnings below 100% and danger at 100% or more.

## Cash flow

`CashFlowService` (`lib/features/overview/application/cash_flow_service.dart`):

| Set | Transaction types |
| --- | --- |
| Inflow | `income`, `refund`, `dividend`, `interest`, `investmentSell` |
| Outflow | `expense`, `investmentBuy`, `loanPayment`, `creditCardPayment`, `taxPayment`, `fee` |

Transfers between your own accounts are excluded from both sets.

- **Overview**: this month's `income` and `expense` totals and their difference, plus a 12-month trend of net = inflow − outflow per month.
- **Sankey**: this month's inflow total, and outflow grouped by each category's 50/30/20 bucket (`needs`, `wants`, `savings`, `debt`, …; uncategorized → `custom`).

## Monthly report

`MonthlyReportService` (`lib/features/overview/application/monthly_report_service.dart`) compares this month with last month:

- income, expenses, net cash flow, saved (`max(0, net)`), savings rate (net ÷ income);
- percentage change for income, expenses and net against last month;
- spending by category, top 5 slices with the rest folded into "Other".

## Upcoming bills

`buildDashboardDueItems` (`lib/features/dashboard/domain/dashboard_due_item.dart`): for each active credit card with a positive amount due (minimum payment, else current balance), the next occurrence of its due day, clamped to the month's length. Items due within 30 days are listed. Bill **notifications** fire for items due within 7 days: warning at 2 days or less, info otherwise.

## Goals

`Account.goalRemaining` = `max(0, target − saved)`; `goalProgress` = `saved ÷ target`, clamped to 0–1. Goal notifications fire at ≥ 50% ("is N% funded") and ≥ 100% ("fully funded").

### Chance of Success (Monte Carlo)

`GoalForecastService` (`lib/features/overview/application/goal_forecast_service.dart`) feeds `MonteCarloEngine` (`lib/core/prediction/monte_carlo_engine.dart`):

| Input | Value |
| --- | --- |
| Months | Whole months from today to the target date (minimum 1; 12 when no date) |
| Monthly contribution | Remaining ÷ months; 100 when the goal is already met |
| Expected annual return | 6% |
| Annual volatility | 12% |
| Iterations | 1,000 |

Each run compounds monthly: `balance = balance × (1 + r) + contribution`, with `r ~ Normal(6%/12, 12%/√12)` drawn by Box–Muller. Results:

- **Probability**: share of runs ending at or above the target.
- **Conservative / expected / optimistic**: the 10th, 50th and 90th percentile final balances.

The forecast is cached per goal ID (`goalForecastProvider`), so the 1,000 runs aren't repeated on every rebuild.

## Investments

`AllocationService` (`lib/features/investments/application/allocation_service.dart`):

| Output | Rule |
| --- | --- |
| Allocation | Market value per asset class ÷ total market value × 100, largest first |
| Holding drift | `|actual % − target %| > 5` (default tolerance) |
| Rebalance alert | Per target asset class, drift beyond the tolerance, with signed drift |
| Capital gains on sale | proceeds = sale price × quantity; cost basis = average cost × quantity; gain = proceeds − cost basis. The quantity must be within the holding. |

## Calculators

`CalculatorServices` (`lib/features/calculators/application/calculator_services.dart`) and `CalculatorDetailScreen` implement compound interest with monthly contributions, loan payment (amortization), credit card payoff, savings goal pace, ROI, currency conversion, Rule of 72, inflation-adjusted value, salary to hourly, tax-equivalent yield, NPV/IRR and tip. They are plain `double` estimates.

## Cloud AI tools

Server-side tools compute with `decimal.js` and return decimal strings ([Backend](backend.md#aikochat)):

- `aiko_account_summary`: net worth per currency. It multiplies `loan`, `liability` and `creditCard` balances by −1, which double-negates debts the app already stores as negative ([Known gaps](features.md#known-gaps)).
- `aiko_budget_status`: spend per budgeted category in the budget's currency over a date range.
- `aiko_spending_by_category`: expenses per category and currency, highest first, top 50.
- `aiko_cashflow_summary`: income, expense and net per currency.
- `aiko_recent_transactions`: newest first, 1–50 rows.
- `aiko_goal_progress`: current/target and fraction complete per goal.
