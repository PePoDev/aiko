abstract final class AccountValidationMessages {
  static const statementDayRange = 'Statement day must be between 1 and 31.';
  static const dueDayRange = 'Due day must be between 1 and 31.';
  static const aprNegative = 'APR cannot be negative.';
  static const creditLimitRequired =
      'Enter a credit limit or turn on shared limit.';
  static const sharedLimitReferenceRequired =
      'Pick a card to share the limit with.';
  static const sharedLimitSelfReference =
      'A card cannot share its own limit.';
  static const sharedLimitReferenceMissing =
      'The referenced card no longer exists.';
  static const creditLimitCurrencyMismatch =
      'Credit limit currency must match the account currency.';
  static const termMonthsPositive = 'Term must be at least 1 month.';
  static const loanCurrencyMismatch =
      'All loan amounts must use the same currency.';
  static const purchaseDateRequired = 'Add a purchase date with the price.';
  static const sharedLimitCardUnavailable =
      'Referenced card is no longer available.';
}
