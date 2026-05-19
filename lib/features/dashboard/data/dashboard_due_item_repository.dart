import '../../../core/money/money.dart';
import '../../bills/domain/bill_subscription.dart';
import '../../credit_cards/domain/credit_card_detail.dart';
import '../application/dashboard_due_item_service.dart';
import '../domain/dashboard_due_item.dart';

class DashboardDueItemRepository {
  DashboardDueItemRepository({
    DashboardDueItemService service = const DashboardDueItemService(),
  }) : _service = service;

  final DashboardDueItemService _service;

  Future<List<DashboardDueItem>> loadUpcomingItems(DateTime asOf) async {
    return _service.upcomingItems(
      bills: [
        BillSubscription(
          id: 'internet',
          userId: 'demo-user',
          merchant: 'Internet',
          amount: Money.parse('60', 'USD'),
          billingCycle: BillingCycle.monthly,
          nextDueDate: asOf.add(const Duration(days: 5)),
        ),
      ],
      creditCards: [
        CreditCardDetail(
          id: 'card',
          userId: 'demo-user',
          accountId: 'card-account',
          statementBalance: Money.parse('320', 'USD'),
          paymentDueDate: asOf.add(const Duration(days: 8)),
        ),
      ],
      asOf: asOf,
    );
  }
}
