import '../../../core/money/money.dart';

enum ContributionFrequency { weekly, monthly }

class SavingPlan {
  const SavingPlan({
    required this.id,
    required this.userId,
    required this.goalId,
    required this.frequency,
    required this.requiredContribution,
    required this.forecastedCompletionDate,
  });

  final String id;
  final String userId;
  final String goalId;
  final ContributionFrequency frequency;
  final Money requiredContribution;
  final DateTime forecastedCompletionDate;
}
