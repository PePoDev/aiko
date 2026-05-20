# Supabase Expansion Seed Data Notes

Seed data should support demos and contract tests without mixing synthetic data into production user accounts.

## Demo Profile Shape

- One demo user profile with USD base currency and supportive Aiko settings.
- Two accounts: checking and credit card.
- Ten sample transactions across food, income, subscriptions, tax, and investment categories.
- One budget, one goal, and one Aiko insight from the MVP seed set.

## Expansion Demo Records

- Aiko character profile with full visibility and professional tone.
- Import job in preview state with one duplicate warning.
- Export package in ready state with CSV scope.
- Bill subscription with upcoming due date and annualized cost.
- Credit card profile with utilization below warning threshold.
- Debt plan with avalanche strategy.
- Asset and investment holding for net-worth and allocation demos.
- Tax record marked estimate-only with document checklist state.
- Learning progress for one completed lesson.
- Device session marked current and trusted.
- Optimization suggestion with source summary and disclaimer.

## Guardrails

- Seed values must be clearly fictional.
- Never seed personal financial data from local developer files.
- Keep all demo rows tied to one known demo user id for cleanup.
