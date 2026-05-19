import 'package:flutter/material.dart';

import '../domain/transaction_attachment.dart';

class TransactionAttachmentSection extends StatelessWidget {
  const TransactionAttachmentSection({
    required this.attachments,
    this.onAddAttachment,
    super.key,
  });

  final List<TransactionAttachment> attachments;
  final VoidCallback? onAddAttachment;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Transaction attachments',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Attachments',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              IconButton(
                tooltip: 'Add attachment',
                onPressed: onAddAttachment,
                icon: const Icon(Icons.attach_file),
              ),
            ],
          ),
          if (attachments.isEmpty)
            const Text('No receipt or document attached.')
          else
            for (final attachment in attachments)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.insert_drive_file_outlined),
                title: Text(attachment.fileName),
                subtitle: Text(attachment.mimeType),
              ),
        ],
      ),
    );
  }
}
