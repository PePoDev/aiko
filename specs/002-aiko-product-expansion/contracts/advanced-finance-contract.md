# Contract: Advanced Finance Modules

## Purpose

Define user-facing expectations for bills, subscriptions, credit cards, debt, loans, portfolio, assets, net worth, tax, accounting, and business mode.

## Required Shared Fields

Each advanced finance module must define:

- ownership,
- source data,
- freshness,
- lifecycle state,
- empty state,
- error state,
- accessibility behavior,
- export behavior,
- disclaimer needs.

## Credit And Debt Contract

Credit/debt modules must show payment status, risk warnings, payoff assumptions, projected payoff date, and interest impact without guaranteeing outcomes.

## Portfolio And Asset Contract

Portfolio modules must show value, allocation, gains/losses, source-data age, drift status, and investment disclaimers.

## Tax And Accounting Contract

Tax/accounting modules must distinguish organization and estimates from certified advice. Country-specific rules must be explicitly scoped before use.
