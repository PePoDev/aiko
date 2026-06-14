import 'package:aiko/core/money/money.dart';
import 'package:aiko/features/accounts/data/account_dto.dart';
import 'package:aiko/features/accounts/domain/account.dart';
import 'package:aiko/features/accounts/domain/account_details.dart';
import 'package:aiko/features/accounts/domain/account_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('account without details round-trips as cash', () {
    final a = Account(
      id: 'a',
      userId: 'u',
      name: 'Wallet',
      type: AccountType.cash,
      currentBalance: Money.parse('10', 'USD'),
    );
    final json = AccountDto.fromDomain(a);
    final restored = AccountDto(json).toDomain();
    expect(restored.id, a.id);
    expect(restored.resolvedDetails, isA<CashDetails>());
  });

  test('credit card details round-trip', () {
    final a = Account(
      id: 'a',
      userId: 'u',
      name: 'Visa',
      type: AccountType.creditCard,
      currentBalance: Money.parse('0', 'USD'),
      details: const CreditCardDetails(statementDay: 15, dueDay: 5),
    );
    final json = AccountDto.fromDomain(a);
    final restored = AccountDto(json).toDomain();
    final details = restored.resolvedDetails;
    expect(details, isA<CreditCardDetails>());
    final cc = details as CreditCardDetails;
    expect(cc.statementDay, 15);
    expect(cc.dueDay, 5);
  });
}
