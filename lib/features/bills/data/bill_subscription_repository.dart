import '../domain/bill_subscription.dart';

class BillSubscriptionRepository {
  BillSubscriptionRepository([List<BillSubscription>? initialBills])
    : _bills = [...?initialBills];

  final List<BillSubscription> _bills;

  List<BillSubscription> list() => List.unmodifiable(_bills);

  void save(BillSubscription bill) {
    _bills.add(bill);
  }
}
