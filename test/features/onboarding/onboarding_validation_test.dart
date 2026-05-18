import 'package:aiko/core/money/money.dart';
import 'package:aiko/features/accounts/domain/account.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('first account carries name, type, currency, and opening balance', () {
    final account = Account(
      id: 'cash',
      userId: 'user',
      name: 'Cash Wallet',
      type: AccountType.cash,
      openingBalance: Money.parse('100', 'USD'),
      currentBalance: Money.parse('100', 'USD'),
    );

    expect(account.name, 'Cash Wallet');
    expect(account.currency, 'USD');
  });
}
