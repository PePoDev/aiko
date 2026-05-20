import 'dart:developer' as developer;

import '../../../core/supabase/supabase_client_provider.dart';
import '../../../core/money/money.dart';
import '../domain/transaction.dart';

class TransactionRepository {
  TransactionRepository({List<FinanceTransaction>? transactions})
    : _transactions = List.from(
        transactions ??
            [
              FinanceTransaction(
                id: 'coffee',
                userId: 'demo-user',
                accountId: 'cash',
                type: TransactionType.expense,
                amount: Money.parse('4.50', 'USD'),
                date: DateTime(2026, 5, 18),
                categoryId: 'food',
                merchant: 'Coffee Shop',
              ),
            ],
      );

  final List<FinanceTransaction> _transactions;

  Future<List<FinanceTransaction>> list() async {
    final client = AikoSupabase.tryClient();
    final user = client?.auth.currentUser;
    if (client != null && user != null) {
      try {
        final response = await client
            .from('transactions')
            .select()
            .eq('user_id', user.id)
            .order('date', ascending: false);
        return (response as List).map((row) => _fromRow(row)).toList();
      } catch (e) {
        // Fallback on error
      }
    }
    return List.unmodifiable(_transactions);
  }

  Future<FinanceTransaction> save(FinanceTransaction transaction) async {
    _validate(transaction);

    final client = AikoSupabase.tryClient();
    final user = client?.auth.currentUser;
    developer.log(
      'TransactionRepository.save: Saving transaction ${transaction.id}. '
      'Supabase client: ${client != null}, Auth user: ${user?.id ?? "null"}, '
      'Account ID: ${transaction.accountId}, Category ID: ${transaction.categoryId}',
    );

    if (client != null && user != null) {
      try {
        final txWithUser = FinanceTransaction(
          id: transaction.id,
          userId: user.id,
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
        final row = _toRow(txWithUser);
        developer.log(
          'TransactionRepository.save: Upserting row to Supabase: $row',
        );
        await client.from('transactions').upsert(row);
        developer.log('TransactionRepository.save: Upsert successful!');

        final index = _transactions.indexWhere(
          (item) => item.id == txWithUser.id,
        );
        if (index == -1) {
          _transactions.add(txWithUser);
        } else {
          _transactions[index] = txWithUser;
        }
        return txWithUser;
      } catch (e, stackTrace) {
        developer.log(
          'TransactionRepository.save error during Supabase write',
          error: e,
          stackTrace: stackTrace,
        );
      }
    } else {
      developer.log(
        'TransactionRepository.save: Bypassing Supabase save (either client or user is null).',
      );
    }

    final index = _transactions.indexWhere((item) => item.id == transaction.id);
    if (index == -1) {
      _transactions.add(transaction);
    } else {
      _transactions[index] = transaction;
    }
    return transaction;
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
    if (transaction.amount.amount.toDouble() <= 0 &&
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
    final typeStr = row['type'] as String;
    final type = TransactionType.values.firstWhere(
      (e) => e.name == typeStr,
      orElse: () => TransactionType.expense,
    );

    final statusStr = row['status'] as String? ?? 'posted';
    final status = TransactionStatus.values.firstWhere(
      (e) => e.name == statusStr,
      orElse: () => TransactionStatus.posted,
    );

    final amountVal = row['amount'] is num
        ? (row['amount'] as num).toDouble()
        : double.parse(row['amount'].toString());
    final currency = row['currency'] as String? ?? 'USD';

    DateTime date;
    if (row['date'] is String) {
      date = DateTime.parse(row['date'] as String);
    } else if (row['date'] is DateTime) {
      date = row['date'] as DateTime;
    } else {
      date = DateTime.now();
    }

    final tagsList =
        (row['tags'] as List?)?.map((e) => e.toString()).toList() ?? [];

    return FinanceTransaction(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      accountId: row['account_id'] as String,
      type: type,
      amount: Money.parse(amountVal.toString(), currency),
      date: date,
      categoryId: row['category_id'] as String?,
      merchant: row['merchant'] as String?,
      note: row['note'] as String?,
      tags: tagsList,
      status: status,
    );
  }

  static Map<String, dynamic> _toRow(FinanceTransaction transaction) {
    return {
      'id': transaction.id,
      'user_id': transaction.userId,
      'account_id': transaction.accountId,
      'type': transaction.type.name,
      'amount': transaction.amount.amount.toDouble(),
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
