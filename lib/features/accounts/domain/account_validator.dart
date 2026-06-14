import 'account.dart';
import 'account_details.dart';
import 'account_type.dart';
import 'account_validation_exception.dart';
import 'account_validation_messages.dart';

abstract final class AccountValidator {
  /// Pure invariants on the account itself.
  static void _checkPureInvariants(Account a) {
    final d = a.resolvedDetails;
    switch (d) {
      case CashDetails():
        break;
      case BankDetails():
        break;
      case EWalletDetails():
        break;
      case InvestmentDetails():
        break;
      case LiabilityDetails():
        final li = d;
        if (li.interestRatePercent != null && li.interestRatePercent! < 0) {
          throw const AccountValidationException(
            'interestRatePercent',
            AccountValidationMessages.aprNegative,
          );
        }
      case OtherDetails():
        break;
      case AssetDetails():
        final as = d;
        if (as.purchasePrice != null && as.purchaseDate == null) {
          throw const AccountValidationException(
            'purchaseDate',
            AccountValidationMessages.purchaseDateRequired,
          );
        }
      case CreditCardDetails():
        final cc = d;
        if (cc.statementDay < 1 || cc.statementDay > 31) {
          throw const AccountValidationException(
            'statementDay',
            AccountValidationMessages.statementDayRange,
          );
        }
        if (cc.dueDay < 1 || cc.dueDay > 31) {
          throw const AccountValidationException(
            'dueDay',
            AccountValidationMessages.dueDayRange,
          );
        }
        if (cc.aprPercent != null && cc.aprPercent! < 0) {
          throw const AccountValidationException(
            'aprPercent',
            AccountValidationMessages.aprNegative,
          );
        }
        if (cc.sharesLimit) {
          if (cc.sharedLimitAccountId == null) {
            throw const AccountValidationException(
              'sharedLimitAccountId',
              AccountValidationMessages.sharedLimitReferenceRequired,
            );
          }
          if (cc.sharedLimitAccountId == a.id) {
            throw const AccountValidationException(
              'sharedLimitAccountId',
              AccountValidationMessages.sharedLimitSelfReference,
            );
          }
        } else if (cc.creditLimit == null) {
          throw const AccountValidationException(
            'creditLimit',
            AccountValidationMessages.creditLimitRequired,
          );
        }
        final limit = cc.creditLimit;
        if (limit != null && limit.currency != a.currency) {
          throw const AccountValidationException(
            'creditLimit',
            AccountValidationMessages.creditLimitCurrencyMismatch,
          );
        }
      case LoanDetails():
        final l = d;
        if (l.termMonths <= 0) {
          throw const AccountValidationException(
            'termMonths',
            AccountValidationMessages.termMonthsPositive,
          );
        }
        if (l.interestRatePercent < 0) {
          throw const AccountValidationException(
            'interestRatePercent',
            AccountValidationMessages.aprNegative,
          );
        }
        if (l.principal.currency != a.currency ||
            l.monthlyPayment.currency != a.currency) {
          throw const AccountValidationException(
            'currency',
            AccountValidationMessages.loanCurrencyMismatch,
          );
        }
    }
  }

  /// Reference checks that need the broader accounts list.
  static void _checkReferences(Account a, List<Account> allAccounts) {
    final d = a.resolvedDetails;
    if (d is CreditCardDetails && d.sharesLimit) {
      final refId = d.sharedLimitAccountId;
      final found =
          refId != null &&
          allAccounts.any(
            (x) => x.id == refId && x.type == AccountType.creditCard,
          );
      if (!found) {
        throw const AccountValidationException(
          'sharedLimitAccountId',
          AccountValidationMessages.sharedLimitReferenceMissing,
        );
      }
    }
  }

  /// Validates [a] against its own invariants and any cross-account references
  /// resolved through [allAccounts]. Throws [AccountValidationException] on
  /// failure; returns normally on success.
  static void validate(Account a, {required List<Account> allAccounts}) {
    _checkPureInvariants(a);
    _checkReferences(a, allAccounts);
  }
}
