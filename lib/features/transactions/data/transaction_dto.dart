import '../../../core/money/money.dart';
import '../domain/transaction.dart';

class TransactionDto {
  const TransactionDto(this.json);

  final Map<String, dynamic> json;

  FinanceTransaction toDomain() {
    return FinanceTransaction(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      accountId: json['account_id'] as String,
      type: TransactionType.values.byName(json['type'] as String? ?? 'expense'),
      amount: Money.parse(
        '${json['amount'] ?? 0}',
        json['currency'] as String? ?? 'USD',
      ),
      date: DateTime.parse(json['date'] as String),
      categoryId: json['category_id'] as String?,
      merchant: json['merchant'] as String?,
      note: json['note'] as String?,
    );
  }
}
