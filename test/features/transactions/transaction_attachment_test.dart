import 'package:aiko/features/transactions/data/transaction_attachment_repository.dart';
import 'package:aiko/features/transactions/domain/transaction_attachment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('validates supported attachment metadata', () {
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

    expect(attachment.isValidForUpload, isTrue);
    expect(attachment.isExportable, isTrue);
  });

  test('repository falls back offline for attachment metadata', () async {
    const repository = TransactionAttachmentRepository();
    final attachment = TransactionAttachment(
      id: 'receipt',
      userId: 'user',
      transactionId: 'txn',
      fileName: 'receipt.jpg',
      storagePath: 'user/txn/receipt.jpg',
      mimeType: 'image/jpeg',
      sizeBytes: 2048,
      createdAt: DateTime(2026, 5, 19),
    );

    final saved = await repository.save(attachment);

    expect(saved.userId, 'user');
    expect(await repository.listForTransaction('txn'), isEmpty);
    expect(await repository.exportableForTransaction('txn'), isEmpty);
  });
}
