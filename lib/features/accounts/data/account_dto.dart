import '../../../core/money/money.dart';
import '../domain/account.dart';

class AccountDto {
  const AccountDto(this.json);

  final Map<String, dynamic> json;

  Account toDomain() {
    final currency = json['currency'] as String? ?? 'THB';
    return Account(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      type: AccountType.values.byName(json['type'] as String? ?? 'cash'),
      openingBalance: Money.parse('${json['opening_balance'] ?? 0}', currency),
      currentBalance: Money.parse('${json['current_balance'] ?? 0}', currency),
      institution: json['institution'] as String?,
      includeInNetWorth: json['include_in_net_worth'] as bool? ?? true,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  static Map<String, dynamic> fromDomain(Account account) => {
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
