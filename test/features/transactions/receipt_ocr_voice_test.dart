import 'package:aiko/features/transactions/application/receipt_ocr_service.dart';
import 'package:aiko/features/transactions/application/voice_transaction_parser.dart';
import 'package:aiko/features/transactions/domain/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('receipt OCR extracts merchant, total, and date', () {
    final autofill = const ReceiptOcrService().parseRecognizedText('''
Coffee Shop
05/21/2026
Subtotal 4.50
Total 5.00
''');

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
''');

    expect(autofill.merchant, 'ร้านกาแฟอโรมา');
    expect(autofill.total?.amount.toString(), '128.4');
    expect(autofill.date, DateTime(2026, 5, 21));
  });

  test('receipt OCR treats an impossible month as day-first', () {
    final autofill = const ReceiptOcrService().parseRecognizedText(
      'Shop\n25/12/2026\nTotal 9.00',
    );
    expect(autofill.date, DateTime(2026, 12, 25));
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
      expect(draft.merchant, startsWith('starbucks'));
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
  });
}
