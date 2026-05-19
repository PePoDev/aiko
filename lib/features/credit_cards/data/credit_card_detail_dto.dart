import '../../../core/money/money.dart';
import '../domain/credit_card_detail.dart';

class CreditCardDetailDto {
  const CreditCardDetailDto(this.json);

  final Map<String, dynamic> json;

  CreditCardDetail toDomain() {
    final currency = json['currency'] as String? ?? 'USD';
    return CreditCardDetail(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      accountId: json['account_id'] as String,
      statementBalance: Money.parse(
        '${json['statement_balance'] ?? 0}',
        currency,
      ),
      paymentDueDate: DateTime.parse(json['payment_due_date'] as String),
      creditLimit: json['credit_limit'] == null
          ? null
          : Money.parse('${json['credit_limit']}', currency),
      aprPercent: (json['apr_percent'] as num?)?.toDouble(),
      rewardsSummary: json['rewards_summary'] as String?,
    );
  }

  static Map<String, dynamic> fromDomain(CreditCardDetail detail) => {
    'id': detail.id,
    'user_id': detail.userId,
    'account_id': detail.accountId,
    'statement_balance': detail.statementBalance.amount.toString(),
    'currency': detail.statementBalance.currency,
    'payment_due_date': detail.paymentDueDate.toIso8601String(),
    'credit_limit': detail.creditLimit?.amount.toString(),
    'apr_percent': detail.aprPercent,
    'rewards_summary': detail.rewardsSummary,
  };
}
