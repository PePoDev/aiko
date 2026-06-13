import 'package:aiko/core/money/money.dart';
import 'package:aiko/features/credit_cards/domain/credit_card_detail.dart';
import 'package:aiko/features/dashboard/application/dashboard_due_item_service.dart';
import 'package:aiko/features/dashboard/domain/dashboard_due_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps upcoming credit card due dates into sorted due items', () {
    const service = DashboardDueItemService();
    final asOf = DateTime(2026, 5, 19);

    final items = service.upcomingItems(
      creditCards: [
        CreditCardDetail(
          id: 'card',
          userId: 'user',
          accountId: 'account',
          statementBalance: Money.parse('300', 'USD'),
          paymentDueDate: DateTime(2026, 5, 22),
        ),
      ],
      asOf: asOf,
    );

    expect(items.single.kind, DashboardDueItemKind.creditCard);
    expect(items.single.title, 'Credit card payment');
    expect(items.single.daysUntil(asOf), 3);
  });

  test('excludes zero-balance credit cards', () {
    const service = DashboardDueItemService();

    final items = service.upcomingItems(
      creditCards: [
        CreditCardDetail(
          id: 'paid',
          userId: 'user',
          accountId: 'account',
          statementBalance: Money.zero('USD'),
          paymentDueDate: DateTime(2026, 5, 20),
        ),
      ],
      asOf: DateTime(2026, 5, 19),
    );

    expect(items, isEmpty);
  });
}
