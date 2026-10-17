import 'package:aiko/features/transactions/domain/transaction_attachment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final attachment = TransactionAttachment(
    id: 'receipt',
    userId: 'user',
    transactionId: 'txn',
    fileName: 'receipt.pdf',
    storagePath: 'user/txn/receipt.pdf',
    mimeType: 'application/pdf',
    sizeBytes: 1200,
    createdAt: DateTime(2026, 5, 19),
  );

  test('validates supported attachment metadata', () {
    expect(attachment.isValidForUpload, isTrue);
    expect(attachment.isExportable, isTrue);
  });

  test('copyWith changes only the owner, transaction and path', () {
    final moved = attachment.copyWith(
      userId: 'uid',
      transactionId: 'tx-2',
      storagePath: 'users/uid/receipts/receipt/receipt.pdf',
    );

    expect(moved.id, 'receipt');
    expect(moved.userId, 'uid');
    expect(moved.transactionId, 'tx-2');
    expect(moved.storagePath, 'users/uid/receipts/receipt/receipt.pdf');
    expect(moved.fileName, attachment.fileName);
    expect(moved.mimeType, attachment.mimeType);
    expect(moved.sizeBytes, attachment.sizeBytes);
    expect(moved.createdAt, attachment.createdAt);
  });
}
