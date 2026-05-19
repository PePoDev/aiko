import '../domain/transaction_attachment.dart';

class TransactionAttachmentDto {
  const TransactionAttachmentDto(this.json);

  final Map<String, dynamic> json;

  TransactionAttachment toDomain() {
    return TransactionAttachment(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      transactionId: json['transaction_id'] as String,
      fileName: json['file_name'] as String,
      storagePath: json['storage_path'] as String,
      mimeType: json['mime_type'] as String,
      sizeBytes: json['size_bytes'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
      isSensitive: json['is_sensitive'] as bool? ?? false,
      exportPolicy: AttachmentExportPolicy.values.byName(
        json['export_policy'] as String? ?? 'include',
      ),
    );
  }

  static Map<String, dynamic> fromDomain(TransactionAttachment attachment) => {
    'id': attachment.id,
    'user_id': attachment.userId,
    'transaction_id': attachment.transactionId,
    'file_name': attachment.fileName,
    'storage_path': attachment.storagePath,
    'mime_type': attachment.mimeType,
    'size_bytes': attachment.sizeBytes,
    'created_at': attachment.createdAt.toIso8601String(),
    'is_sensitive': attachment.isSensitive,
    'export_policy': attachment.exportPolicy.name,
  };
}
