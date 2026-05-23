import 'package:uuid/uuid.dart';
import 'package:decimal/decimal.dart';

import '../../../core/money/money.dart';
import '../domain/account.dart';

class BankFeedService {
  const BankFeedService();

  Future<List<Account>> linkBankFeed({
    required String institution,
    required String username,
    required String password,
  }) async {
    // Simulate network authentication roundtrip
    await Future<void>.delayed(const Duration(seconds: 2));

    if (username.trim().isEmpty || password.trim().isEmpty) {
      throw ArgumentError('Credentials cannot be empty.');
    }

    const currency = 'USD';
    const uuid = Uuid();

    if (institution.toLowerCase().contains('chase')) {
      return [
        Account(
          id: uuid.v4(),
          userId: '',
          name: 'Chase Sapphire Checking',
          type: AccountType.bank,
          openingBalance: Money(amount: Decimal.parse('1500.00'), currency: currency),
          currentBalance: Money(amount: Decimal.parse('3842.50'), currency: currency),
          institution: 'Chase Bank',
        ),
        Account(
          id: uuid.v4(),
          userId: '',
          name: 'Chase Freedom Unlimited',
          type: AccountType.creditCard,
          openingBalance: Money(amount: Decimal.zero, currency: currency),
          currentBalance: Money(amount: Decimal.parse('120.45'), currency: currency),
          institution: 'Chase Bank',
        ),
      ];
    } else if (institution.toLowerCase().contains('america') || institution.toLowerCase().contains('bofa')) {
      return [
        Account(
          id: uuid.v4(),
          userId: '',
          name: 'BofA Advantage Checking',
          type: AccountType.bank,
          openingBalance: Money(amount: Decimal.parse('500.00'), currency: currency),
          currentBalance: Money(amount: Decimal.parse('2150.10'), currency: currency),
          institution: 'Bank of America',
        ),
      ];
    } else {
      return [
        Account(
          id: uuid.v4(),
          userId: '',
          name: '$institution Everyday Checking',
          type: AccountType.bank,
          openingBalance: Money(amount: Decimal.parse('100.00'), currency: currency),
          currentBalance: Money(amount: Decimal.parse('750.00'), currency: currency),
          institution: institution,
        ),
      ];
    }
  }
}
