import '../../../core/money/money.dart';
import 'account_details.dart';
import 'account_type.dart';

export 'account_type.dart';

class Account {
  const Account({
    required this.id,
    required this.userId,
    required this.name,
    required this.type,
    required this.currentBalance,
    this.institution,
    this.includeInNetWorth = true,
    this.isActive = true,
    this.details,
  });

  final String id;
  final String userId;
  final String name;
  final AccountType type;
  final Money currentBalance;
  final String? institution;
  final bool includeInNetWorth;
  final bool isActive;
  final AccountDetails? details;

  String get currency => currentBalance.currency;

  AccountDetails get resolvedDetails =>
      details ?? AccountDetails.defaultFor(type);

  static AccountDetails defaultDetailsFor(AccountType t) =>
      AccountDetails.defaultFor(t);

  Account copyWith({
    String? name,
    AccountType? type,
    Money? currentBalance,
    String? institution,
    bool? includeInNetWorth,
    bool? isActive,
    AccountDetails? details,
    bool resetDetails = false,
  }) {
    return Account(
      id: id,
      userId: userId,
      name: name ?? this.name,
      type: type ?? this.type,
      currentBalance: currentBalance ?? this.currentBalance,
      institution: institution ?? this.institution,
      includeInNetWorth: includeInNetWorth ?? this.includeInNetWorth,
      isActive: isActive ?? this.isActive,
      details: resetDetails
          ? AccountDetails.defaultFor(type ?? this.type)
          : (details ?? this.details),
    );
  }
}
