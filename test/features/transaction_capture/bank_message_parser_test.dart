import 'package:aiko/features/transaction_capture/bank_message_parser.dart';
import 'package:aiko/features/transactions/domain/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

const _expense = TransactionType.expense;
const _income = TransactionType.income;

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

  test('ignores a balance-only ping with no movement keyword', () {
    expect(parser.parse('Your available balance is 9,000.00'), isNull);
  });

  test('reads a Thai debit message', () {
    final r = parser.parse('บัญชีของคุณถูกหักเงิน 500.00 บาท');
    expect(r!.type, TransactionType.expense);
    expect(r.amount, '500.00');
  });

  // (message, amount, direction, merchant). Synthetic samples in the shapes
  // Thai banks send; account numbers, dates and times must never be read as
  // the amount.
  final movements = <(String, String, TransactionType, String?)>[
    // Regressions from the audit.
    (
      'A/C x1234 debited THB 500.00 on 13/10/26. Bal THB 1,200.00',
      '500.00',
      _expense,
      null,
    ),
    (
      '13/10/26 10:25 บช X-1234 ถูกหัก 500.00 คงเหลือ 1,200.00',
      '500.00',
      _expense,
      null,
    ),
    ('Card ending 4321 spent THB 120.00', '120.00', _expense, null),
    (
      'Salary payment THB 50,000.00 credited to A/C x1234',
      '50000.00',
      _income,
      null,
    ),
    // KBank (K PLUS) style.
    (
      '13/10/69 10:25 บชX123456X รับโอนจากX987654 1,500.00บ คงเหลือ12,345.67บ',
      '1500.00',
      _income,
      null,
    ),
    (
      '13/10/69 10:25 บชX123456X เงินออก 250.00บ คงเหลือ12,095.67บ',
      '250.00',
      _expense,
      null,
    ),
    (
      'KBank: Paid 89.00 Baht at 7-Eleven from A/C x1234 on 13 Oct 2026 10:25',
      '89.00',
      _expense,
      '7-Eleven',
    ),
    // SCB style.
    (
      'เงินเข้า 3,200.00บ. เข้าบ/ชx123456 วันที่ 13/10@10:25 ใช้ได้ 15,000.00บ.',
      '3200.00',
      _income,
      null,
    ),
    (
      'ถอน/โอน/จ่าย 640.00บ. จากบ/ชx123456 วันที่ 13/10@18:02 ใช้ได้ 14,360.00บ.',
      '640.00',
      _expense,
      null,
    ),
    (
      'SCB: Withdrawal/transfer THB 1,000.00 from A/C x123456 on 13/10/2026 @ 09:15. Available balance THB 8,500.00',
      '1000.00',
      _expense,
      null,
    ),
    // Bangkok Bank (Bualuang) style.
    (
      'บช X-5678 รับเงินโอน 2,000.00 บาท 13 ต.ค. 69 14:30 คงเหลือ 22,000.00 บาท',
      '2000.00',
      _income,
      null,
    ),
    (
      'Deposit THB 4,250.50 to A/C x5678 on 13/10/26 at 14:30. Avl Bal THB 24,250.50',
      '4250.50',
      _income,
      null,
    ),
    // Krungthai style.
    (
      'Krungthai: เงินโอนเข้าบัญชี XXX-X-X1234-X จำนวน 900.00 บาท วันที่ 13/10/2569 เวลา 08:45 ยอดเงินที่ใช้ได้ 5,900.00 บาท',
      '900.00',
      _income,
      null,
    ),
    (
      'ชำระเงิน 1,250.00 บาท จากบัญชี XXX-X-X1234-X อ้างอิง 202610131234 คงเหลือ 4,650.00 บาท',
      '1250.00',
      _expense,
      null,
    ),
    // ttb style.
    (
      'ttb: Purchase THB 120.00 at TOPS MARKET with card XX1234 on 13/10/26 10:25',
      '120.00',
      _expense,
      'TOPS MARKET',
    ),
    (
      'ttb: Received transfer THB 750.00 to account XX9876 on 13/10/26 11:00 Ref. No. 4455667788',
      '750.00',
      _income,
      null,
    ),
    // Card wording: "credit card" names a card, it doesn't mean money in.
    (
      'Your credit card ending 4321 was charged USD 45.99 at Amazon.',
      '45.99',
      _expense,
      'Amazon',
    ),
    (
      'Refund THB 300.00 to your debit card x4321 from Lazada',
      '300.00',
      _income,
      null,
    ),
    // Currency glued to the number, and baht written as "฿".
    ('Spent ฿1,050 at Grab', '1050', _expense, 'Grab'),
    ('Payment of THB99.00 completed', '99.00', _expense, null),
  ];

  for (final (message, amount, type, merchant) in movements) {
    test('parses "$message"', () {
      final r = parser.parse(message);
      expect(r, isNotNull);
      expect(r!.amount, amount);
      expect(r.type, type);
      expect(r.merchant, merchant);
    });
  }

  // Codes, warnings and non-movements: nothing to book.
  final ignored = <String>[
    'Your OTP is 123456. Do not share it.',
    'OTP for payment of THB 500.00 is 482913 (Ref: ABCD). Do not share this code.',
    'Your one-time password for purchase of USD 20.00 is 774411',
    'รหัส OTP คือ 123456 (Ref: WXYZ) สำหรับชำระเงิน 500.00 บาท ห้ามบอกรหัสนี้แก่ผู้อื่น',
    'You paid 0.00',
    'บช X-1234 ถูกหัก 0.00 บาท',
    'Your available balance is 9,000.00',
    'Statement for A/C x1234 is ready',
  ];

  for (final message in ignored) {
    test('ignores "$message"', () {
      expect(parser.parse(message), isNull);
    });
  }
}
