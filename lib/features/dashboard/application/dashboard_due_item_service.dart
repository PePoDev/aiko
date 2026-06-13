import '../../credit_cards/domain/credit_card_detail.dart';
import '../domain/dashboard_due_item.dart';

class DashboardDueItemService {
  const DashboardDueItemService();

  List<DashboardDueItem> upcomingItems({
    required List<CreditCardDetail> creditCards,
    required DateTime asOf,
    int windowDays = 30,
  }) {
    final end = asOf.add(Duration(days: windowDays));
    final items = <DashboardDueItem>[
      for (final card in creditCards)
        if (card.hasPaymentDue &&
            !card.paymentDueDate.isBefore(asOf) &&
            !card.paymentDueDate.isAfter(end))
          DashboardDueItem(
            id: card.id,
            title: 'Credit card payment',
            amount: card.statementBalance,
            dueDate: card.paymentDueDate,
            kind: DashboardDueItemKind.creditCard,
          ),
    ];

    items.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return items;
  }
}
