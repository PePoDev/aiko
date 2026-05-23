import '../../../core/supabase/supabase_client_provider.dart';
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

    final client = AikoSupabase.tryClient();
    final user = client?.auth.currentUser;
    final userId = user?.id ?? attachment.userId;
    final attachmentWithUser = TransactionAttachment(
      id: attachment.id,
      userId: userId,
      transactionId: attachment.transactionId,
      fileName: attachment.fileName,
      storagePath: attachment.storagePath,
      mimeType: attachment.mimeType,
      sizeBytes: attachment.sizeBytes,
      createdAt: attachment.createdAt,
      isSensitive: attachment.isSensitive,
      exportPolicy: attachment.exportPolicy,
    );

    if (client == null || user == null) {
      return attachmentWithUser;
    }
    try {
      await client.from('attachments').upsert(_toRow(attachmentWithUser));
    } catch (_) {
      return attachmentWithUser;
    }
    return attachmentWithUser;
  }

  Future<List<TransactionAttachment>> listForTransaction(
    String transactionId,
  ) async {
    final client = AikoSupabase.tryClient();
    final user = client?.auth.currentUser;
    if (client == null || user == null) {
      return const [];
    }
    final List<dynamic> response;
    try {
      response = await client
          .from('attachments')
          .select()
          .eq('user_id', user.id)
          .eq('linked_entity_type', 'transaction')
          .eq('linked_entity_id', transactionId)
          .order('created_at', ascending: false);
    } catch (_) {
      return const [];
    }

    return response
        .map((row) => _fromRow(Map<String, dynamic>.from(row)))
        .toList(growable: false);
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
