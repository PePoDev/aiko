import '../../../core/money/money.dart';

enum BillingCycle { weekly, monthly, yearly }

enum CancellationStatus { active, reviewing, canceled }

class BillSubscription {
  BillSubscription({
    this.id = 'bill',
    this.userId = 'local',
    required this.merchant,
    required this.amount,
    required this.billingCycle,
    DateTime? nextDueDate,
    DateTime? nextBillingDate,
    this.categoryId,
    this.reminderEnabled = true,
    this.cancellationStatus = CancellationStatus.active,
    this.isActive = true,
  }) : nextDueDate = nextDueDate ?? nextBillingDate ?? DateTime.now();

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

  DateTime get nextBillingDate => nextDueDate;

  double get annualizedCost {
    final value = amount.amount.toDouble();
    return switch (billingCycle) {
      BillingCycle.weekly => value * 52,
      BillingCycle.monthly => value * 12,
      BillingCycle.yearly => value,
    };
  }

  bool isDueWithin(DateTime now, Duration window) {
    final end = now.add(window);
    return !nextDueDate.isBefore(now) && !nextDueDate.isAfter(end);
  }
}
