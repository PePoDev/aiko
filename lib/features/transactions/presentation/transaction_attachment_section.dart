import '../../../core/storage/local_file_cache.dart';
import '../../../l10n/l10n.dart';
import 'dart:typed_data';
import '../data/transaction_attachment_repository.dart';

import 'package:flutter/material.dart';

import '../domain/transaction_attachment.dart';
import 'attachment_viewer_dialog.dart';

class TransactionAttachmentSection extends StatelessWidget {
  const TransactionAttachmentSection({
    required this.attachments,
    this.onAddAttachment,
    this.onRemoveAttachment,
    this.showTitle = true,
    this.showUploadState = false,
    super.key,
  });

  final List<TransactionAttachment> attachments;

  /// Shows the add button when set.
  final VoidCallback? onAddAttachment;
  final ValueChanged<TransactionAttachment>? onRemoveAttachment;

  /// Whether to show the "Attachments" heading (off inside a titled card).
  final bool showTitle;

  /// Marks attachments that are still waiting to upload (signed in).
  final bool showUploadState;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: context.l10n.txAttachmentsSemantics,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showTitle || onAddAttachment != null)
            Row(
              children: [
                Expanded(
                  child: showTitle
                      ? Text(
                          context.l10n.txAttachments,
                          style: Theme.of(context).textTheme.titleSmall,
                        )
                      : const SizedBox.shrink(),
                ),
                if (onAddAttachment != null)
                  IconButton(
                    tooltip: context.l10n.txAddAttachment,
                    onPressed: onAddAttachment,
                    icon: const Icon(Icons.attach_file),
                  ),
              ],
            ),
          if (attachments.isEmpty)
            Text(context.l10n.txNoAttachments)
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
                        waitingToUpload:
                            showUploadState &&
                            LocalFileCache.isDevicePath(attachment.storagePath),
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
  const _AttachmentThumb({
    required this.attachment,
    required this.waitingToUpload,
    this.onRemove,
  });

  final TransactionAttachment attachment;
  final bool waitingToUpload;
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
              onTap: () =>
                  AttachmentViewerDialog.show(context, attachment: attachment),
              child: _ThumbnailContent(attachment: attachment),
            ),
          ),
          if (waitingToUpload)
            const Positioned(
              left: 6,
              bottom: 6,
              child: _WaitingToUploadBadge(),
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

/// Marks a file that is saved on this device and uploads when online.
class _WaitingToUploadBadge extends StatelessWidget {
  const _WaitingToUploadBadge();

  @override
  Widget build(BuildContext context) {
    final label = context.l10n.filesWaitingToUpload;
    return Tooltip(
      message: label,
      child: Semantics(
        label: label,
        child: const DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black54,
            shape: BoxShape.circle,
          ),
          child: Padding(
            padding: EdgeInsets.all(4),
            child: Icon(
              Icons.cloud_upload_outlined,
              size: 16,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

/// Small visual badge inside a full 48px touch target, with a tooltip.
class _RemoveButton extends StatelessWidget {
  const _RemoveButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: context.l10n.txRemoveAttachment,
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 48, height: 48),
      icon: const DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black54,
          shape: BoxShape.circle,
        ),
        child: Padding(
          padding: EdgeInsets.all(4),
          child: Icon(Icons.close, size: 16, color: Colors.white),
        ),
      ),
    );
  }
}

/// Renders the image bytes directly when the attachment is previewable;
/// otherwise falls back to a type-aware icon.
class _ThumbnailContent extends StatefulWidget {
  const _ThumbnailContent({required this.attachment});

  final TransactionAttachment attachment;

  @override
  State<_ThumbnailContent> createState() => _ThumbnailContentState();
}

class _ThumbnailContentState extends State<_ThumbnailContent> {
  // Read once per attachment, not on every rebuild.
  Future<Uint8List>? _bytes;

  TransactionAttachment get attachment => widget.attachment;

  @override
  void initState() {
    super.initState();
    _bytes = _load();
  }

  @override
  void didUpdateWidget(covariant _ThumbnailContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.attachment.id != attachment.id ||
        oldWidget.attachment.storagePath != attachment.storagePath) {
      _bytes = _load();
    }
  }

  Future<Uint8List>? _load() => attachment.isImagePreviewable
      ? TransactionAttachmentRepository().readBytes(attachment)
      : null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (attachment.isImagePreviewable) {
      // Decode at thumbnail size instead of the full photo.
      final cacheWidth =
          (_AttachmentThumb._size * MediaQuery.devicePixelRatioOf(context))
              .round();
      return FutureBuilder<Uint8List>(
        future: _bytes,
        builder: (context, snapshot) => snapshot.hasData
            ? Image.memory(
                snapshot.data!,
                fit: BoxFit.cover,
                cacheWidth: cacheWidth,
                errorBuilder: (_, _, _) =>
                    const Icon(Icons.broken_image_outlined),
              )
            : Icon(
                switch (snapshot.error) {
                  // Not on this device yet and no connection to download it.
                  AttachmentUnavailableException(offline: true) =>
                    Icons.cloud_off_outlined,
                  null => Icons.image_outlined,
                  _ => Icons.broken_image_outlined,
                },
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
