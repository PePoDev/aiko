import 'package:aiko/features/transactions/data/transaction_attachment_repository.dart';
import 'package:aiko/features/transactions/domain/transaction_attachment.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite/sqflite.dart' as sqlite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:aiko/core/storage/local_file_cache.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    FlutterSecureStorage.setMockInitialValues({'aiko_offline_user_id': 'user'});
    sqfliteFfiInit();
    sqlite.databaseFactory = databaseFactoryFfi;
  });
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

  test('offline attachment metadata survives repository recreation', () async {
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
    final reopened = await const TransactionAttachmentRepository()
        .listForTransaction('txn');
    expect(reopened.single.id, 'receipt');
    expect(reopened.single.storagePath, attachment.storagePath);
    expect(
      (await repository.exportableForTransaction('txn')).single.id,
      'receipt',
    );
    await LocalFileCache.remove('aiko-cache:attachment-metadata/user/txn');
  });
}
