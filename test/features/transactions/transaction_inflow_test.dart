import 'package:aiko/core/money/money.dart';
import 'package:aiko/features/transactions/domain/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

FinanceTransaction _tx(
  TransactionType type,
  String amount, {
  String id = 'tx',
  String? groupId,
}) => FinanceTransaction(
  id: id,
  userId: 'user',
  accountId: 'acct',
  type: type,
  amount: Money.parse(amount, 'THB'),
  date: DateTime(2026, 10, 1),
  transferGroupId: groupId,
);

void main() {
  group('TransactionType.isInflow', () {
    test('money-in types are inflows; everything else is an outflow', () {
      const inflows = {
        TransactionType.income,
        TransactionType.transferIn,
        TransactionType.refund,
        TransactionType.dividend,
        TransactionType.interest,
        TransactionType.investmentSell,
      };
      for (final type in TransactionType.values) {
        expect(type.isInflow, inflows.contains(type), reason: type.name);
      }
    });

    test('isTransfer covers both legs and the legacy single row', () {
      expect(TransactionType.values.where((type) => type.isTransfer).toSet(), {
        TransactionType.transfer,
        TransactionType.transferIn,
        TransactionType.transferOut,
      });
    });
  });

  group('balance math', () {
    final start = Money.parse('1000', 'THB');

    for (final type in [
      TransactionType.refund,
      TransactionType.dividend,
      TransactionType.interest,
      TransactionType.investmentSell,
    ]) {
      test('${type.name} adds to the balance and reverses cleanly', () {
        final tx = _tx(type, '150');
        final applied = tx.applyToAccountBalance(start);
        expect(applied, Money.parse('1150', 'THB'));
        expect(tx.reverseFromAccountBalance(applied), start);
        expect(tx.isInflow, isTrue);
      });
    }

    test('fee and payments still subtract', () {
      for (final type in [
        TransactionType.fee,
        TransactionType.loanPayment,
        TransactionType.creditCardPayment,
        TransactionType.taxPayment,
        TransactionType.investmentBuy,
      ]) {
        expect(
          _tx(type, '100').applyToAccountBalance(start),
          Money.parse('900', 'THB'),
          reason: type.name,
        );
      }
    });

    test('a positive adjustment raises the balance', () {
      final tx = _tx(TransactionType.adjustment, '250');
      expect(tx.applyToAccountBalance(start), Money.parse('1250', 'THB'));
      expect(tx.isInflow, isTrue);
      expect(tx.signedAmount, Money.parse('250', 'THB'));
    });

    test('a negative adjustment lowers the balance and reverses cleanly', () {
      final tx = _tx(TransactionType.adjustment, '-400');
      final applied = tx.applyToAccountBalance(start);
      expect(applied, Money.parse('600', 'THB'));
      expect(tx.reverseFromAccountBalance(applied), start);
      expect(tx.isInflow, isFalse);
      expect(tx.absoluteAmount, Money.parse('400', 'THB'));
    });

    test('an expense has a negative signed amount', () {
      expect(
        _tx(TransactionType.expense, '80').signedAmount,
        Money.parse('-80', 'THB'),
      );
    });

    test('balanceFromTransactions sums from zero, opening balance first', () {
      final balance = balanceFromTransactions([
        _tx(TransactionType.adjustment, '5000'),
        _tx(TransactionType.expense, '45'),
        _tx(TransactionType.refund, '20'),
        _tx(TransactionType.adjustment, '-75'),
      ], 'THB');
      expect(balance, Money.parse('4900', 'THB'));
    });

    test('a debt opening balance stays negative', () {
      expect(
        balanceFromTransactions([
          _tx(TransactionType.adjustment, '-12000'),
        ], 'THB'),
        Money.parse('-12000', 'THB'),
      );
    });
  });

  group('transferPartnersOf', () {
    test('finds the other leg by shared group id', () {
      final out = _tx(TransactionType.transferOut, '10', id: 'o', groupId: 'g');
      final inLeg = _tx(
        TransactionType.transferIn,
        '10',
        id: 'i',
        groupId: 'g',
      );
      final other = _tx(TransactionType.expense, '5', id: 'e');
      expect(transferPartnersOf(out, [out, inLeg, other]), [inLeg]);
      expect(transferPartnersOf(inLeg, [out, inLeg, other]), [out]);
    });

    test('unlinked legacy legs have no partner', () {
      final out = _tx(TransactionType.transferOut, '10', id: 'o');
      final inLeg = _tx(TransactionType.transferIn, '10', id: 'i');
      expect(transferPartnersOf(out, [out, inLeg]), isEmpty);
    });
  });
}
