# Contract: Aiko Assistant And Insights

## Purpose

Define how Aiko guidance, insights, and chat-like responses behave before AI implementation details are chosen.

## Consent Contract

Aiko may analyze sensitive user financial data only when:

- User is authenticated.
- User has granted AI consent.
- The relevant feature has access to required source data.
- The response includes the appropriate financial, tax, investment, or AI disclaimer when needed.

If consent is disabled, Aiko may provide generic education but must not analyze personal data.

## Insight Types

- **Descriptive**: What happened.
- **Diagnostic**: Why it likely happened.
- **Predictive**: What may happen if the pattern continues.
- **Prescriptive**: What action could improve the outcome.

## Insight Record Contract

Each Aiko insight includes:

- `insight_type`.
- `title`.
- `description`.
- `recommendation`.
- `confidence_score`.
- `source_data_summary`.
- `related_entity_type`.
- `related_entity_id`.
- `created_at`.
- User actions: view, dismiss, apply, mute, rate helpful, rate not helpful.

## Response Contract

Aiko responses must include:

- Direct answer when data is sufficient.
- Short explanation in user-friendly language.
- Source summary explaining why the response appears.
- Clear next step when applicable.
- Disclaimer when the response includes financial, tax, investment, or AI estimate guidance.

## Missing Data Contract

When Aiko cannot answer reliably, it must:

- Say what data is missing.
- Avoid guessing.
- Offer a concrete next action, such as add income, add bills, create a budget, create a goal, or enable consent.

## Example Response Shapes

### Safe-To-Spend

```json
{
  "type": "safe_to_spend",
  "answer": "You have 245.00 USD safe to spend this week.",
  "explanation": "This reserves your bills, planned savings, goal contributions, and current spending.",
  "source_summary": ["monthly_income", "fixed_bills", "goal_contributions", "posted_transactions"],
  "recommendation": "Keep flexible spending under 35.00 USD per day to stay on track.",
  "disclaimer": "This is an estimate based on the data in Aiko."
}
```

### Missing Data

```json
{
  "type": "missing_data",
  "answer": "I need your income and upcoming bills before I can estimate safe-to-spend.",
  "missing_data": ["income", "upcoming_bills"],
  "next_step": "Add monthly income or create recurring bills."
}
```

## Safety Contract

Aiko must not:

- Present estimates as guarantees.
- Provide certified financial, tax, legal, or investment advice.
- Shame the user.
- Reveal hidden raw identifiers or backend implementation details.
- Use sensitive financial data without consent.

## Initial MVP Behavior

MVP Aiko can be rule-driven:

- Budget threshold warning.
- Pace warning.
- Leftover explanation.
- Goal contribution suggestion.
- Spending increase summary.
- Missing data prompt.
- Calculator explanation.

The same contract can later support LLM-generated explanations if source summaries, consent, disclaimers, and user controls are preserved.
