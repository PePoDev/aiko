import '../../../core/money/money.dart';
import 'account_details.dart';
import 'account_type.dart';

export 'account_type.dart';

class Account {
  const Account({
    required this.id,
    required this.userId,
    required this.name,
    required this.type,
    required this.currentBalance,
    this.institution,
    this.includeInNetWorth = true,
    this.isActive = true,
    this.details,
    this.targetAmount,
    this.targetDate,
    this.priority = GoalPriority.medium,
  });

  final String id;
  final String userId;
  final String name;
  final AccountType type;
  final Money currentBalance;
  final String? institution;
  final bool includeInNetWorth;
  final bool isActive;
  final AccountDetails? details;

  /// Required when [type] is [AccountType.goal]. The savings target.
  /// Null for non-goal accounts.
  final Money? targetAmount;

  /// Required when [type] is [AccountType.goal]. The date the user wants to
  /// reach the target by. Null for non-goal accounts.
  final DateTime? targetDate;

  /// Priority for goal accounts. Defaults to [GoalPriority.medium]. Ignored
  /// for non-goal accounts.
  final GoalPriority priority;

  String get currency => currentBalance.currency;

  AccountDetails get resolvedDetails =>
      details ?? AccountDetails.defaultFor(type);

  /// `true` for accounts that represent a SMART savings goal. Goal accounts
  /// use [currentBalance] as the saved amount and require [targetAmount] /
  /// [targetDate] to be set.
  bool get isGoal => type == AccountType.goal;

  /// Money still to save to reach [targetAmount]. Returns [Money.zero] for
  /// non-goal accounts or when the target is null.
  Money get goalRemaining {
    final target = targetAmount;
    if (target == null) return Money.zero(currentBalance.currency);
    final diffAmount = target.amount - currentBalance.amount;
    final zero = _zeroFor(currentBalance.currency);
    if (diffAmount <= zero.amount) return zero;
    return Money(amount: diffAmount, currency: currentBalance.currency);
  }

  double get goalProgress {
    final target = targetAmount;
    if (target == null || target.amount <= _zeroFor(target.currency).amount) {
      return 0;
    }
    final ratio = currentBalance.amount.toDouble() / target.amount.toDouble();
    if (ratio.isNaN || ratio.isInfinite) return 0;
    return ratio.clamp(0.0, 1.0).toDouble();
  }

  Account copyWith({
    String? name,
    AccountType? type,
    Money? currentBalance,
    String? institution,
    bool? includeInNetWorth,
    bool? isActive,
    AccountDetails? details,
    bool resetDetails = false,
    Object? targetAmount = _accountUnset,
    Object? targetDate = _accountUnset,
    GoalPriority? priority,
  }) {
    return Account(
      id: id,
      userId: userId,
      name: name ?? this.name,
      type: type ?? this.type,
      currentBalance: currentBalance ?? this.currentBalance,
      institution: institution ?? this.institution,
      includeInNetWorth: includeInNetWorth ?? this.includeInNetWorth,
      isActive: isActive ?? this.isActive,
      details: resetDetails
          ? AccountDetails.defaultFor(type ?? this.type)
          : (details ?? this.details),
      targetAmount: identical(targetAmount, _accountUnset)
          ? this.targetAmount
          : targetAmount as Money?,
      targetDate: identical(targetDate, _accountUnset)
          ? this.targetDate
          : targetDate as DateTime?,
      priority: priority ?? this.priority,
    );
  }
}

const Object _accountUnset = Object();

Money _zeroFor(String currency) => Money.zero(currency);
