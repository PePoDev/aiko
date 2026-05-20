import '../../../core/supabase/supabase_client_provider.dart';
import '../../../core/money/money.dart';
import '../domain/account.dart';

class AccountRepository {
  AccountRepository({List<Account>? accounts})
    : _accounts = List.from(
        accounts ??
            [
              Account(
                id: 'cash',
                userId: 'demo-user',
                name: 'Cash Wallet',
                type: AccountType.cash,
                openingBalance: Money.parse('1000', 'USD'),
                currentBalance: Money.parse('1000', 'USD'),
              ),
            ],
      );

  final List<Account> _accounts;

  Future<List<Account>> list() async {
    final client = AikoSupabase.tryClient();
    final user = client?.auth.currentUser;
    if (client != null && user != null) {
      try {
        final response = await client
            .from('accounts')
            .select()
            .eq('user_id', user.id);
        return (response as List)
            .map((row) => _fromRow(row))
            .toList();
      } catch (e) {
        // Fallback on error
      }
    }
    return List.unmodifiable(_accounts);
  }

  Future<Account> save(Account account) async {
    final client = AikoSupabase.tryClient();
    final user = client?.auth.currentUser;
    if (client != null && user != null) {
      try {
        final accWithUser = Account(
          id: account.id,
          userId: user.id,
          name: account.name,
          type: account.type,
          openingBalance: account.openingBalance,
          currentBalance: account.currentBalance,
          institution: account.institution,
          includeInNetWorth: account.includeInNetWorth,
          isActive: account.isActive,
        );
        await client.from('accounts').upsert(_toRow(accWithUser));
        
        final index = _accounts.indexWhere((item) => item.id == accWithUser.id);
        if (index == -1) {
          _accounts.add(accWithUser);
        } else {
          _accounts[index] = accWithUser;
        }
        return accWithUser;
      } catch (e, stackTrace) {
        print('AccountRepository.save error: $e');
        print(stackTrace);
      }
    }

    final index = _accounts.indexWhere((item) => item.id == account.id);
    if (index == -1) {
      _accounts.add(account);
    } else {
      _accounts[index] = account;
    }
    return account;
  }

  Future<void> archive(String id) async {
    final client = AikoSupabase.tryClient();
    final user = client?.auth.currentUser;
    if (client != null && user != null) {
      try {
        await client
            .from('accounts')
            .update({'is_active': false})
            .eq('id', id)
            .eq('user_id', user.id);
      } catch (e) {
        // Fallback
      }
    }

    final index = _accounts.indexWhere((item) => item.id == id);
    if (index != -1) {
      _accounts[index] = _accounts[index].copyWith(isActive: false);
    }
  }

  static Account _fromRow(Map<String, dynamic> row) {
    final typeStr = row['type'] as String;
    final type = AccountType.values.firstWhere(
      (e) => e.name == typeStr,
      orElse: () => AccountType.cash,
    );

    final openingBalanceVal = row['opening_balance'] is num
        ? (row['opening_balance'] as num).toDouble()
        : double.parse(row['opening_balance'].toString());
    final currentBalanceVal = row['current_balance'] is num
        ? (row['current_balance'] as num).toDouble()
        : double.parse(row['current_balance'].toString());
    final currency = row['currency'] as String? ?? 'USD';

    return Account(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      name: row['name'] as String,
      type: type,
      openingBalance: Money.parse(openingBalanceVal.toString(), currency),
      currentBalance: Money.parse(currentBalanceVal.toString(), currency),
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
      'opening_balance': account.openingBalance.amount.toDouble(),
      'current_balance': account.currentBalance.amount.toDouble(),
      'institution': account.institution,
      'include_in_net_worth': account.includeInNetWorth,
      'is_active': account.isActive,
    };
  }
}
