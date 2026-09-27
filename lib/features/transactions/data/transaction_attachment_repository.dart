import 'dart:convert';
import '../../../core/offline/offline_user_context.dart';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import '../../../core/storage/local_file_cache.dart';
import '../../../core/firebase/firebase_backend.dart';
import '../domain/transaction_attachment.dart';

class TransactionAttachmentRepository {
  const TransactionAttachmentRepository();

  Future<TransactionAttachment> save(TransactionAttachment attachment) async {
    if (!attachment.isValidForUpload) {
      throw ArgumentError.value(
        attachment.fileName,
        'attachment',
        'Attachment metadata is invalid or unsupported',
      );
    }

    final userId = await OfflineUserContext().resolveUserId();
    await _cacheMetadata(attachment, userId);
    final attachmentWithUser = TransactionAttachment(
      id: attachment.id,
      userId: userId,
      transactionId: attachment.transactionId,
      fileName: attachment.fileName,
      storagePath:
          'users/$userId/receipts/${attachment.id}/${attachment.fileName}',
      mimeType: attachment.mimeType,
      sizeBytes: attachment.sizeBytes,
      createdAt: attachment.createdAt,
      isSensitive: attachment.isSensitive,
      exportPolicy: attachment.exportPolicy,
    );

    if (FirebaseBackend.userId == null) {
      return attachment;
    }
    try {
      if (attachment.storagePath != attachmentWithUser.storagePath) {
        final bytes = await readBytes(attachment);
        await FirebaseBackend.storage
            .ref(attachmentWithUser.storagePath)
            .putData(bytes, SettableMetadata(contentType: attachment.mimeType));
      }
      await FirebaseBackend.collection(
        'attachments',
      ).doc(attachment.id).set(_toRow(attachmentWithUser));
      await _cacheMetadata(attachmentWithUser, userId);
    } catch (_) {
      return attachment;
    }
    return attachmentWithUser;
  }

  Future<Uint8List> readBytes(TransactionAttachment attachment) async {
    final path = attachment.storagePath;
    if (path.startsWith('aiko-cache:') ||
        path.startsWith('/') ||
        path.startsWith('blob:') ||
        path.startsWith('file:')) {
      return LocalFileCache.read(path);
    }
    final cacheKey = 'receipts/$path';
    try {
      return await LocalFileCache.read('aiko-cache:$cacheKey');
    } catch (_) {
      final bytes = await FirebaseBackend.storage
          .ref(path)
          .getData(TransactionAttachment.maxUploadBytes);
      if (bytes == null) throw StateError('Attachment is unavailable.');
      await LocalFileCache.write(cacheKey, bytes);
      return bytes;
    }
  }

  Future<List<TransactionAttachment>> listForTransaction(
    String transactionId,
  ) async {
    final userId = await OfflineUserContext().resolveUserId();
    final local = await _localMetadata(userId, transactionId);
    if (FirebaseBackend.userId == null) return local;
    try {
      // Retry attachments whose bytes were saved while disconnected.
      for (final attachment in local) {
        if (attachment.storagePath.startsWith('aiko-cache:')) {
          await save(attachment);
        }
      }
      final response = await FirebaseBackend.collection(
        'attachments',
      ).where('linked_entity_id', isEqualTo: transactionId).get();
      final remote = response.docs.map((doc) => _fromRow(doc.data())).toList();
      for (final attachment in remote) {
        await _cacheMetadata(attachment, userId);
      }
      final merged = {
        for (final attachment in local) attachment.id: attachment,
        for (final attachment in remote) attachment.id: attachment,
      };
      return merged.values.toList();
    } catch (_) {
      return local;
    }
  }

  Future<List<TransactionAttachment>> _localMetadata(
    String userId,
    String transactionId,
  ) async {
    try {
      final bytes = await LocalFileCache.read(
        'aiko-cache:attachment-metadata/$userId/$transactionId',
      );
      return (jsonDecode(utf8.decode(bytes)) as List)
          .map((row) => _fromRow(Map<String, dynamic>.from(row as Map)))
          .toList();
    } on StateError {
      return [];
    }
  }

  Future<void> _cacheMetadata(
    TransactionAttachment attachment,
    String userId,
  ) async {
    final items = await _localMetadata(userId, attachment.transactionId);
    final rows = {
      for (final item in items) item.id: _toRow(item),
      attachment.id: {..._toRow(attachment), 'user_id': userId},
    };
    await LocalFileCache.write(
      'attachment-metadata/$userId/${attachment.transactionId}',
      utf8.encode(jsonEncode(rows.values.toList())),
    );
  }

  Future<List<TransactionAttachment>> exportableForTransaction(
    String transactionId,
  ) async {
    final attachments = await listForTransaction(transactionId);
    return attachments.where((item) => item.isExportable).toList();
  }

  static TransactionAttachment _fromRow(Map<String, dynamic> row) {
    final exportPolicy = AttachmentExportPolicy.values.firstWhere(
      (item) => item.name == (row['export_policy'] as String? ?? 'include'),
      orElse: () => AttachmentExportPolicy.include,
    );

    return TransactionAttachment(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      transactionId: row['linked_entity_id'] as String,
      fileName: row['file_name'] as String,
      storagePath: row['storage_path'] as String,
      mimeType: row['content_type'] as String,
      sizeBytes: int.parse('${row['size_bytes'] ?? 0}'),
      createdAt: DateTime.parse(row['created_at'] as String),
      isSensitive: row['is_sensitive'] as bool? ?? false,
      exportPolicy: exportPolicy,
    );
  }

  static Map<String, dynamic> _toRow(TransactionAttachment attachment) {
    return {
      'created_at': attachment.createdAt.toUtc().toIso8601String(),
      'id': attachment.id,
      'user_id': attachment.userId,
      'storage_bucket': 'receipts',
      'storage_path': attachment.storagePath,
      'file_name': attachment.fileName,
      'content_type': attachment.mimeType,
      'size_bytes': attachment.sizeBytes,
      'linked_entity_type': 'transaction',
      'linked_entity_id': attachment.transactionId,
      'is_sensitive': attachment.isSensitive,
      'export_policy': attachment.exportPolicy.name,
    };
  }
}
