import 'package:aiko/core/money/money.dart';
import 'package:aiko/features/accounts/domain/account.dart';
import 'package:aiko/features/accounts/domain/account_details.dart';
import 'package:aiko/features/credit_cards/application/credit_card_metrics_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final service = const CreditCardMetricsService();
  Money m(String s) => Money.parse(s, 'USD');

  test('uses own limit when not sharing', () {
    final own = Account(
      id: 'own',
      userId: 'u',
      name: 'Own',
      type: AccountType.creditCard,
      currentBalance: Money.zero('USD'),
      details: CreditCardDetails(
        statementDay: 1,
        dueDay: 1,
        creditLimit: m('2000'),
      ),
    );
    final limit = service.effectiveLimit(own, allAccounts: [own]);
    expect(limit?.amount.toString(), '2000');
  });

  test('uses parent limit when sharing', () {
    final parent = Account(
      id: 'parent',
      userId: 'u',
      name: 'Parent',
      type: AccountType.creditCard,
      currentBalance: Money.zero('USD'),
      details: CreditCardDetails(
        statementDay: 1,
        dueDay: 1,
        creditLimit: m('8000'),
      ),
    );
    final child = Account(
      id: 'child',
      userId: 'u',
      name: 'Child',
      type: AccountType.creditCard,
      currentBalance: Money.zero('USD'),
      details: const CreditCardDetails(
        statementDay: 1,
        dueDay: 1,
        sharesLimit: true,
        sharedLimitAccountId: 'parent',
      ),
    );
    final limit = service.effectiveLimit(child, allAccounts: [parent, child]);
    expect(limit?.amount.toString(), '8000');
  });

  test('returns null when shared reference is missing', () {
    final child = Account(
      id: 'child',
      userId: 'u',
      name: 'Child',
      type: AccountType.creditCard,
      currentBalance: Money.zero('USD'),
      details: const CreditCardDetails(
        statementDay: 1,
        dueDay: 1,
        sharesLimit: true,
        sharedLimitAccountId: 'ghost',
      ),
    );
    final limit = service.effectiveLimit(child, allAccounts: [child]);
    expect(limit, isNull);
  });
}
