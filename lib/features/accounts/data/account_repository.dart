import '../../../core/money/money.dart';
import '../domain/account.dart';

class AccountRepository {
  AccountRepository({List<Account>? accounts})
    : _accounts =
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
          ];

  final List<Account> _accounts;

  Future<List<Account>> list() async => List.unmodifiable(_accounts);

  Future<Account> save(Account account) async {
    final index = _accounts.indexWhere((item) => item.id == account.id);
    if (index == -1) {
      _accounts.add(account);
    } else {
      _accounts[index] = account;
    }
    return account;
  }

  Future<void> archive(String id) async {
    final index = _accounts.indexWhere((item) => item.id == id);
    if (index != -1) {
      _accounts[index] = _accounts[index].copyWith(isActive: false);
    }
  }
}
