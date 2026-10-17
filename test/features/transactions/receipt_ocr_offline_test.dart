import 'dart:async';

import 'package:aiko/core/money/money.dart';
import 'package:aiko/features/transactions/application/receipt_ocr_service.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  Future<ReceiptAutofill> scan(Future<Object?> Function() answer) =>
      ReceiptOcrService(
        call: (_) => answer(),
      ).scanWithCloudOcr(imageBytes: [1, 2, 3], fileName: 'r.jpg');

  test('a read receipt fills the form', () async {
    final autofill = await scan(
      () async => {'recognizedText': 'Cafe Aroi\nTotal 120.00'},
    );
    expect(autofill.failure, isNull);
    expect(autofill.merchant, 'Cafe Aroi');
    expect(autofill.total, Money.parse('120.00', 'THB'));
  });

  test('offline says offline, not "limited fields"', () async {
    for (final error in <Object>[
      FirebaseFunctionsException(code: 'unavailable', message: 'UNAVAILABLE'),
      http.ClientException('Failed to fetch'),
      TimeoutException('no answer'),
    ]) {
      final autofill = await scan(() async => throw error);
      expect(autofill.failure, ReceiptOcrFailure.offline, reason: '$error');
      expect(autofill.hasTransactionFields, isFalse);
    }
  });

  test('a server refusal is a failed scan', () async {
    final autofill = await scan(
      () async => throw FirebaseFunctionsException(
        code: 'invalid-argument',
        message: 'Invalid receipt image.',
      ),
    );
    expect(autofill.failure, ReceiptOcrFailure.failed);
  });

  test('a local-only build needs the cloud', () async {
    final autofill = await const ReceiptOcrService().scanWithCloudOcr(
      imageBytes: [1],
      fileName: 'r.jpg',
    );
    expect(autofill.failure, ReceiptOcrFailure.needsCloud);
  });
}
