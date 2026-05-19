import 'package:decimal/decimal.dart';

import '../../../core/money/money.dart';
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
    if (explicit != null) {
      return explicit;
    }

    return card.statementBalance.times(Decimal.parse('0.02'));
  }
}
