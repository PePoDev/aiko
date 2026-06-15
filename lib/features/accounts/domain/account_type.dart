enum AccountType {
  cash,
  bank,
  eWallet,
  creditCard,
  loan,
  investment,
  asset,
  liability,
  goal,
  other,
}

/// Priority for a [AccountType.goal] account. Defaults to medium.
enum GoalPriority { high, medium, low }
