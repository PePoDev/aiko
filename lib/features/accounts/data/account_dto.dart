import 'dart:convert';

import '../../../core/money/money.dart';
import '../domain/account.dart';
import '../domain/account_details.dart';
import 'account_details_dto.dart';

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
      currentBalance: Money.parse('${json['current_balance'] ?? 0}', currency),
      institution: json['institution'] as String?,
      includeInNetWorth: json['include_in_net_worth'] as bool? ?? true,
      isActive: json['is_active'] as bool? ?? true,
      details: _detailsFromJson(json['details']),
    );
  }

  static Map<String, dynamic> fromDomain(Account account) {
    return {
      'id': account.id,
      'user_id': account.userId,
      'name': account.name,
      'type': account.type.name,
      'currency': account.currency,
      'current_balance': account.currentBalance.amount.toString(),
      'institution': account.institution,
      'include_in_net_worth': account.includeInNetWorth,
      'is_active': account.isActive,
      'details': AccountDetailsDto.toJson(account.resolvedDetails),
    };
  }

  static AccountDetails? _detailsFromJson(Object? raw) {
    if (raw == null) return null;
    if (raw is String) {
      if (raw.isEmpty) return null;
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          return AccountDetailsDto.fromJson(decoded);
        }
      } catch (_) {
        return null;
      }
      return null;
    }
    if (raw is Map<String, dynamic>) return AccountDetailsDto.fromJson(raw);
    return null;
  }
}
