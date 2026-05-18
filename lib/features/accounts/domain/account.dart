import '../../../core/money/money.dart';

enum AccountType {
  cash,
  bank,
  eWallet,
  creditCard,
  loan,
  investment,
  asset,
  liability,
  other,
}

class Account {
  const Account({
    required this.id,
    required this.userId,
    required this.name,
    required this.type,
    required this.openingBalance,
    required this.currentBalance,
    this.institution,
    this.includeInNetWorth = true,
    this.isActive = true,
  });

  final String id;
  final String userId;
  final String name;
  final AccountType type;
  final Money openingBalance;
  final Money currentBalance;
  final String? institution;
  final bool includeInNetWorth;
  final bool isActive;

  String get currency => currentBalance.currency;

  Account copyWith({
    String? name,
    AccountType? type,
    Money? openingBalance,
    Money? currentBalance,
    bool? isActive,
  }) {
    return Account(
      id: id,
      userId: userId,
      name: name ?? this.name,
      type: type ?? this.type,
      openingBalance: openingBalance ?? this.openingBalance,
      currentBalance: currentBalance ?? this.currentBalance,
      institution: institution,
      includeInNetWorth: includeInNetWorth,
      isActive: isActive ?? this.isActive,
    );
  }
}
