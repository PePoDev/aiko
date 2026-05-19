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
    this.minimumPayment,
    this.annualFee,
  });

  final String id;
  final String userId;
  final String accountId;
  final Money statementBalance;
  final DateTime paymentDueDate;
  final Money? creditLimit;
  final double? aprPercent;
  final String? rewardsSummary;
  final Money? minimumPayment;
  final Money? annualFee;

  bool get hasPaymentDue => statementBalance.isPositive;

  double get utilizationPercent {
    final limit = creditLimit;
    if (limit == null || limit.amount.toDouble() <= 0) {
      return 0;
    }

    return statementBalance.amount.toDouble() / limit.amount.toDouble() * 100;
  }
}
