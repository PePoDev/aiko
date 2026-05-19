enum NotificationType {
  billDue,
  creditCardDue,
  budgetThreshold,
  goalMilestone,
  lowBalance,
  unusualSpending,
  subscriptionRenewal,
  taxDeadline,
  portfolioDrift,
  aikoReviewReady,
}

enum NotificationSourceModule {
  bills,
  creditCards,
  budgets,
  goals,
  accounts,
  transactions,
  subscriptions,
  tax,
  portfolio,
  reports,
}

class NotificationPreference {
  const NotificationPreference({
    required this.userId,
    required this.type,
    required this.sourceModule,
    required this.isEnabled,
  });

  final String userId;
  final NotificationType type;
  final NotificationSourceModule sourceModule;
  final bool isEnabled;
}
