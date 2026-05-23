import '../../../core/money/money.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../domain/bill_subscription.dart';

class BillSubscriptionRepository {
  const BillSubscriptionRepository();

  Future<List<BillSubscription>> list() async {
    final session = AikoSupabase.requireSession();
    final response = await session.client
        .from('bill_subscriptions')
        .select()
        .eq('user_id', session.userId)
        .order('next_billing_date');

    return response
        .map((row) => _fromRow(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  Future<BillSubscription> save(BillSubscription bill) async {
    final session = AikoSupabase.requireSession();
    final billWithUser = BillSubscription(
      id: bill.id,
      userId: session.userId,
      merchant: bill.merchant,
      amount: bill.amount,
      billingCycle: bill.billingCycle,
      nextDueDate: bill.nextDueDate,
      categoryId: bill.categoryId,
      reminderEnabled: bill.reminderEnabled,
      cancellationStatus: bill.cancellationStatus,
      isActive: bill.isActive,
    );

    await session.client
        .from('bill_subscriptions')
        .upsert(_toRow(billWithUser));
    return billWithUser;
  }

  Future<void> delete(String id) async {
    final session = AikoSupabase.requireSession();
    await session.client
        .from('bill_subscriptions')
        .delete()
        .eq('id', id)
        .eq('user_id', session.userId);
  }

  static BillSubscription _fromRow(Map<String, dynamic> row) {
    final cycle = BillingCycle.values.firstWhere(
      (item) => item.name == row['billing_cycle'],
      orElse: () => BillingCycle.monthly,
    );
    final cancellationStatus = CancellationStatus.values.firstWhere(
      (item) =>
          item.name == (row['cancellation_status'] as String? ?? 'active'),
      orElse: () => CancellationStatus.active,
    );
    final currency = row['currency'] as String? ?? 'USD';

    return BillSubscription(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      merchant: row['merchant'] as String,
      amount: Money.parse('${row['amount'] ?? 0}', currency),
      billingCycle: cycle,
      nextDueDate: DateTime.parse(row['next_billing_date'] as String),
      categoryId: row['category_id'] as String?,
      cancellationStatus: cancellationStatus,
      isActive: cancellationStatus != CancellationStatus.canceled,
    );
  }

  static Map<String, dynamic> _toRow(BillSubscription bill) {
    return {
      'id': bill.id,
      'user_id': bill.userId,
      'merchant': bill.merchant,
      'amount': bill.amount.amount.toString(),
      'currency': bill.amount.currency,
      'billing_cycle': bill.billingCycle.name,
      'next_billing_date': bill.nextDueDate.toIso8601String().substring(0, 10),
      'category_id': bill.categoryId,
      'cancellation_status': bill.cancellationStatus.name,
    };
  }
}
