import '../../../l10n/app_localizations.dart';
import '../domain/account_validator.dart';

/// [AccountValidationMessages] (English, kept in the domain for logs and
/// tests) in the user's language.
String localizedAccountValidationMessage(
  String message,
  AppLocalizations l10n,
) => switch (message) {
  AccountValidationMessages.statementDayRange =>
    l10n.accountValidationStatementDayRange,
  AccountValidationMessages.dueDayRange => l10n.accountValidationDueDayRange,
  AccountValidationMessages.aprNegative => l10n.accountValidationAprNegative,
  AccountValidationMessages.creditLimitRequired =>
    l10n.accountValidationCreditLimitRequired,
  AccountValidationMessages.sharedLimitReferenceRequired =>
    l10n.accountValidationSharedLimitReferenceRequired,
  AccountValidationMessages.sharedLimitSelfReference =>
    l10n.accountValidationSharedLimitSelfReference,
  AccountValidationMessages.sharedLimitReferenceMissing =>
    l10n.accountValidationSharedLimitReferenceMissing,
  AccountValidationMessages.creditLimitCurrencyMismatch =>
    l10n.accountValidationCreditLimitCurrencyMismatch,
  AccountValidationMessages.termMonthsPositive =>
    l10n.accountValidationTermMonthsPositive,
  AccountValidationMessages.loanCurrencyMismatch =>
    l10n.accountValidationLoanCurrencyMismatch,
  AccountValidationMessages.purchaseDateRequired =>
    l10n.accountValidationPurchaseDateRequired,
  AccountValidationMessages.sharedLimitCardUnavailable =>
    l10n.accountValidationSharedLimitCardUnavailable,
  _ => message,
};
