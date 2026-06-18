import 'package:aiko/features/transaction_capture/bank_message_parser.dart';
import 'package:aiko/features/transactions/domain/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parser = BankMessageParser();

  test('reads a debit, picks the spent amount not the balance', () {
    final r = parser.parse(
      'Your card was debited THB 350.00 at Starbucks. Available balance 1,200.00',
    );
    expect(r, isNotNull);
    expect(r!.type, TransactionType.expense);
    expect(r.amount, '350.00');
    expect(r.merchant, 'Starbucks');
  });

  test('reads a credit/income', () {
    final r = parser.parse('You received \$2,500.00 salary deposit');
    expect(r!.type, TransactionType.income);
    expect(r.amount, '2500.00');
  });

  test('ignores non-money messages (OTP)', () {
    expect(parser.parse('Your OTP is 123456. Do not share it.'), isNull);
  });

  test('ignores a balance-only ping with no movement keyword', () {
    expect(parser.parse('Your available balance is 9,000.00'), isNull);
  });

  test('reads a Thai debit message', () {
    final r = parser.parse('บัญชีของคุณถูกหักเงิน 500.00 บาท');
    expect(r!.type, TransactionType.expense);
    expect(r.amount, '500.00');
  });
}
