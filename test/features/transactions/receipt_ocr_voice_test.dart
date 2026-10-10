import 'package:aiko/features/transactions/application/receipt_ocr_service.dart';
import 'package:aiko/features/transactions/application/voice_transaction_parser.dart';
import 'package:aiko/features/transactions/domain/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Fixed clock so the plausible-date window doesn't drift with the calendar.
  final today = DateTime(2026, 10, 10, 9);

  test('receipt OCR extracts merchant, total, and date', () {
    final autofill = const ReceiptOcrService().parseRecognizedText('''
Coffee Shop
05/21/2026
Subtotal 4.50
Total 5.00
''', now: today);

    expect(autofill.merchant, 'Coffee Shop');
    expect(autofill.total?.amount.toString(), '5');
    expect(autofill.date, DateTime(2026, 5, 21));
  });

  test('receipt OCR reads Thai totals and Buddhist-era dates', () {
    final autofill = const ReceiptOcrService().parseRecognizedText('''
ร้านกาแฟอโรมา
21/05/2569
รวมย่อย 120.00
ยอดรวม 128.40
''', now: today);

    expect(autofill.merchant, 'ร้านกาแฟอโรมา');
    expect(autofill.total?.amount.toString(), '128.4');
    expect(autofill.date, DateTime(2026, 5, 21));
  });

  test('receipt OCR treats an impossible month as day-first', () {
    final autofill = const ReceiptOcrService().parseRecognizedText(
      'Shop\n25/12/2025\nTotal 9.00',
      now: today,
    );
    expect(autofill.date, DateTime(2025, 12, 25));
  });

  group('receipt date', () {
    DateTime? read(String line, {List<String> extra = const []}) =>
        ReceiptOcrService.extractDate(['Shop', ...extra, line], now: today);

    final cases = <(String, DateTime?)>[
      // Day first unless the middle number can't be a month.
      ('05/10/2026', DateTime(2026, 10, 5)),
      ('05-10-2026', DateTime(2026, 10, 5)),
      ('10/05/2026', DateTime(2026, 5, 10)),
      ('05/21/2026', DateTime(2026, 5, 21)),
      ('21/05/2026', DateTime(2026, 5, 21)),
      // Buddhist era: four digits above 2400, or two digits beyond next year.
      ('05/10/2569', DateTime(2026, 10, 5)),
      ('09/10/69', DateTime(2026, 10, 9)),
      ('13/09/68', DateTime(2025, 9, 13)),
      // Two-digit Gregorian years.
      ('05/10/26', DateTime(2026, 10, 5)),
      ('31/12/25', DateTime(2025, 12, 31)),
      // Tomorrow is allowed (time zones); later dates are not.
      ('11/10/2026', DateTime(2026, 10, 11)),
      ('12/10/2026', null),
      ('13/10/69', null),
      ('05/10/27', null),
      // Older than the date picker's range, or not a calendar date.
      ('05/10/2020', null),
      ('31/12/2020', null),
      ('01/01/2021', DateTime(2021, 1, 1)),
      ('31/02/2026', null),
      ('00/05/2026', null),
      ('15/13/2026', null),
    ];

    for (final (line, expected) in cases) {
      test('$line → $expected', () => expect(read(line), expected));
    }

    test('an MM/DD label makes ambiguous dates month-first', () {
      expect(
        read('05/10/2026', extra: ['Date (MM/DD/YYYY)']),
        DateTime(2026, 5, 10),
      );
    });

    test('a Buddhist-era date stays day-first even with an MM/DD label', () {
      expect(
        read('05/10/2569', extra: ['Date (MM/DD/YYYY)']),
        DateTime(2026, 10, 5),
      );
    });

    test('a two-digit Buddhist year is never read as 20xx', () {
      // 13/10/69 used to become 13 Oct 2069, outside the date picker.
      expect(
        ReceiptOcrService.extractDate([
          '13/10/69',
        ], now: DateTime(2026, 10, 20)),
        DateTime(2026, 10, 13),
      );
    });

    test('skips an implausible date and keeps looking', () {
      expect(
        ReceiptOcrService.extractDate([
          'Member since 01/01/1999',
          'Valid until 31/12/2030',
          'Date 07/10/2569 14:02',
        ], now: today),
        DateTime(2026, 10, 7),
      );
    });

    test('no date → null', () {
      expect(ReceiptOcrService.extractDate(['Shop', 'Total 5.00']), isNull);
    });
  });

  group('voice entry', () {
    final now = DateTime(2026, 5, 21, 10);
    const parser = VoiceTransactionParser();

    test('parses an English expense', () {
      final draft = parser.parse(
        'spent 15.50 at Starbucks yesterday for coffee',
        now: now,
        currency: 'USD',
      );
      expect(draft.type, TransactionType.expense);
      expect(draft.amount.amount.toString(), '15.5');
      expect(draft.date, DateTime(2026, 5, 20));
      expect(draft.merchant, 'Starbucks');
    });

    test('parses a Thai expense', () {
      final draft = parser.parse(
        'ซื้อกาแฟ 65 บาท ที่ร้านสตาร์บัคส์ เมื่อวาน',
        now: now,
        currency: 'THB',
      );
      expect(draft.type, TransactionType.expense);
      expect(draft.amount.amount.toString(), '65');
      expect(draft.date, DateTime(2026, 5, 20));
      expect(draft.merchant, 'สตาร์บัคส์');
    });

    test('parses Thai income with a thousands separator', () {
      final draft = parser.parse(
        'ได้รับเงินเดือน 25,000 บาท',
        now: now,
        currency: 'THB',
      );
      expect(draft.type, TransactionType.income);
      expect(draft.amount.amount.toString(), '25000');
      expect(draft.date, DateTime(2026, 5, 21));
    });

    final merchants = <(String, String?)>[
      // The merchant stops at date words and connectives, casing kept.
      ('spent 25 at Amazon yesterday', 'Amazon'),
      ('Spent 25 at Amazon today', 'Amazon'),
      ('paid 12 at Burger King tomorrow', 'Burger King'),
      ('spent 40 at Tesco Lotus last night', 'Tesco Lotus'),
      ('spent 9 at 7-Eleven on Monday', '7-Eleven'),
      ('spent 30 at Marks and Spencer with my card', 'Marks and Spencer'),
      ('spent 18 at McDonald\'s.', 'McDonald\'s'),
      ('received 500 from Acme Corp for the design job', 'Acme Corp'),
      // A place ("at") beats what was bought ("for").
      ('paid 120 for lunch at KFC', 'KFC'),
      ('spent 20 on Netflix', 'Netflix'),
      ('spent 20', null),
      // Thai: after ที่(ร้าน) / จาก, up to a date word, even without a space.
      ('ซื้อกาแฟ 65 บาท ที่ร้านสตาร์บัคส์เมื่อวาน', 'สตาร์บัคส์'),
      ('จ่ายค่าข้าว 80 บาท ที่ร้าน KFC วันนี้', 'KFC'),
      ('ซื้อของ 300 บาท ที่โลตัสพรุ่งนี้', 'โลตัส'),
      ('ได้รับเงิน 1,000 บาท จากบริษัทเอบีซีเมื่อวันศุกร์', 'บริษัทเอบีซี'),
    ];

    for (final (sentence, merchant) in merchants) {
      test('merchant of "$sentence"', () {
        expect(parser.parse(sentence, now: now).merchant, merchant);
      });
    }
  });
}
