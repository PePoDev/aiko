import '../../../core/money/money.dart';

enum BillingCycle { weekly, monthly, quarterly, yearly, custom }

enum CancellationStatus { active, canceling, canceled, unknown }

class BillSubscription {
  const BillSubscription({
    required this.id,
    required this.userId,
    required this.merchant,
    required this.amount,
    required this.billingCycle,
    required this.nextDueDate,
    this.categoryId,
    this.reminderEnabled = true,
    this.cancellationStatus = CancellationStatus.active,
    this.isActive = true,
  });

  final String id;
  final String userId;
  final String merchant;
  final Money amount;
  final BillingCycle billingCycle;
  final DateTime nextDueDate;
  final String? categoryId;
  final bool reminderEnabled;
  final CancellationStatus cancellationStatus;
  final bool isActive;

  int daysUntil(DateTime asOf) => nextDueDate.difference(asOf).inDays;
}
