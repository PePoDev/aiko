import '../../../core/money/money.dart';

enum TransactionType {
  income,
  expense,
  transfer,
  refund,
  investmentBuy,
  investmentSell,
  dividend,
  interest,
  loanPayment,
  creditCardPayment,
  taxPayment,
  fee,
  adjustment,
}

enum TransactionStatus { draft, posted, voided, archived }

class FinanceTransaction {
  const FinanceTransaction({
    required this.id,
    required this.userId,
    required this.accountId,
    required this.type,
    required this.amount,
    required this.date,
    this.categoryId,
    this.merchant,
    this.note,
    this.tags = const [],
    this.splits = const [],
    this.status = TransactionStatus.posted,
  });

  final String id;
  final String userId;
  final String accountId;
  final TransactionType type;
  final Money amount;
  final DateTime date;
  final String? categoryId;
  final String? merchant;
  final String? note;
  final List<String> tags;
  final List<TransactionSplit> splits;
  final TransactionStatus status;

  bool get isExpense => type == TransactionType.expense;

  FinanceTransaction copyWith({
    Money? amount,
    String? categoryId,
    String? merchant,
    List<TransactionSplit>? splits,
    TransactionStatus? status,
  }) {
    return FinanceTransaction(
      id: id,
      userId: userId,
      accountId: accountId,
      type: type,
      amount: amount ?? this.amount,
      date: date,
      categoryId: categoryId ?? this.categoryId,
      merchant: merchant ?? this.merchant,
      note: note,
      tags: tags,
      splits: splits ?? this.splits,
      status: status ?? this.status,
    );
  }
}

class TransactionSplit {
  const TransactionSplit({
    required this.categoryId,
    required this.amount,
    this.note,
  });

  final String categoryId;
  final Money amount;
  final String? note;
}
