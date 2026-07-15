# Transaction Month Range Design

## Goal

Make the Transactions screen cover all available transaction history and at
least one year of future planning tabs so recurring transaction previews are
visible in advance.

## Month Range

The generated range is continuous and inclusive.

- The current month is always included and remains the initially selected tab.
- The first month is the earlier of the current month and the oldest saved
  transaction month.
- The last month is the later of 12 months after the current month and the
  newest saved transaction month.
- When there are no transactions, the range starts at the current month and
  ends 12 months later.

For example, with a current month of July 2026 and transactions dating back to
March 2024, the default range is March 2024 through July 2027. If a saved
transaction exists in September 2028, the continuous range extends through
September 2028.

## Architecture

Move the month-range calculation out of the Transactions widget into a small
pure application-layer service. The service accepts the saved transactions and
an explicit current date, then returns ordered month values for the UI. Passing
the current date explicitly keeps the logic deterministic in tests.

`TransactionListScreen` continues to own the `DefaultTabController`, labels,
month filtering, empty states, and current-month initial selection. It consumes
the service result instead of calculating a fixed historical window itself.

The existing `RecurringProjection` remains unchanged. Each generated future
month page already asks it for occurrences in that month, so extending the tab
range automatically exposes recurring previews through the next year.

## Data Flow

1. `transactionsProvider` supplies all saved transactions.
2. The month-range service normalizes the current date and transaction dates to
   calendar months.
3. It chooses the earliest required start and latest required end.
4. It produces every month between those boundaries in ascending order.
5. The Transactions screen creates one tab and page per returned month.
6. Each page filters real transactions for its month and adds existing
   recurring previews when search filters are inactive.

## Edge Cases

- Transactions older than one year extend the past boundary to the oldest
  transaction month.
- Transactions more than one year in the future extend the future boundary to
  the newest transaction month so saved records are never hidden.
- A future-only dataset still starts at the current month.
- Month arithmetic must cross December and January correctly.
- The range always contains at least the current month plus the following 12
  months.

## Testing and Validation

Follow the repository rule prohibiting widget tests. Add logic-only unit tests
for the month-range service covering:

- no transactions;
- history older than the current month;
- a future-only dataset;
- a saved transaction beyond the default 12-month future boundary;
- year-boundary month arithmetic; and
- ordered, inclusive output with the current month present.

Run targeted tests, the full `flutter test` suite, `flutter analyze`, and
targeted formatting for changed Dart files. No authentication, persistence,
recurrence, search, or transaction-form behavior changes are in scope.
