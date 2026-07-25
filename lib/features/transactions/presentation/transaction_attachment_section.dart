import 'dart:io';

import 'package:flutter/material.dart';

import '../domain/transaction_attachment.dart';
import 'attachment_viewer_dialog.dart';

class TransactionAttachmentSection extends StatelessWidget {
  const TransactionAttachmentSection({
    required this.attachments,
    this.onAddAttachment,
    this.onRemoveAttachment,
    super.key,
  });

  final List<TransactionAttachment> attachments;
  final VoidCallback? onAddAttachment;
  final ValueChanged<TransactionAttachment>? onRemoveAttachment;

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
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final attachment in attachments)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _AttachmentThumb(
                        attachment: attachment,
                        onRemove: onRemoveAttachment == null
                            ? null
                            : () => onRemoveAttachment!(attachment),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Square thumbnail with an overlaid close (X) button. Tapping the thumb
/// opens the full viewer; tapping the X removes the attachment.
class _AttachmentThumb extends StatelessWidget {
  const _AttachmentThumb({required this.attachment, this.onRemove});

  final TransactionAttachment attachment;
  final VoidCallback? onRemove;

  static const double _size = 96;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: _size,
      height: _size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Material(
            color: theme.colorScheme.surfaceContainerHighest,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => AttachmentViewerDialog.show(
                context,
                attachment: attachment,
              ),
              child: _ThumbnailContent(attachment: attachment),
            ),
          ),
          if (onRemove != null)
            Positioned(
              top: 0,
              right: 0,
              child: _RemoveButton(onPressed: onRemove!),
            ),
        ],
      ),
    );
  }
}

class _RemoveButton extends StatelessWidget {
  const _RemoveButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(10),
          bottomLeft: Radius.circular(10),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: const Padding(
          padding: EdgeInsets.all(4),
          child: Icon(Icons.close, size: 16, color: Colors.white),
        ),
      ),
    );
  }
}

/// Renders the image bytes directly when the attachment is previewable;
/// otherwise falls back to a type-aware icon.
class _ThumbnailContent extends StatelessWidget {
  const _ThumbnailContent({required this.attachment});

  final TransactionAttachment attachment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (attachment.isImagePreviewable) {
      return Image.file(
        File(attachment.storagePath),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Icon(
          Icons.broken_image_outlined,
          color: theme.colorScheme.onSurfaceVariant,
          size: 32,
        ),
      );
    }
    return Center(
      child: Icon(_icon(), size: 32, color: theme.colorScheme.primary),
    );
  }

  IconData _icon() {
    if (attachment.isPdf) return Icons.picture_as_pdf_outlined;
    if (attachment.isTextPreviewable) return Icons.description_outlined;
    switch (attachment.fileExtension) {
      case 'doc':
      case 'docx':
        return Icons.article_outlined;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }
}
