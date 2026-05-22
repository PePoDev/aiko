import '../../../core/money/money.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../domain/transaction.dart';

class TransactionRepository {
  const TransactionRepository();

  Future<List<FinanceTransaction>> list() async {
    final session = AikoSupabase.requireSession();
    final response = await session.client
        .from('transactions')
        .select()
        .eq('user_id', session.userId)
        .order('date', ascending: false);

    return response
        .map((row) => _fromRow(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  Future<FinanceTransaction> save(FinanceTransaction transaction) async {
    _validate(transaction);

    final session = AikoSupabase.requireSession();
    final transactionWithUser = FinanceTransaction(
      id: transaction.id,
      userId: session.userId,
      accountId: transaction.accountId,
      type: transaction.type,
      amount: transaction.amount,
      date: transaction.date,
      categoryId: transaction.categoryId,
      merchant: transaction.merchant,
      note: transaction.note,
      tags: transaction.tags,
      splits: transaction.splits,
      status: transaction.status,
    );

    await session.client
        .from('transactions')
        .upsert(_toRow(transactionWithUser));

    return transactionWithUser;
  }

  Future<List<FinanceTransaction>> search(String query) async {
    final currentList = await list();
    final lower = query.toLowerCase();
    return currentList
        .where(
          (item) =>
              (item.merchant ?? '').toLowerCase().contains(lower) ||
              (item.categoryId ?? '').toLowerCase().contains(lower),
        )
        .toList(growable: false);
  }

  Future<FinanceTransaction> duplicate(String id, String newId) async {
    final currentList = await list();
    final original = currentList.firstWhere((item) => item.id == id);
    final copy = FinanceTransaction(
      id: newId,
      userId: original.userId,
      accountId: original.accountId,
      type: original.type,
      amount: original.amount,
      date: DateTime.now(),
      categoryId: original.categoryId,
      merchant: original.merchant,
      note: original.note,
      tags: original.tags,
      splits: original.splits,
    );
    return save(copy);
  }

  void _validate(FinanceTransaction transaction) {
    if (transaction.amount.amount <=
            Money.zero(transaction.amount.currency).amount &&
        transaction.type != TransactionType.adjustment) {
      throw ArgumentError('Transaction amount must be positive.');
    }
    if (transaction.splits.isNotEmpty) {
      final total = transaction.splits
          .map((split) => split.amount)
          .reduce((value, element) => value + element);
      if (total != transaction.amount) {
        throw ArgumentError('Split total must equal transaction amount.');
      }
    }
  }

  static FinanceTransaction _fromRow(Map<String, dynamic> row) {
    final type = TransactionType.values.firstWhere(
      (item) => item.name == row['type'],
      orElse: () => TransactionType.expense,
    );
    final status = TransactionStatus.values.firstWhere(
      (item) => item.name == (row['status'] as String? ?? 'posted'),
      orElse: () => TransactionStatus.posted,
    );
    final tags =
        (row['tags'] as List?)?.map((item) => item.toString()).toList() ??
        const <String>[];
    final currency = row['currency'] as String? ?? 'USD';

    return FinanceTransaction(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      accountId: row['account_id'] as String,
      type: type,
      amount: Money.parse('${row['amount'] ?? 0}', currency),
      date: DateTime.parse(row['date'] as String),
      categoryId: row['category_id'] as String?,
      merchant: row['merchant'] as String?,
      note: row['note'] as String?,
      tags: tags,
      status: status,
    );
  }

  static Map<String, dynamic> _toRow(FinanceTransaction transaction) {
    return {
      'id': transaction.id,
      'user_id': transaction.userId,
      'account_id': transaction.accountId,
      'type': transaction.type.name,
      'amount': transaction.amount.amount.toString(),
      'currency': transaction.amount.currency,
      'category_id': transaction.categoryId,
      'date': transaction.date.toIso8601String().substring(0, 10),
      'merchant': transaction.merchant,
      'note': transaction.note,
      'tags': transaction.tags,
      'status': transaction.status.name,
    };
  }
}
