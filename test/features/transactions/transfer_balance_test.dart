import 'package:aiko/core/money/money.dart';
import 'package:aiko/features/transactions/domain/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

FinanceTransaction _tx(TransactionType type, String amount) => FinanceTransaction(
  id: 'tx',
  userId: 'user',
  accountId: 'acct',
  type: type,
  amount: Money.parse(amount, 'USD'),
  date: DateTime(2026, 6, 15),
);

void main() {
  group('transfer leg balance math', () {
    test('transferOut subtracts from the source account', () {
      final start = Money.parse('100', 'USD');
      final out = _tx(TransactionType.transferOut, '30');
      expect(out.applyToAccountBalance(start), Money.parse('70', 'USD'));
      // Reversing restores the original balance.
      expect(
        out.reverseFromAccountBalance(out.applyToAccountBalance(start)),
        start,
      );
    });

    test('transferIn adds to the destination account, like income', () {
      final start = Money.parse('100', 'USD');
      final inLeg = _tx(TransactionType.transferIn, '30');
      final income = _tx(TransactionType.income, '30');
      expect(inLeg.applyToAccountBalance(start), Money.parse('130', 'USD'));
      expect(
        inLeg.applyToAccountBalance(start),
        income.applyToAccountBalance(start),
      );
    });

    test('a paired transfer is balance-neutral across both accounts', () {
      final from = Money.parse('100', 'USD');
      final to = Money.parse('40', 'USD');
      final out = _tx(TransactionType.transferOut, '25');
      final inLeg = _tx(TransactionType.transferIn, '25');

      final newFrom = out.applyToAccountBalance(from);
      final newTo = inLeg.applyToAccountBalance(to);
      // Money left the source equals money that arrived at the destination.
      expect(newFrom, Money.parse('75', 'USD'));
      expect(newTo, Money.parse('65', 'USD'));
      expect((from + to), (newFrom + newTo));
    });

    test('plain transfer still subtracts (legacy single-row behaviour)', () {
      final start = Money.parse('100', 'USD');
      final transfer = _tx(TransactionType.transfer, '30');
      expect(transfer.applyToAccountBalance(start), Money.parse('70', 'USD'));
    });
  });
}
