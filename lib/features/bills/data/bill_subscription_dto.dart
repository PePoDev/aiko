import '../../../core/money/money.dart';
import '../domain/bill_subscription.dart';

class BillSubscriptionDto {
  const BillSubscriptionDto(this.json);

  final Map<String, dynamic> json;

  BillSubscription toDomain() {
    return BillSubscription(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      merchant: json['merchant'] as String,
      amount: Money.parse(
        '${json['amount'] ?? 0}',
        json['currency'] as String? ?? 'USD',
      ),
      billingCycle: BillingCycle.values.byName(
        json['billing_cycle'] as String? ?? 'monthly',
      ),
      nextDueDate: DateTime.parse(json['next_due_date'] as String),
      categoryId: json['category_id'] as String?,
      reminderEnabled: json['reminder_enabled'] as bool? ?? true,
      cancellationStatus: CancellationStatus.values.byName(
        json['cancellation_status'] as String? ?? 'active',
      ),
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  static Map<String, dynamic> fromDomain(BillSubscription bill) => {
    'id': bill.id,
    'user_id': bill.userId,
    'merchant': bill.merchant,
    'amount': bill.amount.amount.toString(),
    'currency': bill.amount.currency,
    'billing_cycle': bill.billingCycle.name,
    'next_due_date': bill.nextDueDate.toIso8601String(),
    'category_id': bill.categoryId,
    'reminder_enabled': bill.reminderEnabled,
    'cancellation_status': bill.cancellationStatus.name,
    'is_active': bill.isActive,
  };
}
