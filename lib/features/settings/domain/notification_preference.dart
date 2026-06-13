enum NotificationType {
  recurringDue,
  creditCardDue,
  budgetThreshold,
  goalMilestone,
  lowBalance,
  unusualSpending,
  taxDeadline,
  portfolioDrift,
  aikoReviewReady,
}

enum NotificationSourceModule {
  recurring,
  creditCards,
  budgets,
  goals,
  accounts,
  transactions,
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
