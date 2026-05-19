import '../../../core/money/money.dart';

class CreditCardDetail {
  const CreditCardDetail({
    required this.id,
    required this.userId,
    required this.accountId,
    required this.statementBalance,
    required this.paymentDueDate,
    this.creditLimit,
    this.aprPercent,
    this.rewardsSummary,
  });

  final String id;
  final String userId;
  final String accountId;
  final Money statementBalance;
  final DateTime paymentDueDate;
  final Money? creditLimit;
  final double? aprPercent;
  final String? rewardsSummary;

  bool get hasPaymentDue => statementBalance.isPositive;
}
