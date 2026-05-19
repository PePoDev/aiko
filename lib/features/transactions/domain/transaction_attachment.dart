enum AttachmentExportPolicy { include, exclude }

class TransactionAttachment {
  const TransactionAttachment({
    required this.id,
    required this.userId,
    required this.transactionId,
    required this.fileName,
    required this.storagePath,
    required this.mimeType,
    required this.sizeBytes,
    required this.createdAt,
    this.isSensitive = false,
    this.exportPolicy = AttachmentExportPolicy.include,
  });

  static const maxUploadBytes = 10 * 1024 * 1024;
  static const supportedMimeTypes = {
    'application/pdf',
    'image/jpeg',
    'image/png',
  };

  final String id;
  final String userId;
  final String transactionId;
  final String fileName;
  final String storagePath;
  final String mimeType;
  final int sizeBytes;
  final DateTime createdAt;
  final bool isSensitive;
  final AttachmentExportPolicy exportPolicy;

  bool get isValidForUpload {
    return fileName.trim().isNotEmpty &&
        storagePath.trim().isNotEmpty &&
        sizeBytes > 0 &&
        sizeBytes <= maxUploadBytes &&
        supportedMimeTypes.contains(mimeType);
  }

  bool get isExportable {
    return isValidForUpload && exportPolicy == AttachmentExportPolicy.include;
  }
}
