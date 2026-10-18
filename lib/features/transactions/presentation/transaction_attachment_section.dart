import '../../../core/storage/file_sync_queue.dart';
import '../../../core/storage/local_file_cache.dart';
import '../../../l10n/l10n.dart';
import '../../../theme/aiko_colors.dart';
import 'dart:async';
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
            Positioned(
              left: 0,
              bottom: 0,
              child: _UploadStateBadge(attachment: attachment),
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

/// Marks a file that is saved on this device and uploads when online, or,
/// when its upload failed for good, offers to try again.
class _UploadStateBadge extends StatefulWidget {
  const _UploadStateBadge({required this.attachment});

  final TransactionAttachment attachment;

  @override
  State<_UploadStateBadge> createState() => _UploadStateBadgeState();
}

class _UploadStateBadgeState extends State<_UploadStateBadge> {
  final _repository = TransactionAttachmentRepository();
  StreamSubscription<void>? _queueChanges;
  var _stalled = false;
  var _check = 0;

  @override
  void initState() {
    super.initState();
    _queueChanges = FileSyncQueue.instance.changes.listen((_) => _refresh());
    _refresh();
  }

  @override
  void didUpdateWidget(covariant _UploadStateBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.attachment.id != widget.attachment.id) _refresh();
  }

  @override
  void dispose() {
    _queueChanges?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    final check = ++_check;
    bool stalled;
    try {
      stalled = await _repository.uploadStalled(widget.attachment);
    } catch (_) {
      stalled = false;
    }
    if (!mounted || check != _check || stalled == _stalled) return;
    setState(() => _stalled = stalled);
  }

  @override
  Widget build(BuildContext context) {
    if (!_stalled) {
      final label = context.l10n.filesWaitingToUpload;
      return Padding(
        padding: const EdgeInsets.all(6),
        child: Tooltip(
          message: label,
          child: Semantics(
            label: label,
            child: const _BadgeIcon(icon: Icons.cloud_upload_outlined),
          ),
        ),
      );
    }
    // Same 48px touch target as the remove button.
    return IconButton(
      tooltip: context.l10n.filesUploadFailed,
      onPressed: () {
        setState(() => _stalled = false);
        unawaited(_repository.retryUpload(widget.attachment));
      },
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 48, height: 48),
      icon: const _BadgeIcon(
        icon: Icons.sync_problem_outlined,
        color: AikoColors.dangerRed,
      ),
    );
  }
}

class _BadgeIcon extends StatelessWidget {
  const _BadgeIcon({required this.icon, this.color = Colors.black54});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, size: 16, color: Colors.white),
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
