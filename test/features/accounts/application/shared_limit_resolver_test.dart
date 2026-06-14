import 'package:aiko/core/money/money.dart';
import 'package:aiko/features/accounts/application/shared_limit_resolver.dart';
import 'package:aiko/features/accounts/domain/account.dart';
import 'package:aiko/features/accounts/domain/account_details.dart';
import 'package:aiko/features/accounts/domain/account_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Account _card(
    String id, {
    bool shares = false,
    String? ref,
  }) =>
      Account(
        id: id,
        userId: 'u',
        name: id,
        type: AccountType.creditCard,
        currentBalance: Money.zero('USD'),
        details: CreditCardDetails(
          statementDay: 1,
          dueDay: 1,
          creditLimit: shares ? null : Money.parse('5000', 'USD'),
          sharesLimit: shares,
          sharedLimitAccountId: ref,
        ),
      );

  test('flips child to not sharing when parent missing', () {
    final child = _card('child', shares: true, ref: 'gone');
    final updated = SharedLimitResolver.resolve(
      accounts: [child],
      deletedId: 'gone',
    );
    expect(updated.length, 1);
    final details = updated.first.resolvedDetails as CreditCardDetails;
    expect(details.sharesLimit, false);
    expect(details.sharedLimitAccountId, isNull);
  });

  test('idempotent on second pass', () {
    final child = _card('child', shares: false);
    final updated = SharedLimitResolver.resolve(
      accounts: [child],
      deletedId: 'gone',
    );
    expect(updated, isEmpty);
  });

  test('does not touch non-referencing accounts', () {
    final other = _card('other', shares: false);
    final updated = SharedLimitResolver.resolve(
      accounts: [other],
      deletedId: 'gone',
    );
    expect(updated, isEmpty);
  });
}
