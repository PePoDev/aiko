import '../../../core/money/money.dart';

enum GoalPurpose {
  emergencyFund,
  debtPayoff,
  investment,
  vacation,
  education,
  home,
  car,
  wedding,
  retirement,
  custom,
}

enum GoalStatus { active, paused, completed, archived }

class Goal {
  const Goal({
    required this.id,
    required this.userId,
    required this.name,
    required this.purpose,
    required this.targetAmount,
    required this.currentAmount,
    required this.targetDate,
    this.linkedAccountId,
    this.priority = 1,
    this.successProbability,
    this.status = GoalStatus.active,
  });

  final String id;
  final String userId;
  final String name;
  final GoalPurpose purpose;
  final Money targetAmount;
  final Money currentAmount;
  final DateTime targetDate;
  final String? linkedAccountId;
  final int priority;
  final double? successProbability;
  final GoalStatus status;

  double get progress {
    return currentAmount.amount.toDouble() / targetAmount.amount.toDouble();
  }

  Money get remaining => targetAmount - currentAmount;
}
