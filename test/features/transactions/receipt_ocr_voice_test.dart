import 'package:aiko/features/transactions/application/receipt_ocr_service.dart';
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
}
