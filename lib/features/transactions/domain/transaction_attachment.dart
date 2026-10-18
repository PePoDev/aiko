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
    'image/webp',
    'image/heic',
    'text/plain',
    'text/csv',
    'text/markdown',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
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

  TransactionAttachment copyWith({
    String? userId,
    String? transactionId,
    String? storagePath,
  }) {
    return TransactionAttachment(
      id: id,
      userId: userId ?? this.userId,
      transactionId: transactionId ?? this.transactionId,
      fileName: fileName,
      storagePath: storagePath ?? this.storagePath,
      mimeType: mimeType,
      sizeBytes: sizeBytes,
      createdAt: createdAt,
      isSensitive: isSensitive,
      exportPolicy: exportPolicy,
    );
  }

  bool get isValidForUpload {
    return fileName.trim().isNotEmpty &&
        storagePath.trim().isNotEmpty &&
        sizeBytes > 0 &&
        sizeBytes <= maxUploadBytes &&
        supportedMimeTypes.contains(mimeType);
  }

  /// True for any image MIME type we can render as a thumbnail with
  /// [Image.file]. HEIC is excluded — Flutter's default decoders don't read
  /// it on every platform, so it falls back to the generic file icon.
  bool get isImagePreviewable {
    return mimeType == 'image/jpeg' ||
        mimeType == 'image/png' ||
        mimeType == 'image/webp';
  }

  /// True for plain-text-like MIME types we can render as a scrollable
  /// monospace text block (txt, csv, md).
  bool get isTextPreviewable {
    return mimeType == 'text/plain' ||
        mimeType == 'text/csv' ||
        mimeType == 'text/markdown';
  }

  /// True for PDF attachments (rendered page-by-page via pdfrx).
  bool get isPdf => mimeType == 'application/pdf';

  /// File extension parsed from [fileName], lowercase without the dot.
  /// Empty string when [fileName] has no extension.
  String get fileExtension {
    final dot = fileName.lastIndexOf('.');
    if (dot < 0 || dot == fileName.length - 1) return '';
    return fileName.substring(dot + 1).toLowerCase();
  }
}
