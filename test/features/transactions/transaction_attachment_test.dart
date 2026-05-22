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

  test('repository requires Supabase for attachment persistence', () async {
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

    await expectLater(repository.save(attachment), throwsStateError);
    await expectLater(repository.listForTransaction('txn'), throwsStateError);
    await expectLater(
      repository.exportableForTransaction('txn'),
      throwsStateError,
    );
  });
}
