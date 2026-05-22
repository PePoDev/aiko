import '../../../core/money/money.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../domain/account.dart';

class AccountRepository {
  const AccountRepository();

  Future<List<Account>> list() async {
    final session = AikoSupabase.requireSession();
    final response = await session.client
        .from('accounts')
        .select()
        .eq('user_id', session.userId)
        .order('name');

    return response
        .map((row) => _fromRow(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  Future<Account> save(Account account) async {
    final session = AikoSupabase.requireSession();
    final accountWithUser = Account(
      id: account.id,
      userId: session.userId,
      name: account.name,
      type: account.type,
      openingBalance: account.openingBalance,
      currentBalance: account.currentBalance,
      institution: account.institution,
      includeInNetWorth: account.includeInNetWorth,
      isActive: account.isActive,
    );

    await session.client.from('accounts').upsert(_toRow(accountWithUser));
    return accountWithUser;
  }

  Future<void> archive(String id) async {
    final session = AikoSupabase.requireSession();
    await session.client
        .from('accounts')
        .update({
          'is_active': false,
          'archived_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', id)
        .eq('user_id', session.userId);
  }

  static Account _fromRow(Map<String, dynamic> row) {
    final type = AccountType.values.firstWhere(
      (item) => item.name == row['type'],
      orElse: () => AccountType.cash,
    );
    final currency = row['currency'] as String? ?? 'USD';

    return Account(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      name: row['name'] as String,
      type: type,
      openingBalance: Money.parse('${row['opening_balance'] ?? 0}', currency),
      currentBalance: Money.parse('${row['current_balance'] ?? 0}', currency),
      institution: row['institution'] as String?,
      includeInNetWorth: row['include_in_net_worth'] as bool? ?? true,
      isActive: row['is_active'] as bool? ?? true,
    );
  }

  static Map<String, dynamic> _toRow(Account account) {
    return {
      'id': account.id,
      'user_id': account.userId,
      'name': account.name,
      'type': account.type.name,
      'currency': account.currency,
      'opening_balance': account.openingBalance.amount.toString(),
      'current_balance': account.currentBalance.amount.toString(),
      'institution': account.institution,
      'include_in_net_worth': account.includeInNetWorth,
      'is_active': account.isActive,
    };
  }
}
