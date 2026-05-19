import 'package:aiko/core/money/money.dart';
import 'package:aiko/features/credit_cards/application/credit_card_metrics_service.dart';
import 'package:aiko/features/credit_cards/domain/credit_card_detail.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('calculates utilization and monthly interest estimate', () {
    final card = CreditCardDetail(
      id: 'card',
      userId: 'user',
      accountId: 'account',
      statementBalance: Money.parse('500', 'USD'),
      paymentDueDate: DateTime.utc(2026, 6),
      creditLimit: Money.parse('2000', 'USD'),
      aprPercent: 24,
    );

    expect(card.utilizationPercent, 25);
    expect(
      const CreditCardMetricsService()
          .estimateMonthlyInterest(card)
          .amount
          .toDouble(),
      closeTo(10, 0.01),
    );
  });
}
