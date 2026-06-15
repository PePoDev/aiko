import 'package:decimal/decimal.dart';

import '../../../core/money/money.dart';
import '../../accounts/domain/account.dart';
import '../../accounts/domain/account_details.dart';
import '../domain/credit_card_detail.dart';

class CreditCardMetricsService {
  const CreditCardMetricsService();

  Money estimateMonthlyInterest(CreditCardDetail card) {
    final apr = card.aprPercent ?? 0;
    if (apr <= 0) {
      return Money.zero(card.statementBalance.currency);
    }
    return card.statementBalance.times(Decimal.parse('${apr / 100 / 12}'));
  }

  Money suggestedMinimumPayment(CreditCardDetail card) {
    final explicit = card.minimumPayment;
    if (explicit != null) return explicit;
    return card.statementBalance.times(Decimal.parse('0.02'));
  }

  /// Returns the effective credit limit for [account]. If the account shares
  /// a limit with another card, the parent's limit is returned. Returns null
  /// when no limit is available.
  Money? effectiveLimit(Account account, {required List<Account> allAccounts}) {
    if (account.type != AccountType.creditCard) return null;
    final details = account.resolvedDetails;
    if (details is! CreditCardDetails) return null;
    if (details.creditLimit != null) return details.creditLimit;
    if (!details.sharesLimit) return null;
    final refId = details.sharedLimitAccountId;
    if (refId == null) return null;
    final parent = allAccounts.where((a) => a.id == refId).firstOrNull;
    if (parent == null) return null;
    return effectiveLimit(parent, allAccounts: allAccounts);
  }
}
