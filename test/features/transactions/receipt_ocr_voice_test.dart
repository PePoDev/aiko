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

  test('voice parser creates transaction draft from natural language', () {
    final draft = const VoiceTransactionParser().parse(
      'Spent five dollars on coffee yesterday',
      now: DateTime(2026, 5, 22, 12),
    );

    expect(draft.type, TransactionType.expense);
    expect(draft.amount.amount.toString(), '5');
    expect(draft.date, DateTime(2026, 5, 21));
    expect(draft.merchant, 'coffee yesterday');
  });
}
