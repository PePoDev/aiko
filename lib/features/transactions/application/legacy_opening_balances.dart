import 'package:flutter/widgets.dart';

import '../../../core/money/money.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/transaction.dart';

/// Opening balances recorded before they became adjustments: an `income`
/// (positive balance) or `expense` (negative balance) row with the "Initial
/// balance" merchant and note, in English or Thai. Returns each as a signed
/// `adjustment`, which changes the account balance by the same amount but no
/// longer counts as income or spending.
List<FinanceTransaction> legacyOpeningBalanceFixes(
  Iterable<FinanceTransaction> transactions,
) {
  final markers = [
    for (final code in ['en', 'th']) lookupAppLocalizations(Locale(code)),
  ];
  final merchants = {
    for (final l10n in markers) l10n.accountFormInitialBalance,
  };
  final notes = {
    for (final l10n in markers) l10n.accountFormInitialBalanceNote,
  };
  return [
    for (final transaction in transactions)
      if ((transaction.type == TransactionType.income ||
              transaction.type == TransactionType.expense) &&
          merchants.contains(transaction.merchant) &&
          notes.contains(transaction.note))
        transaction.copyWith(
          type: TransactionType.adjustment,
          amount: transaction.type == TransactionType.expense
              ? Money(
                  amount: -transaction.amount.amount.abs(),
                  currency: transaction.amount.currency,
                )
              : Money(
                  amount: transaction.amount.amount.abs(),
                  currency: transaction.amount.currency,
                ),
        ),
  ];
}
