import 'dart:convert';

import 'package:aiko/features/transactions/application/receipt_ocr_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the cloud OCR request carries the image as base64', () {
    final bytes = [0, 1, 127, 128, 254, 255];

    final request = ReceiptOcrService.cloudOcrRequest(
      imageBytes: bytes,
      fileName: 'receipt.jpg',
    );

    expect(request, {'fileName': 'receipt.jpg', 'imageBase64': 'AAF/gP7/'});
    expect(base64Decode(request['imageBase64']! as String), bytes);
    expect(request.containsKey('imageBytes'), isFalse);
  });
}
