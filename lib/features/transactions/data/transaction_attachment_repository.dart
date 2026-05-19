import '../domain/transaction_attachment.dart';

class TransactionAttachmentRepository {
  final List<TransactionAttachment> _attachments = [];

  Future<TransactionAttachment> save(TransactionAttachment attachment) async {
    if (!attachment.isValidForUpload) {
      throw ArgumentError.value(
        attachment.fileName,
        'attachment',
        'Attachment metadata is invalid or unsupported',
      );
    }
    _attachments.removeWhere((item) => item.id == attachment.id);
    _attachments.add(attachment);
    return attachment;
  }

  Future<List<TransactionAttachment>> listForTransaction(
    String transactionId,
  ) async {
    return _attachments
        .where((item) => item.transactionId == transactionId)
        .toList(growable: false);
  }

  Future<List<TransactionAttachment>> exportableForTransaction(
    String transactionId,
  ) async {
    final attachments = await listForTransaction(transactionId);
    return attachments.where((item) => item.isExportable).toList();
  }
}
