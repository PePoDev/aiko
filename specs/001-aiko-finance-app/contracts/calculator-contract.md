# Contract: Financial Calculators

## Purpose

Define first-release calculator behavior and saved scenario requirements.

## Shared Calculator Requirements

Each calculator must:

- Validate required inputs before calculation.
- Treat money as currency plus decimal amount.
- Show assumptions used by the formula.
- Show result, explanation, and next action.
- Allow save scenario.
- Allow optional notes.
- Allow conversion to a draft goal, budget, debt plan, or investment scenario where relevant.
- Provide Aiko explanation entry point.
- Avoid presenting projections as guarantees.

## Calculator Types

### Compound Interest

**Inputs**:
- Initial amount.
- Contribution amount.
- Contribution frequency.
- Annual return rate.
- Compounding frequency.
- Time period.
- Currency.

**Outputs**:
- Future value.
- Total contributions.
- Estimated interest earned.
- Period summary.

### Loan

**Inputs**:
- Principal.
- Annual interest rate.
- Term.
- Payment frequency.
- Start date.
- Currency.

**Outputs**:
- Payment amount.
- Total interest.
- Total repayment.
- Amortization summary.

### Credit Card Payoff

**Inputs**:
- Current balance.
- APR.
- Minimum payment.
- Extra payment.
- Payment frequency.
- Currency.

**Outputs**:
- Estimated payoff date.
- Total interest.
- Interest saved with extra payment.
- Suggested monthly payment.

### Savings Goal

**Inputs**:
- Target amount.
- Current amount.
- Target date.
- Contribution frequency.
- Expected return rate, optional.
- Currency.

**Outputs**:
- Required contribution.
- Forecasted completion date.
- Progress percentage.
- Shortfall or surplus.

### ROI

**Inputs**:
- Initial investment.
- Ending value.
- Fees.
- Income received.
- Time period.
- Currency.

**Outputs**:
- ROI percentage.
- Net gain or loss.
- Annualized return when time period allows.

### Currency Converter

**Inputs**:
- Source amount.
- Source currency.
- Target currency.
- Exchange rate.
- Rate date.

**Outputs**:
- Converted amount.
- Rate used.
- Conversion disclaimer.

## Saved Scenario Contract

Saved scenario record:

```json
{
  "calculator_type": "savings_goal",
  "input_json": {},
  "result_json": {},
  "notes": "Optional user note",
  "converted_entity_type": "goal",
  "converted_entity_id": "optional-linked-id"
}
```

## Acceptance Samples

Each calculator requires acceptance sample cases in tasks:

- One standard case.
- One zero-contribution or minimum-boundary case.
- One invalid-input case.
- One conversion-to-draft case when supported.

## Precision Contract

- Calculator inputs and outputs use decimal semantics.
- Display rounds according to currency formatting, but stored results retain enough precision to reproduce the calculation.
- Percentages include the displayed precision and raw calculation value in saved results.
